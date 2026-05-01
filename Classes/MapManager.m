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

static NSString *const kBackupSuffix = @".bak_original";
static NSString *const kCurrentMapKey = @"MapReplacer_CurrentMap";
static NSString *const kResourceSubDir = @"MapReplacerRes";

@interface MapManager ()
@property (nonatomic, strong) NSArray<MapInfo *> *mapList;
@property (nonatomic, copy) NSString *cachedPaksDir;
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
        [MapInfo infoWithName:@"海岛地图 (Erangel)"
                      pakFile:@"map_baltic_1.36.11.15210.pak"
                         type:MapTypeBaltic],

        [MapInfo infoWithName:@"沙漠地图 (Miramar)"
                      pakFile:@"map_desert_1.36.11.15210.pak"
                         type:MapTypeDesert],

        [MapInfo infoWithName:@"热带雨林 (Sanhok)"
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

    self.progressCallback = progressBlock;
    self.completionCallback = completionBlock;

    NSString *destPath = [[self resourcePaksDirectory] stringByAppendingPathComponent:mapInfo.pakFileName];
    if (!destPath) {
        if (completionBlock) {
            NSError *error = [NSError errorWithDomain:@"MapReplacer"
                                                 code:3003
                                             userInfo:@{NSLocalizedDescriptionKey: @"无法获取资源目录"}];
            completionBlock(NO, error);
        }
        return;
    }

    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config
                                                          delegate:self
                                                     delegateQueue:[NSOperationQueue mainQueue]];

    NSURL *url = [NSURL URLWithString:downloadURL];
    NSURLSessionDownloadTask *task = [session downloadTaskWithURL:url];

    NSLog(@"[MapReplacer] 开始下载: %@", downloadURL);
    [task resume];
}

- (NSString *)downloadURLForMapType:(MapType)mapType {
    NSDictionary *urls = @{
        @(MapTypeBaltic): @"https://modelscope-resouces.oss-cn-zhangjiakou.aliyuncs.com/avatar%2Fac2536b6-c87e-471f-ada2-ae8d3c9aeb1e.pak",
    };

    return urls[@(mapType)];
}

#pragma mark - NSURLSessionDownloadDelegate

- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
      didWriteData:(int64_t)bytesWritten
 totalBytesWritten:(int64_t)totalBytesWritten
totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {

    if (totalBytesExpectedToWrite > 0 && self.progressCallback) {
        float progress = (float)totalBytesWritten / (float)totalBytesExpectedToWrite;
        self.progressCallback(progress);
    }
}

- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
didFinishDownloadingToURL:(NSURL *)location {

    NSLog(@"[MapReplacer] 下载完成，临时文件: %@", location.path);

    NSString *fileName = nil;
    MapType mapType = MapTypeBaltic;

    for (MapInfo *info in self.mapList) {
        if ([[downloadTask.originalRequest.URL absoluteString] containsString:info.pakFileName]) {
            fileName = info.pakFileName;
            mapType = info.mapType;
            break;
        }
    }

    if (!fileName) {
        fileName = [[location lastPathComponent] isEqualToString:@""] ? @"download.pak" : [location lastPathComponent];
    }

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

    NSArray *existingFiles = [fm contentsOfDirectoryAtPath:targetPaksDir error:nil];
    for (NSString *existingFile in existingFiles) {
        if ([existingFile hasSuffix:@".pak"]) {
            NSString *oldPath = [targetPaksDir stringByAppendingPathComponent:existingFile];
            NSString *backupPath = [oldPath stringByAppendingString:kBackupSuffix];

            if (![fm fileExistsAtPath:backupPath]) {
                [fm copyItemAtPath:oldPath toPath:backupPath error:nil];
                NSLog(@"[MapReplacer] 已备份: %@", existingFile);
            }

            [fm removeItemAtPath:oldPath error:nil];
        }
    }

    NSString *tempPath = [[NSTemporaryDirectory() stringByAppendingPathComponent:[NSUUID UUID].UUIDString] stringByAppendingPathExtension:@"pak"];
    BOOL copySuccess = [fm copyItemAtPath:location.path toPath:tempPath error:&fileError];

    if (!copySuccess) {
        NSLog(@"[MapReplacer] 复制临时文件失败: %@", fileError.localizedDescription);
        if (self.completionCallback) {
            self.completionCallback(NO, fileError);
        }
        return;
    }

    NSString *destPath = [targetPaksDir stringByAppendingPathComponent:fileName];
    [fm removeItemAtPath:destPath error:nil];
    BOOL moveSuccess = [fm moveItemAtPath:tempPath toPath:destPath error:&fileError];

    if (!moveSuccess) {
        NSLog(@"[MapReplacer] 移动文件失败: %@", fileError.localizedDescription);
        [fm removeItemAtPath:tempPath error:nil];
        if (self.completionCallback) {
            self.completionCallback(NO, fileError);
        }
    } else {
        NSLog(@"[MapReplacer] ✓ 文件已保存到: %@", destPath);

        [[NSUserDefaults standardUserDefaults] setInteger:mapType forKey:kCurrentMapKey];
        [[NSUserDefaults standardUserDefaults] synchronize];

        if (self.completionCallback) {
            self.completionCallback(YES, nil);
        }
    }
}

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
didCompleteWithError:(NSError *)error {

    if (error) {
        NSLog(@"[MapReplacer] 下载失败: %@", error.localizedDescription);
        if (self.completionCallback) {
            self.completionCallback(NO, error);
        }
    }
}

