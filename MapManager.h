//
//  MapManager.h
//  MapReplacerApp
//
//  🛈 逻辑与原 MapReplacer/MapManager.h 完全一致，仅新增 overrideTargetPaksDirectory:
//
#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, MapType) {
    MapTypeBaltic = 0,   // 海岛 (Erangel)
    MapTypeDesert,       // 沙漠 (Miramar)
    MapTypeSavage,       // 雨林 (Sanhok)
    MapTypeDihor,        // 雪地 (Vikendi)
    MapTypeLivik,        // Livik
    MapTypeKarakin,      // Karakin
    MapTypeCount
};

@interface MapInfo : NSObject
@property (nonatomic, copy) NSString *displayName;
@property (nonatomic, copy) NSString *pakFileName;
@property (nonatomic, copy) NSString *iconName;
@property (nonatomic, assign) MapType mapType;
+ (instancetype)infoWithName:(NSString *)name pakFile:(NSString *)pakFile type:(MapType)type;
@end

@interface MapManager : NSObject <NSURLSessionDownloadDelegate>

+ (instancetype)sharedManager;

- (NSArray<MapInfo *> *)availableMaps;

- (NSString *)targetPaksDirectory;
- (NSString *)resourcePaksDirectory;

/// 由 SandboxEscape 定位到的目标 App Paks 目录，用来覆盖默认 (当前 App Documents)
- (void)overrideTargetPaksDirectory:(NSString *)path;

- (void)downloadMapWithType:(MapType)mapType
                   progress:(void(^)(float progress))progressBlock
                 completion:(void(^)(BOOL success, NSError *error))completionBlock;

- (BOOL)replaceMapWithType:(MapType)mapType error:(NSError **)error;
- (BOOL)restoreOriginalMapWithError:(NSError **)error;
- (BOOL)isMapResourceAvailable:(MapType)mapType;
- (NSInteger)currentReplacedMapType;

@property (nonatomic, copy) void(^progressCallback)(float progress);
@property (nonatomic, copy) void(^completionCallback)(BOOL success, NSError *error);

@end
