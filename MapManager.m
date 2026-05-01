//
//  MapManager.m
//  MapReplacerApp
//
//  与原 MapReplacer/MapManager.m 逻辑完全一致。
//  差异：
//    1. 新增 overrideTargetPaksDirectory: 由 SandboxEscape 定位的真实目标路径覆盖
//    2. 写入目标路径时统一走 SandboxEscape 封装 (若逃逸成功则跨沙箱写入)
//
#import "MapManager.h"
#import "SandboxEscape.h"
#import <Foundation/Foundation.h>

@implementation MapInfo
+ (instancetype)infoWithName:(NSString *)name pakFile:(NSString *)pakFile type:(MapType)type {
    MapInfo *info = [[MapInfo alloc] init];
    info.displayName = name;
    info.pakFileName = pakFile;
    info.mapType = type;
    return info;
}
@end

static NSString *const kBackupSuffix = @".bak_original";
static NSString *const kCurrentMapKey = @"MapReplacer_CurrentMap";
static NSString *const kResourceSubDir = @"MapReplacerRes";

@interface MapManager ()
@property (nonatomic, strong) NSArray<MapInfo *> *mapList;
@property (nonatomic, copy) NSString *cachedPaksDir;
@property (nonatomic, copy) NSString *overriddenPaksDir;
@end

@implementation MapManager

+ (instancetype)sharedManager {
    static MapManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[MapManager alloc] init]; });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) [self setupMapList];
    return self;
}

#pragma mark - 地图配置

- (void)setupMapList {
    self.mapList = @[
        [MapInfo infoWithName:@"海岛地图 (Erangel)"  pakFile:@"map_baltic_1.36.11.15210.pak"  type:MapTypeBaltic],
        [MapInfo infoWithName:@"沙漠地图 (Miramar)"  pakFile:@"map_desert_1.36.11.15210.pak"  type:MapTypeDesert],
        [MapInfo infoWithName:@"热带雨林 (Sanhok)"   pakFile:@"map_savage_1.36.11.15210.pak"  type:MapTypeSavage],
        [MapInfo infoWithName:@"雪地地图 (Vikendi)"  pakFile:@"map_dihor_1.36.11.15210.pak"   type:MapTypeDihor],
        [MapInfo infoWithName:@"Livik 地图"         pakFile:@"map_livik_1.36.11.15210.pak"   type:MapTypeLivik],
        [MapInfo infoWithName:@"Karakin 地图"       pakFile:@"map_karakin_1.36.11.15210.pak" type:MapTypeKarakin],
    ];
}

- (NSArray<MapInfo *> *)availableMaps { return self.mapList; }

- (void)overrideTargetPaksDirectory:(NSString *)path {
    self.overriddenPaksDir = [path copy];
    self.cachedPaksDir = nil;
    NSLog(@"[MapManager] 目标 Paks 目录被覆盖为: %@", path);
}

#pragma mark - 下载

- (void)downloadMapWithType:(MapType)mapType
                   progress:(void(^)(float))progressBlock
                 completion:(void(^)(BOOL, NSError *))completionBlock {

    MapInfo *mapInfo = nil;
    for (MapInfo *info in self.mapList) if (info.mapType == mapType) { mapInfo = info; break; }
    if (!mapInfo) {
        if (completionBlock) completionBlock(NO, [NSError errorWithDomain:@"MapReplacer" code:3001
                                                                  userInfo:@{NSLocalizedDescriptionKey:@"无效的地图类型"}]);
        return;
    }

    NSString *downloadURL = [self downloadURLForMapType:mapType];
    if (!downloadURL) {
        if (completionBlock) completionBlock(NO, [NSError errorWithDomain:@"MapReplacer" code:3002
                                                                  userInfo:@{NSLocalizedDescriptionKey:@"未配置下载链接"}]);
        return;
    }

    self.progressCallback = progressBlock;
    self.completionCallback = completionBlock;

    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:[NSOperationQueue mainQueue]];
    NSURLSessionDownloadTask *task = [session downloadTaskWithURL:[NSURL URLWithString:downloadURL]];
    NSLog(@"[MapManager] 开始下载: %@", downloadURL);
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
        self.progressCallback((float)totalBytesWritten / (float)totalBytesExpectedToWrite);
    }
}

- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
didFinishDownloadingToURL:(NSURL *)location {

    NSLog(@"[MapManager] 下载完成: %@", location.path);

    NSString *fileName = nil;
    MapType mapType = MapTypeBaltic;
    for (MapInfo *info in self.mapList) {
        if ([[downloadTask.originalRequest.URL absoluteString] containsString:info.pakFileName]) {
            fileName = info.pakFileName; mapType = info.mapType; break;
        }
    }
    if (!fileName) {
        // URL 没带 pak 文件名时，按当前请求匹配的 mapType 用其 pakFileName
        for (MapInfo *info in self.mapList) {
            NSString *mapUrl = [self downloadURLForMapType:info.mapType];
            if (mapUrl && [mapUrl isEqualToString:[downloadTask.originalRequest.URL absoluteString]]) {
                fileName = info.pakFileName; mapType = info.mapType; break;
            }
        }
    }
    if (!fileName) fileName = @"download.pak";

    NSString *targetPaksDir = [self targetPaksDirectory];
    if (!targetPaksDir) {
        if (self.completionCallback) {
            self.completionCallback(NO, [NSError errorWithDomain:@"MapReplacer" code:3005
                                                        userInfo:@{NSLocalizedDescriptionKey:@"未找到目标 Paks 目录"}]);
        }
        return;
    }

    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *fileError = nil;

    // 确保目标目录存在
    if (![fm fileExistsAtPath:targetPaksDir]) {
        [fm createDirectoryAtPath:targetPaksDir withIntermediateDirectories:YES attributes:nil error:&fileError];
    }

    // 备份并清理旧的 pak 文件
    NSArray *existingFiles = [fm contentsOfDirectoryAtPath:targetPaksDir error:nil];
    for (NSString *existingFile in existingFiles) {
        if ([existingFile hasSuffix:@".pak"]) {
            NSString *oldPath = [targetPaksDir stringByAppendingPathComponent:existingFile];
            NSString *backupPath = [oldPath stringByAppendingString:kBackupSuffix];
            if (![fm fileExistsAtPath:backupPath]) {
                SandboxEscapeCopyFile(oldPath, backupPath);
                NSLog(@"[MapManager] 已备份: %@", existingFile);
            }
            SandboxEscapeRemoveFile(oldPath);
        }
    }

    NSString *destPath = [targetPaksDir stringByAppendingPathComponent:fileName];
    SandboxEscapeRemoveFile(destPath);

    BOOL copyOK = SandboxEscapeCopyFile(location.path, destPath);
    if (!copyOK) {
        if (self.completionCallback) {
            self.completionCallback(NO, [NSError errorWithDomain:@"MapReplacer" code:3006
                                                        userInfo:@{NSLocalizedDescriptionKey:@"写入目标 Paks 失败 (无权限?)"}]);
        }
        return;
    }

    // 若 DarkSword 激活，把文件属主修正为 mobile:mobile(501:501)
    if (SandboxEscapeIsActive()) {
        SandboxEscapeChown(destPath, 501, 501);
    }

    NSLog(@"[MapManager] ✓ 文件已保存: %@", destPath);

    [[NSUserDefaults standardUserDefaults] setInteger:mapType forKey:kCurrentMapKey];
    [[NSUserDefaults standardUserDefaults] synchronize];

    if (self.completionCallback) self.completionCallback(YES, nil);
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if (error && self.completionCallback) {
        NSLog(@"[MapManager] 下载失败: %@", error.localizedDescription);
        self.completionCallback(NO, error);
    }
}

#pragma mark - 路径管理

- (NSString *)targetPaksDirectory {
    if (self.overriddenPaksDir) return self.overriddenPaksDir;
    if (self.cachedPaksDir) return self.cachedPaksDir;

    // 默认回退：当前 App Documents/ShadowTrackerExtra/Saved/Paks
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    if (paths.count == 0) return nil;

    NSString *paksDir = [paths.firstObject stringByAppendingPathComponent:@"ShadowTrackerExtra/Saved/Paks"];
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:paksDir]) {
        [fm createDirectoryAtPath:paksDir withIntermediateDirectories:YES attributes:nil error:nil];
    }
    self.cachedPaksDir = paksDir;
    return paksDir;
}

