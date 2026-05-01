//
//  AppDelegate.m
//  MapReplacerApp
//
//  启动流程：
//    1. 尝试初始化 DarkSword 沙箱逃逸 (需 krw 环境)
//    2. 不论逃逸是否成功，都展示 MainViewController（UI/逻辑与原 tweak 一致）
//
#import "AppDelegate.h"
#import "MainViewController.h"
#import "SandboxEscape.h"
#import "MapManager.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    NSLog(@"[MapReplacerApp] ============================================");
    NSLog(@"[MapReplacerApp]  MapReplacer 独立 IPA v1.0.0");
    NSLog(@"[MapReplacerApp]  构建时间: %s %s", __DATE__, __TIME__);
    NSLog(@"[MapReplacerApp] ============================================");

    // ---- 尝试执行 DarkSword 沙箱逃逸 (后台异步，避免阻塞 UI) ----
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        BOOL ok = SandboxEscapeInit();
        NSLog(@"[MapReplacerApp] SandboxEscapeInit => %@", ok ? @"SUCCESS" : @"FAILED (回退至沙箱内写入)");

        // 如果逃逸成功，让 MapManager 尝试发现目标 App 容器的 Paks 目录
        if (ok) {
            NSString *paks = SandboxEscapeFindPaksForBundleID(@"com.tencent.ig");
            if (paks) {
                [[MapManager sharedManager] overrideTargetPaksDirectory:paks];
                NSLog(@"[MapReplacerApp] ✓ 已定位目标 Paks: %@", paks);
            }
        }
    });

    // ---- 主界面：直接使用 MapReplacer 的面板布局 (去除悬浮窗) ----
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];

    MainViewController *rootVC = [[MainViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:rootVC];
    nav.navigationBar.hidden = YES;

    self.window.rootViewController = nav;
    [self.window makeKeyAndVisible];

    return YES;
}

@end