- (NSString *)targetPaksDirectory {
    if (self.cachedPaksDir) {
        return self.cachedPaksDir;
    }

    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    if (paths.count == 0) {
        NSLog(@"[MapReplacer] 无法获取 Documents 目录");
        return nil;
    }

    NSString *documentsDir = paths.firstObject;
    NSString *paksDir = [documentsDir stringByAppendingPathComponent:@"ShadowTrackerExtra/Saved/Paks"];

    NSLog(@"[MapReplacer] 目标 Paks 目录: %@", paksDir);

    NSFileManager *fm = [NSFileManager defaultManager];

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

- (NSString *)resourcePaksDirectory {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    if (paths.count == 0) {
        return nil;
    }

    NSString *documentsDir = paths.firstObject;
    NSString *resDir = [documentsDir stringByAppendingPathComponent:kResourceSubDir];

    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *error = nil;
    if (![fm fileExistsAtPath:resDir]) {
        BOOL success = [fm createDirectoryAtPath:resDir withIntermediateDirectories:YES attributes:nil error:&error];
        if (!success) {
            NSLog(@"[MapReplacer] 创建资源目录失败: %@", error.localizedDescription);
            return nil;
        }
    }

    NSLog(@"[MapReplacer] 资源目录: %@", resDir);
    return resDir;
}

#pragma mark - 文件替换操作

- (BOOL)replaceMapWithType:(MapType)mapType error:(NSError **)error {
    NSString *targetDir = [self targetPaksDirectory];
    if (!targetDir) {
        if (error) {
            *error = [NSError errorWithDomain:@"MapReplacer"
                                         code:1001
                                     userInfo:@{NSLocalizedDescriptionKey: @"未找到目标 Paks 目录，请确认游戏已安装并运行过一次"}];
        }
        return NO;
    }

    MapInfo *mapInfo = nil;
    for (MapInfo *info in self.mapList) {
        if (info.mapType == mapType) {
            mapInfo = info;
            break;
        }
    }

    if (!mapInfo) {
        if (error) {
            *error = [NSError errorWithDomain:@"MapReplacer"
                                         code:1002
                                     userInfo:@{NSLocalizedDescriptionKey: @"无效的地图类型"}];
        }
        return NO;
    }

    NSString *srcPath = [[self resourcePaksDirectory] stringByAppendingPathComponent:mapInfo.pakFileName];

    NSFileManager *fm = [NSFileManager defaultManager];

    if (![fm fileExistsAtPath:srcPath]) {
        if (error) {
            *error = [NSError errorWithDomain:@"MapReplacer"
                                         code:1003
                                     userInfo:@{NSLocalizedDescriptionKey:
                [NSString stringWithFormat:@"地图资源文件不存在: %@", mapInfo.pakFileName]}];
        }
        return NO;
    }

    NSArray *targetFiles = [fm contentsOfDirectoryAtPath:targetDir error:nil];

    for (NSString *fileName in targetFiles) {
        if ([fileName hasSuffix:@".pak"]) {
            NSString *targetFilePath = [targetDir stringByAppendingPathComponent:fileName];
            NSString *backupFilePath = [targetFilePath stringByAppendingString:kBackupSuffix];

            if (![fm fileExistsAtPath:backupFilePath]) {
                NSError *copyError = nil;
                [fm copyItemAtPath:targetFilePath toPath:backupFilePath error:&copyError];
                if (copyError) {
                    NSLog(@"[MapReplacer] 备份文件失败: %@", copyError.localizedDescription);
                }
            }

            [fm removeItemAtPath:targetFilePath error:nil];
        }
    }

    NSString *destPath = [targetDir stringByAppendingPathComponent:mapInfo.pakFileName];
    NSError *copyError = nil;
    BOOL success = [fm copyItemAtPath:srcPath toPath:destPath error:&copyError];

    if (!success) {
        if (error) {
            *error = [NSError errorWithDomain:@"MapReplacer"
                                         code:1004
                                     userInfo:@{NSLocalizedDescriptionKey:
                [NSString stringWithFormat:@"文件复制失败: %@", copyError.localizedDescription]}];
        }
        return NO;
    }

    [[NSUserDefaults standardUserDefaults] setInteger:mapType forKey:kCurrentMapKey];
    [[NSUserDefaults standardUserDefaults] synchronize];

    NSLog(@"[MapReplacer] 成功替换地图: %@ -> %@", mapInfo.displayName, destPath);
    return YES;
}

- (BOOL)restoreOriginalMapWithError:(NSError **)error {
    NSString *targetDir = [self targetPaksDirectory];
    if (!targetDir) {
        if (error) {
            *error = [NSError errorWithDomain:@"MapReplacer"
                                         code:2001
                                     userInfo:@{NSLocalizedDescriptionKey: @"未找到目标 Paks 目录"}];
        }
        return NO;
    }

    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *allFiles = [fm contentsOfDirectoryAtPath:targetDir error:nil];

    for (NSString *fileName in allFiles) {
        if ([fileName hasSuffix:@".pak"] && ![fileName hasSuffix:kBackupSuffix]) {
            NSString *filePath = [targetDir stringByAppendingPathComponent:fileName];
            [fm removeItemAtPath:filePath error:nil];
        }
    }

    allFiles = [fm contentsOfDirectoryAtPath:targetDir error:nil];
    for (NSString *fileName in allFiles) {
        if ([fileName hasSuffix:kBackupSuffix]) {
            NSString *backupPath = [targetDir stringByAppendingPathComponent:fileName];
            NSString *originalName = [fileName stringByReplacingOccurrencesOfString:kBackupSuffix withString:@""];
            NSString *originalPath = [targetDir stringByAppendingPathComponent:originalName];

            [fm moveItemAtPath:backupPath toPath:originalPath error:nil];
        }
    }

    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kCurrentMapKey];
    [[NSUserDefaults standardUserDefaults] synchronize];

    NSLog(@"[MapReplacer] 已恢复原始地图文件");
    return YES;
}

- (BOOL)isMapResourceAvailable:(MapType)mapType {
    MapInfo *mapInfo = nil;
    for (MapInfo *info in self.mapList) {
        if (info.mapType == mapType) {
            mapInfo = info;
            break;
        }
    }
    if (!mapInfo) return NO;

    NSString *path = [[self resourcePaksDirectory] stringByAppendingPathComponent:mapInfo.pakFileName];
    return [[NSFileManager defaultManager] fileExistsAtPath:path];
}

- (NSInteger)currentReplacedMapType {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults objectForKey:kCurrentMapKey] == nil) {
        return -1;
    }
    return [defaults integerForKey:kCurrentMapKey];
}

@end