- (NSString *)resourcePaksDirectory {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    if (paths.count == 0) return nil;
    NSString *resDir = [paths.firstObject stringByAppendingPathComponent:kResourceSubDir];
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:resDir]) {
        [fm createDirectoryAtPath:resDir withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return resDir;
}

#pragma mark - 文件替换 / 恢复

- (BOOL)replaceMapWithType:(MapType)mapType error:(NSError **)error {
    NSString *targetDir = [self targetPaksDirectory];
    if (!targetDir) {
        if (error) *error = [NSError errorWithDomain:@"MapReplacer" code:1001
                                             userInfo:@{NSLocalizedDescriptionKey:@"未找到目标 Paks 目录"}];
        return NO;
    }
    MapInfo *mapInfo = nil;
    for (MapInfo *info in self.mapList) if (info.mapType == mapType) { mapInfo = info; break; }
    if (!mapInfo) {
        if (error) *error = [NSError errorWithDomain:@"MapReplacer" code:1002
                                             userInfo:@{NSLocalizedDescriptionKey:@"无效地图类型"}];
        return NO;
    }

    NSString *srcPath = [[self resourcePaksDirectory] stringByAppendingPathComponent:mapInfo.pakFileName];
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:srcPath]) {
        if (error) *error = [NSError errorWithDomain:@"MapReplacer" code:1003
                                             userInfo:@{NSLocalizedDescriptionKey:
            [NSString stringWithFormat:@"资源文件不存在: %@", mapInfo.pakFileName]}];
        return NO;
    }

    NSArray *targetFiles = [fm contentsOfDirectoryAtPath:targetDir error:nil];
    for (NSString *fileName in targetFiles) {
        if ([fileName hasSuffix:@".pak"]) {
            NSString *targetFilePath = [targetDir stringByAppendingPathComponent:fileName];
            NSString *backupFilePath = [targetFilePath stringByAppendingString:kBackupSuffix];
            if (![fm fileExistsAtPath:backupFilePath]) SandboxEscapeCopyFile(targetFilePath, backupFilePath);
            SandboxEscapeRemoveFile(targetFilePath);
        }
    }

    NSString *destPath = [targetDir stringByAppendingPathComponent:mapInfo.pakFileName];
    if (!SandboxEscapeCopyFile(srcPath, destPath)) {
        if (error) *error = [NSError errorWithDomain:@"MapReplacer" code:1004
                                             userInfo:@{NSLocalizedDescriptionKey:@"文件复制失败"}];
        return NO;
    }
    if (SandboxEscapeIsActive()) SandboxEscapeChown(destPath, 501, 501);

    [[NSUserDefaults standardUserDefaults] setInteger:mapType forKey:kCurrentMapKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    NSLog(@"[MapManager] 成功替换: %@", destPath);
    return YES;
}

- (BOOL)restoreOriginalMapWithError:(NSError **)error {
    NSString *targetDir = [self targetPaksDirectory];
    if (!targetDir) {
        if (error) *error = [NSError errorWithDomain:@"MapReplacer" code:2001
                                             userInfo:@{NSLocalizedDescriptionKey:@"未找到目标 Paks 目录"}];
        return NO;
    }
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *allFiles = [fm contentsOfDirectoryAtPath:targetDir error:nil];

    for (NSString *fileName in allFiles) {
        if ([fileName hasSuffix:@".pak"] && ![fileName hasSuffix:kBackupSuffix]) {
            SandboxEscapeRemoveFile([targetDir stringByAppendingPathComponent:fileName]);
        }
    }
    allFiles = [fm contentsOfDirectoryAtPath:targetDir error:nil];
    for (NSString *fileName in allFiles) {
        if ([fileName hasSuffix:kBackupSuffix]) {
            NSString *backupPath = [targetDir stringByAppendingPathComponent:fileName];
            NSString *originalName = [fileName stringByReplacingOccurrencesOfString:kBackupSuffix withString:@""];
            NSString *originalPath = [targetDir stringByAppendingPathComponent:originalName];
            SandboxEscapeCopyFile(backupPath, originalPath);
            SandboxEscapeRemoveFile(backupPath);
            if (SandboxEscapeIsActive()) SandboxEscapeChown(originalPath, 501, 501);
        }
    }

    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kCurrentMapKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    NSLog(@"[MapManager] 已恢复原始地图");
    return YES;
}

- (BOOL)isMapResourceAvailable:(MapType)mapType {
    MapInfo *mapInfo = nil;
    for (MapInfo *info in self.mapList) if (info.mapType == mapType) { mapInfo = info; break; }
    if (!mapInfo) return NO;
    NSString *path = [[self resourcePaksDirectory] stringByAppendingPathComponent:mapInfo.pakFileName];
    return [[NSFileManager defaultManager] fileExistsAtPath:path];
}

- (NSInteger)currentReplacedMapType {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults objectForKey:kCurrentMapKey] == nil) return -1;
    return [defaults integerForKey:kCurrentMapKey];
}

@end
