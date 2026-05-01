#import "AppDelegate.h"
#import "MapViewController.h"
#import "MapManager.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {

    NSLog(@"[MapReplacer] ============================================");
    NSLog(@"[MapReplacer]  地图替换器 IPA v1.0.0 已启动");
    NSLog(@"[MapReplacer] ============================================");

    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];

    MapViewController *viewController = [[MapViewController alloc] init];
    self.window.rootViewController = viewController;
    [self.window makeKeyAndVisible];

    // 预热 MapManager
    MapManager *manager = [MapManager sharedManager];
    NSString *paksDir = [manager targetPaksDirectory];
    NSString *resDir = [manager resourcePaksDirectory];
    NSLog(@"[MapReplacer] 目标 Paks 目录: %@", paksDir ?: @"(未就绪)");
    NSLog(@"[MapReplacer] 资源目录: %@", resDir ?: @"(未就绪)");

    return YES;
}

@end
