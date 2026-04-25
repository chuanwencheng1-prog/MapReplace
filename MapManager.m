#import "MapManager.h"
#import <Foundation/Foundation.h>

// ============================================================
// MapInfo 实现
// ============================================================
@implementation MapInfo

+ (instancetype)infoWithName:(NSString *)name pakFile:(NSString *)pakFile type:(MapType)type {
    MapInfo *info = [[MapInfo alloc] init];
    info.displayName = name;
    info.pakFileName = pakFile;
    info.mapType = type;
    return info;
}

@end

// ============================================================
// MapManager 实现
// ============================================================

@interface MapManager ()
@property (nonatomic, strong) NSArray<MapInfo *> *mapList;
@property (nonatomic, copy) NSString *cachedPaksDir;
@property (nonatomic, assign) MapType currentDownloadingMapType;
@property (nonatomic, strong) NSURLSession *currentSession;
@property (nonatomic, assign) BOOL isDownloading;
@property (nonatomic, assign) float currentProgress;
// DataTask 流式写入相关
@property (nonatomic, strong) NSFileHandle *downloadFileHandle;  // 写入句柄
@property (nonatomic, copy) NSString *downloadTempPath;           // 临时文件路径
@property (nonatomic, assign) int64_t expectedContentLength;     // 预期总大小
@property (nonatomic, assign) int64_t receivedDataLength;        // 已接收大小
@end

@implementation MapManager

+ (instancetype)sharedManager {
    static MapManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[MapManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self setupMapList];
    }
    return self;
}

#pragma mark - 地图配置

- (void)setupMapList {
    self.mapList = @[
        [MapInfo infoWithName:@"海岛地图 (除草)"
                      pakFile:@"map_baltic_1.36.11.15210.pak"
                         type:MapTypeBaltic],
        
        [MapInfo infoWithName:@"海岛地图 (全除)"
                      pakFile:@"map_baltic_1.36.11.15210.pak"
                         type:MapTypeDesert],
        
        [MapInfo infoWithName:@"雨林地图 (Sanhok)"
                      pakFile:@"map_savage_1.36.11.15210.pak"
                         type:MapTypeSavage],
        
        [MapInfo infoWithName:@"雪地地图 (Vikendi)"
                      pakFile:@"map_dihor_1.36.11.15210.pak"
                         type:MapTypeDihor],
        
        [MapInfo infoWithName:@"Livik 地图"
                      pakFile:@"map_livik_1.36.11.15210.pak"
                         type:MapTypeLivik],
        
        [MapInfo infoWithName:@"Karakin 地图"
                      pakFile:@"map_karakin_1.36.11.15210.pak"
                         type:MapTypeKarakin],
    ];
}

- (NSArray<MapInfo *> *)availableMaps {
    return self.mapList;
}

#pragma mark - 路径管理

- (void)downloadMapWithType:(MapType)mapType
                   progress:(void(^)(float progress))progressBlock
                 completion:(void(^)(BOOL success, NSError *error))completionBlock {
    
    MapInfo *mapInfo = nil;
    for (MapInfo *info in self.mapList) {
        if (info.mapType == mapType) {
            mapInfo = info;
            break;
        }
    }
    
    if (!mapInfo) {
        if (completionBlock) {
            NSError *error = [NSError errorWithDomain:@"MapReplacer"
                                                 code:3001
                                             userInfo:@{NSLocalizedDescriptionKey: @"无效的地图类型"}];
            completionBlock(NO, error);
        }
        return;
    }
    
    // 获取下载 URL（从配置或默认）
    NSString *downloadURL = [self downloadURLForMapType:mapType];
    if (!downloadURL) {
        if (completionBlock) {
            NSError *error = [NSError errorWithDomain:@"MapReplacer"
                                                 code:3002
                                             userInfo:@{NSLocalizedDescriptionKey: @"未配置下载链接"}];
            completionBlock(NO, error);
        }
        return;
    }
    
    // 保存回调和当前下载的地图类型
    self.progressCallback = progressBlock;
    self.completionCallback = completionBlock;
    self.currentDownloadingMapType = mapType;
    self.isDownloading = YES;
    self.currentProgress = 0;
    self.receivedDataLength = 0;
    self.expectedContentLength = 0;
    
    // 销毁旧的 session
    [self.currentSession invalidateAndCancel];
    // 关闭旧的文件句柄
    [self.downloadFileHandle closeFile];
    self.downloadFileHandle = nil;
    
    // 创建临时文件路径（在 App 沙箱内，兼容所有设备）
    NSString *tempDir = NSTemporaryDirectory();
    self.downloadTempPath = [[tempDir stringByAppendingPathComponent:[NSUUID UUID].UUIDString] stringByAppendingPathExtension:@"pak"];
    
    // 创建空的临时文件
    [[NSFileManager defaultManager] createFileAtPath:self.downloadTempPath contents:nil attributes:nil];
    self.downloadFileHandle = [NSFileHandle fileHandleForWritingAtPath:self.downloadTempPath];
    
    if (!self.downloadFileHandle) {
        NSLog(@"[MapReplacer] 无法创建临时文件: %@", self.downloadTempPath);
        self.isDownloading = NO;
        if (completionBlock) {
            NSError *error = [NSError errorWithDomain:@"MapReplacer"
                                                 code:3003
                                             userInfo:@{NSLocalizedDescriptionKey: @"无法创建临时文件"}];
            completionBlock(NO, error);
        }
        return;
    }
    
    // 使用默认会话 + DataTask（不依赖系统临时文件，兼容所有设备）
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    config.timeoutIntervalForRequest = 300;
    config.timeoutIntervalForResource = 3600;
    
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config
                                                          delegate:self
                                                     delegateQueue:[NSOperationQueue mainQueue]];
    self.currentSession = session;
    
    NSURL *url = [NSURL URLWithString:downloadURL];
    NSURLSessionDataTask *task = [session dataTaskWithURL:url];
    
    NSLog(@"[MapReplacer] 开始下载 (流式写入): %@", downloadURL);
    [task resume];
}

