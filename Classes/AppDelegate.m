#import "AppDelegate.h"
#import "MapManager.h"
#import "UIOverlay.h"

@interface AppDelegate ()

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.backgroundColor = [UIColor whiteColor];
    
    // 创建主视图控制器
    UIViewController *mainVC = [[UIViewController alloc] init];
    mainVC.view.backgroundColor = [UIColor colorWithRed:0.96 green:0.96 blue:0.98 alpha:1.0];
    
    // 添加欢迎界面
    [self setupWelcomeUI:mainVC.view];
    
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:mainVC];
    self.window.rootViewController = nav;
    [self.window makeKeyAndVisible];
    
    // 延迟初始化插件功能
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"[MapReplacer] 初始化地图管理器...");
        
        // 初始化地图管理器
        MapManager *manager = [MapManager sharedManager];
        NSString *paksDir = [manager targetPaksDirectory];
        
        if (paksDir) {
            NSLog(@"[MapReplacer] 目标 Paks 目录: %@", paksDir);
        } else {
            NSLog(@"[MapReplacer] 警告: 未找到目标 Paks 目录");
        }
        
        // 显示悬浮按钮
        [[UIOverlay sharedOverlay] showFloatingButton];
        
        NSLog(@"[MapReplacer] 初始化完成！");
    });
    
    return YES;
}

- (void)setupWelcomeUI:(UIView *)view {
    // 标题
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 100, view.bounds.size.width - 40, 50)];
    titleLabel.text = @"MapReplacer";
    titleLabel.font = [UIFont systemFontOfSize:32 weight:UIFontWeightBold];
    titleLabel.textColor = [UIColor colorWithRed:0.0 green:0.48 blue:1.0 alpha:1.0];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [view addSubview:titleLabel];
    
    // 副标题
    UILabel *subtitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 160, view.bounds.size.width - 40, 30)];
    subtitleLabel.text = @"地图资源管理器";
    subtitleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightRegular];
    subtitleLabel.textColor = [UIColor colorWithRed:0.4 green:0.4 blue:0.45 alpha:1.0];
    subtitleLabel.textAlignment = NSTextAlignmentCenter;
    [view addSubview:subtitleLabel];
    
    // 说明文字
    NSString *infoText = @"点击屏幕右侧的悬浮按钮\n打开地图选择面板\n下载并管理游戏地图资源";
    UILabel *infoLabel = [[UILabel alloc] initWithFrame:CGRectMake(40, 250, view.bounds.size.width - 80, 100)];
    infoLabel.text = infoText;
    infoLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightRegular];
    infoLabel.textColor = [UIColor colorWithRed:0.4 green:0.4 blue:0.45 alpha:1.0];
    infoLabel.textAlignment = NSTextAlignmentCenter;
    infoLabel.numberOfLines = 0;
    [view addSubview:infoLabel];
    
    // 图标
    UILabel *iconLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 80, 80)];
    iconLabel.text = @"🗂";
    iconLabel.font = [UIFont systemFontOfSize:60];
    iconLabel.textAlignment = NSTextAlignmentCenter;
    iconLabel.center = CGPointMake(view.bounds.size.width / 2, 450);
    [view addSubview:iconLabel];
}

- (void)applicationWillResignActive:(UIApplication *)application {
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
}

- (void)applicationWillTerminate:(UIApplication *)application {
}

@end
