//
//  PersonalCenterTweak.m
//  dylib 入口：宿主 App 启动后把 PersonalCenterViewController 以全屏覆盖层弹出。
//
//  编译产物为 dylib，放入目标 .app 目录下，通过 insert_dylib 给主二进制追加
//  LC_LOAD_WEAK_DYLIB @executable_path/xxx.dylib 即可生效。
//

#import <UIKit/UIKit.h>
#import "PersonalCenterViewController.h"

@interface PersonalCenterTweak : NSObject
@end

@implementation PersonalCenterTweak

+ (void)load {
    // +load 早于 main，此处只做注册；真正创建 UI 等 App 完成启动
    [[NSNotificationCenter defaultCenter]
        addObserver:[self class]
           selector:@selector(presentOverlay)
               name:UIApplicationDidFinishLaunchingNotification
             object:nil];
}

+ (void)presentOverlay {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = [PersonalCenterTweak findKeyWindow];
        UIViewController *root = keyWindow.rootViewController;
        if (!root) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                [PersonalCenterTweak presentOverlay];
            });
            return;
        }

        PersonalCenterViewController *vc = [[PersonalCenterViewController alloc] init];
        vc.modalPresentationStyle = UIModalPresentationFullScreen;

        UIViewController *top = root;
        while (top.presentedViewController) top = top.presentedViewController;
        [top presentViewController:vc animated:NO completion:nil];
    });
}

+ (UIWindow *)findKeyWindow {
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            if (scene.activationState != UISceneActivationStateForegroundActive &&
                scene.activationState != UISceneActivationStateForegroundInactive) continue;
            for (UIWindow *w in ((UIWindowScene *)scene).windows) {
                if (w.isKeyWindow) return w;
            }
            for (UIWindow *w in ((UIWindowScene *)scene).windows) {
                if (!w.hidden) return w;
            }
        }
    }
    return [UIApplication sharedApplication].keyWindow;
}

@end
