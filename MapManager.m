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
@property (nonatomic, assign) BOOL isDownloading;  // 下载状态标记
@property (nonatomic, assign) float currentProgress;  // 当前进度缓存
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
    
    // 销毁旧的 session
    [self.currentSession invalidateAndCancel];
    
    // 使用后台下载会话，关闭面板/切换后台都不会中断
    NSString *sessionID = [NSString stringWithFormat:@"com.mapreplacer.download.%ld.%f", (long)mapType, [[NSDate date] timeIntervalSince1970]];
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:sessionID];
    config.sessionSendsLaunchEvents = YES;
    config.discretionary = NO;  // 不延迟下载
    
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config
                                                          delegate:self
                                                     delegateQueue:[NSOperationQueue mainQueue]];
    self.currentSession = session;
    
    NSURL *url = [NSURL URLWithString:downloadURL];
    NSURLSessionDownloadTask *task = [session downloadTaskWithURL:url];
    
    NSLog(@"[MapReplacer] 开始后台下载: %@", downloadURL);
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

#pragma mark - NSURLSessionDownloadDelegate

// 实时进度回调
- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
      didWriteData:(int64_t)bytesWritten
 totalBytesWritten:(int64_t)totalBytesWritten
totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    
    if (totalBytesExpectedToWrite > 0) {
        float progress = (float)totalBytesWritten / (float)totalBytesExpectedToWrite;
        self.currentProgress = progress;  // 缓存进度，重新打开面板时可恢复
        if (self.progressCallback) {
            self.progressCallback(progress);
        }
    }
}

// 下载完成回调
- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
didFinishDownloadingToURL:(NSURL *)location {
    
    NSLog(@"[MapReplacer] 下载完成，临时文件: %@", location.path);
    
    // 使用保存的地图类型获取对应的 mapInfo
    MapType mapType = self.currentDownloadingMapType;
    MapInfo *mapInfo = nil;
    for (MapInfo *info in self.mapList) {
        if (info.mapType == mapType) {
            mapInfo = info;
            break;
        }
    }
    
    // 确定文件名：优先用 mapInfo 中配置的 pakFileName
    NSString *fileName = mapInfo ? mapInfo.pakFileName : nil;
    if (!fileName) {
        // fallback: 使用下载任务的建议文件名或临时文件名
        fileName = downloadTask.response.suggestedFilename;
        if (!fileName || fileName.length == 0) {
            fileName = [location lastPathComponent];
        }
        if (!fileName || fileName.length == 0) {
            fileName = @"download.pak";
        }
    }
    
    NSLog(@"[MapReplacer] 目标文件名: %@", fileName);
    
    // 直接保存到游戏 Paks 目录
    NSString *targetPaksDir = [self targetPaksDirectory];
    
    if (!targetPaksDir) {
        NSLog(@"[MapReplacer] 未找到目标 Paks 目录");
        if (self.completionCallback) {
            NSError *error = [NSError errorWithDomain:@"MapReplacer"
                                                 code:3005
                                             userInfo:@{NSLocalizedDescriptionKey: @"未找到游戏 Paks 目录，请先运行游戏"}];
            self.completionCallback(NO, error);
        }
        return;
    }
    
    NSLog(@"[MapReplacer] 目标目录: %@", targetPaksDir);
    
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *fileError = nil;
    
    // 确保目标目录存在
    if (![fm fileExistsAtPath:targetPaksDir]) {
        [fm createDirectoryAtPath:targetPaksDir withIntermediateDirectories:YES attributes:nil error:&fileError];
        if (fileError) {
            NSLog(@"[MapReplacer] 创建目标目录失败: %@", fileError.localizedDescription);
            if (self.completionCallback) {
                self.completionCallback(NO, fileError);
            }
            return;
        }
    }
    
    // 安全替换流程：先复制到临时位置，确认完整后才替换原文件
    NSString *destPath = [targetPaksDir stringByAppendingPathComponent:fileName];
    
    // ① 先复制下载文件到临时位置（避免跨卷问题）
    NSString *tempPath = [[NSTemporaryDirectory() stringByAppendingPathComponent:[NSUUID UUID].UUIDString] stringByAppendingPathExtension:@"pak"];
    BOOL copySuccess = [fm copyItemAtPath:location.path toPath:tempPath error:&fileError];
    
    if (!copySuccess) {
        NSLog(@"[MapReplacer] 复制临时文件失败: %@", fileError.localizedDescription);
        self.isDownloading = NO;
        if (self.completionCallback) {
            self.completionCallback(NO, fileError);
        }
        return;
    }
    
    // ② 验证临时文件是否完整（文件大小 > 0）
    NSDictionary *attrs = [fm attributesOfItemAtPath:tempPath error:nil];
    unsigned long long fileSize = [attrs fileSize];
    if (fileSize == 0) {
        NSLog(@"[MapReplacer] 下载文件为空，不替换原文件");
        [fm removeItemAtPath:tempPath error:nil];
        self.isDownloading = NO;
        if (self.completionCallback) {
            NSError *error = [NSError errorWithDomain:@"MapReplacer"
                                                 code:3006
                                             userInfo:@{NSLocalizedDescriptionKey: @"下载文件为空，已取消替换"}];
            self.completionCallback(NO, error);
        }
        return;
    }
    
    NSLog(@"[MapReplacer] 临时文件大小: %llu bytes，准备替换", fileSize);
    
    // ③ 现在才删除原文件（新文件已确认完整）
    if ([fm fileExistsAtPath:destPath]) {
        [fm removeItemAtPath:destPath error:nil];
    }
    
    // ④ 移动新文件到目标位置
    BOOL moveSuccess = [fm moveItemAtPath:tempPath toPath:destPath error:&fileError];
    
    if (!moveSuccess) {
        NSLog(@"[MapReplacer] 移动文件失败: %@", fileError.localizedDescription);
        [fm removeItemAtPath:tempPath error:nil];
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
    
    // 清理 session
    [session finishTasksAndInvalidate];
}

// 下载失败回调
- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
didCompleteWithError:(NSError *)error {
    
    if (error) {
        NSLog(@"[MapReplacer] 下载失败: %@", error.localizedDescription);
        self.isDownloading = NO;
        self.currentProgress = 0;
        if (self.completionCallback) {
            self.completionCallback(NO, error);
        }
    }
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