- (NSString *)downloadURLForMapType:(MapType)mapType {
    // 地图下载链接配置
    NSDictionary *urls = @{
        @(MapTypeBaltic): @"https://modelscope-resouces.oss-cn-zhangjiakou.aliyuncs.com/avatar%2Fac2536b6-c87e-471f-ada2-ae8d3c9aeb1e.pak",
        @(MapTypeDesert): @"https://modelscope-resouces.oss-cn-zhangjiakou.aliyuncs.com/avatar%2F350ce505-1505-45d6-92fd-e1cac8dc7a9b.pak",
        // 其他地图可以继续添加
    };
    
    return urls[@(mapType)];
}

#pragma mark - NSURLSessionDataDelegate

// 收到响应头 - 获取文件总大小
- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
didReceiveResponse:(NSURLResponse *)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    
    self.expectedContentLength = response.expectedContentLength;
    self.receivedDataLength = 0;
    
    NSLog(@"[MapReplacer] 响应状态: %ld，预期大小: %lld bytes",
          (long)((NSHTTPURLResponse *)response).statusCode,
          self.expectedContentLength);
    
    // 检查 HTTP 状态码
    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
        NSInteger statusCode = ((NSHTTPURLResponse *)response).statusCode;
        if (statusCode >= 400) {
            NSLog(@"[MapReplacer] HTTP 错误: %ld", (long)statusCode);
            completionHandler(NSURLSessionResponseCancel);
            self.isDownloading = NO;
            if (self.completionCallback) {
                NSError *error = [NSError errorWithDomain:@"MapReplacer"
                                                     code:statusCode
                                                 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"HTTP 错误: %ld", (long)statusCode]}];
                self.completionCallback(NO, error);
            }
            return;
        }
    }
    
    // 允许接收数据
    completionHandler(NSURLSessionResponseAllow);
}

// 收到数据块 - 实时写入文件
- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data {
    
    // 直接写入文件，不占用内存
    if (self.downloadFileHandle) {
        @try {
            [self.downloadFileHandle writeData:data];
        } @catch (NSException *exception) {
            NSLog(@"[MapReplacer] 写入文件异常: %@", exception.reason);
        }
    }
    
    self.receivedDataLength += data.length;
    
    // 更新进度
    if (self.expectedContentLength > 0) {
        float progress = (float)self.receivedDataLength / (float)self.expectedContentLength;
        self.currentProgress = progress;
        if (self.progressCallback) {
            self.progressCallback(progress);
        }
    }
}

// 下载完成/失败回调
- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
didCompleteWithError:(NSError *)error {
    
    // 关闭文件句柄
    [self.downloadFileHandle closeFile];
    self.downloadFileHandle = nil;
    
    if (error) {
        // 下载失败，清理临时文件
        NSLog(@"[MapReplacer] 下载失败: %@", error.localizedDescription);
        [[NSFileManager defaultManager] removeItemAtPath:self.downloadTempPath error:nil];
        self.isDownloading = NO;
        self.currentProgress = 0;
        if (self.completionCallback) {
            self.completionCallback(NO, error);
        }
        return;
    }
    
    // 下载成功，开始安全替换流程
    NSLog(@"[MapReplacer] 下载完成，已接收: %lld bytes", self.receivedDataLength);
    
    NSFileManager *fm = [NSFileManager defaultManager];
    
    // ① 验证临时文件是否完整
    NSDictionary *attrs = [fm attributesOfItemAtPath:self.downloadTempPath error:nil];
    unsigned long long fileSize = [attrs fileSize];
    
    if (fileSize == 0) {
        NSLog(@"[MapReplacer] 下载文件为空，不替换原文件");
        [fm removeItemAtPath:self.downloadTempPath error:nil];
        self.isDownloading = NO;
        if (self.completionCallback) {
            NSError *err = [NSError errorWithDomain:@"MapReplacer"
                                               code:3006
                                           userInfo:@{NSLocalizedDescriptionKey: @"下载文件为空，已取消替换"}];
            self.completionCallback(NO, err);
        }
        return;
    }
    
    // ② 获取目标文件名和目录
    MapInfo *mapInfo = nil;
    for (MapInfo *info in self.mapList) {
        if (info.mapType == self.currentDownloadingMapType) {
            mapInfo = info;
            break;
        }
    }
    
    NSString *fileName = mapInfo ? mapInfo.pakFileName : @"download.pak";
    NSString *targetPaksDir = [self targetPaksDirectory];
    
    if (!targetPaksDir) {
        [fm removeItemAtPath:self.downloadTempPath error:nil];
        self.isDownloading = NO;
        if (self.completionCallback) {
            NSError *err = [NSError errorWithDomain:@"MapReplacer"
                                               code:3005
                                           userInfo:@{NSLocalizedDescriptionKey: @"未找到目标 Paks 目录"}];
            self.completionCallback(NO, err);
        }
        return;
    }
    
    // 确保目标目录存在
    NSError *dirError = nil;
    if (![fm fileExistsAtPath:targetPaksDir]) {
        [fm createDirectoryAtPath:targetPaksDir withIntermediateDirectories:YES attributes:nil error:&dirError];
        if (dirError) {
            [fm removeItemAtPath:self.downloadTempPath error:nil];
            self.isDownloading = NO;
            if (self.completionCallback) {
                self.completionCallback(NO, dirError);
            }
            return;
        }
    }
    
    NSString *destPath = [targetPaksDir stringByAppendingPathComponent:fileName];
    NSLog(@"[MapReplacer] 临时文件大小: %llu bytes，准备替换 -> %@", fileSize, destPath);
    
    // ③ 新文件已确认完整，现在才删除原文件
    NSError *fileError = nil;
    if ([fm fileExistsAtPath:destPath]) {
        [fm removeItemAtPath:destPath error:nil];
    }
    
    // ④ 移动新文件到目标位置
    BOOL moveSuccess = [fm moveItemAtPath:self.downloadTempPath toPath:destPath error:&fileError];
    
    if (!moveSuccess) {
        NSLog(@"[MapReplacer] 移动文件失败: %@", fileError.localizedDescription);
        [fm removeItemAtPath:self.downloadTempPath error:nil];
        self.isDownloading = NO;
        if (self.completionCallback) {
            self.completionCallback(NO, fileError);
        }
    } else {
        NSLog(@"[MapReplacer] ✓ 文件已安全替换: %@ (%llu bytes)", destPath, fileSize);
        self.isDownloading = NO;
        if (self.completionCallback) {
            self.completionCallback(YES, nil);
        }
    }
    
    [session finishTasksAndInvalidate];
}

- (NSString *)targetPaksDirectory {
    if (self.cachedPaksDir) {
        return self.cachedPaksDir;
    }
    
    // 直接获取当前 App 的 Documents 路径（不需要知道 UUID）
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    if (paths.count == 0) {
        NSLog(@"[MapReplacer] 无法获取 Documents 目录");
        return nil;
    }
    
    NSString *documentsDir = paths.firstObject;
    NSString *paksDir = [documentsDir stringByAppendingPathComponent:@"ShadowTrackerExtra/Saved/Paks"];
    
    NSLog(@"[MapReplacer] 目标 Paks 目录: %@", paksDir);
    
    NSFileManager *fm = [NSFileManager defaultManager];
    
    // 如果目录不存在，尝试创建
    if (![fm fileExistsAtPath:paksDir]) {
        NSError *error = nil;
        BOOL success = [fm createDirectoryAtPath:paksDir withIntermediateDirectories:YES attributes:nil error:&error];
        
        if (success) {
            NSLog(@"[MapReplacer] ✓ 已创建 Paks 目录");
        } else {
            NSLog(@"[MapReplacer] ✗ 创建目录失败: %@", error.localizedDescription);
            return nil;
        }
    }
    
    self.cachedPaksDir = paksDir;
    return paksDir;
}

@end
