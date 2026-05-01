//
//  MainViewController.m
//  MapReplacerApp
//
//  ⚠ UI 与交互逻辑完全对齐 MapReplacer/UIOverlay.m 的面板部分：
//     - 顶部 header (标题 + 关闭/刷新按钮)
//     - 目标目录状态栏
//     - 地图卡片列表 (图标/名称/状态/进度条/下载按钮)
//
#import "MainViewController.h"
#import "MapManager.h"
#import "SandboxEscape.h"

// ============================================================
// 颜色常量 - 与原 UIOverlay 保持一致
// ============================================================
#define kPrimaryColor    [UIColor colorWithRed:0.0 green:0.48 blue:1.0 alpha:1.0]
#define kAccentColor     [UIColor colorWithRed:0.0 green:0.75 blue:0.5 alpha:1.0]
#define kBgColor         [UIColor colorWithRed:0.96 green:0.96 blue:0.98 alpha:1.0]
#define kCardBgColor     [UIColor whiteColor]
#define kTextPrimary     [UIColor colorWithRed:0.1 green:0.1 blue:0.12 alpha:1.0]
#define kTextSecondary   [UIColor colorWithRed:0.4 green:0.4 blue:0.45 alpha:1.0]
#define kSuccessColor    [UIColor colorWithRed:0.2 green:0.7 blue:0.3 alpha:1.0]
#define kDividerColor    [UIColor colorWithRed:0.9 green:0.9 blue:0.92 alpha:1.0]

@interface MainViewController ()
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UILabel *escapeStatusLabel;
@property (nonatomic, strong) NSMutableDictionary<NSNumber*, UIButton*> *mapButtons;
@property (nonatomic, strong) NSMutableDictionary<NSNumber*, UIProgressView*> *progressViews;
@property (nonatomic, strong) NSMutableDictionary<NSNumber*, UILabel*> *statusLabels;
@property (nonatomic, strong) UIView *cardContainer;
@end

@implementation MainViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = kBgColor;
    self.mapButtons = [NSMutableDictionary dictionary];
    self.progressViews = [NSMutableDictionary dictionary];
    self.statusLabels = [NSMutableDictionary dictionary];

    [self buildUI];

    // 每次前台切回刷新一次状态
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(refreshAllButtons)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self updateStatusLabels];
    [self refreshAllButtons];
}

#pragma mark - UI 构建

- (void)buildUI {
    CGFloat screenWidth = self.view.bounds.size.width;
    CGFloat padding = 20;
    CGFloat yOffset = 0;

    // safeArea top
    CGFloat safeTop = 0;
    if (@available(iOS 11.0, *)) {
        safeTop = [UIApplication sharedApplication].keyWindow.safeAreaInsets.top;
        if (safeTop <= 0) safeTop = 20;
    } else {
        safeTop = 20;
    }
    yOffset = safeTop;

    // ---- 标题栏 ----
    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, yOffset, screenWidth, 60)];
    headerView.backgroundColor = kCardBgColor;
    [self.view addSubview:headerView];

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(padding, 15, screenWidth - 120, 30)];
    titleLabel.text = @"地图资源管理器";
    titleLabel.textColor = kTextPrimary;
    titleLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightSemibold];
    [headerView addSubview:titleLabel];

    // 刷新按钮 (替代原关闭按钮，因为主界面不需要关闭)
    UIButton *refreshBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    refreshBtn.frame = CGRectMake(screenWidth - 95, 15, 35, 35);
    refreshBtn.backgroundColor = [UIColor colorWithRed:0.94 green:0.94 blue:0.96 alpha:1.0];
    refreshBtn.layer.cornerRadius = 17.5;
    [refreshBtn setTitle:@"↻" forState:UIControlStateNormal];
    [refreshBtn setTitleColor:kTextSecondary forState:UIControlStateNormal];
    refreshBtn.titleLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightMedium];
    [refreshBtn addTarget:self action:@selector(refreshButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [headerView addSubview:refreshBtn];

    // 恢复按钮
    UIButton *restoreBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    restoreBtn.frame = CGRectMake(screenWidth - 55, 15, 35, 35);
    restoreBtn.backgroundColor = [UIColor colorWithRed:0.94 green:0.94 blue:0.96 alpha:1.0];
    restoreBtn.layer.cornerRadius = 17.5;
    [restoreBtn setTitle:@"⎌" forState:UIControlStateNormal];
    [restoreBtn setTitleColor:[UIColor systemOrangeColor] forState:UIControlStateNormal];
    restoreBtn.titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightMedium];
    [restoreBtn addTarget:self action:@selector(restoreButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [headerView addSubview:restoreBtn];

    yOffset += 60;

    // ---- 逃逸状态栏 ----
    self.escapeStatusLabel = [[UILabel alloc] initWithFrame:CGRectMake(padding, yOffset + 6, screenWidth - padding * 2, 22)];
    self.escapeStatusLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    self.escapeStatusLabel.textAlignment = NSTextAlignmentLeft;
    [self.view addSubview:self.escapeStatusLabel];

    yOffset += 28;

    // ---- 目标目录状态栏 ----
    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(padding, yOffset + 6, screenWidth - padding * 2, 22)];
    self.statusLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    [self.view addSubview:self.statusLabel];

    yOffset += 32;

    // ---- 地图列表 (ScrollView) ----
    CGFloat bottomSafe = 0;
    if (@available(iOS 11.0, *)) {
        bottomSafe = [UIApplication sharedApplication].keyWindow.safeAreaInsets.bottom;
    }
    self.scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, yOffset, screenWidth,
                                                                      self.view.bounds.size.height - yOffset - bottomSafe)];
    self.scrollView.showsVerticalScrollIndicator = NO;
    [self.view addSubview:self.scrollView];

    self.cardContainer = [[UIView alloc] initWithFrame:self.scrollView.bounds];
    [self.scrollView addSubview:self.cardContainer];

    [self buildCards];
    [self updateStatusLabels];
}

- (void)buildCards {
    // 清理旧卡片
    for (UIView *sub in self.cardContainer.subviews) [sub removeFromSuperview];
    [self.mapButtons removeAllObjects];
    [self.progressViews removeAllObjects];
    [self.statusLabels removeAllObjects];

    CGFloat screenWidth = self.view.bounds.size.width;
    CGFloat padding = 20;
    CGFloat scrollY = 10;

    NSArray<MapInfo *> *maps = [[MapManager sharedManager] availableMaps];
    NSInteger currentMap = [[MapManager sharedManager] currentReplacedMapType];

    for (NSInteger i = 0; i < maps.count; i++) {
        MapInfo *info = maps[i];
        CGFloat cardHeight = 70;
        CGFloat cardSpacing = 10;

        UIView *card = [[UIView alloc] initWithFrame:CGRectMake(padding, scrollY, screenWidth - padding * 2, cardHeight)];
        card.backgroundColor = kCardBgColor;
        card.layer.cornerRadius = 12;
        card.layer.shadowColor = [UIColor blackColor].CGColor;
        card.layer.shadowOffset = CGSizeMake(0, 2);
        card.layer.shadowOpacity = 0.08;
        card.layer.shadowRadius = 6;
        [self.cardContainer addSubview:card];

        UILabel *iconLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 10, 40, 40)];
        iconLabel.text = [self iconForMapType:info.mapType];
        iconLabel.font = [UIFont systemFontOfSize:28];
        iconLabel.textAlignment = NSTextAlignmentCenter;
        iconLabel.backgroundColor = [self bgColorForMapType:info.mapType];
        iconLabel.layer.cornerRadius = 10;
        iconLabel.clipsToBounds = YES;
        [card addSubview:iconLabel];

        UILabel *nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(60, 12, screenWidth - padding * 2 - 75, 22)];
        nameLabel.text = info.displayName;
        nameLabel.textColor = kTextPrimary;
        nameLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
        [card addSubview:nameLabel];

        UILabel *descLabel = [[UILabel alloc] initWithFrame:CGRectMake(60, 34, screenWidth - padding * 2 - 75, 18)];
        BOOL isCurrentMap = (currentMap == info.mapType);
        if (isCurrentMap) {
            descLabel.text = @"✓ 当前使用";
            descLabel.textColor = kSuccessColor;
        } else {
            descLabel.text = @"点击下载";
            descLabel.textColor = kTextSecondary;
        }
        descLabel.font = [UIFont systemFontOfSize:12];
        [card addSubview:descLabel];

        UIProgressView *progressView = [[UIProgressView alloc] initWithFrame:CGRectMake(12, cardHeight - 8, screenWidth - padding * 2 - 24, 4)];
        progressView.progressTintColor = kPrimaryColor;
        progressView.trackTintColor = [UIColor colorWithRed:0.92 green:0.92 blue:0.94 alpha:1.0];
        progressView.hidden = YES;
        [card addSubview:progressView];
        self.progressViews[@(info.mapType)] = progressView;

        UILabel *stateLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, cardHeight - 22, screenWidth - padding * 2 - 24, 14)];
        stateLabel.textAlignment = NSTextAlignmentCenter;
        stateLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
        stateLabel.textColor = kTextSecondary;
        stateLabel.hidden = YES;
        [card addSubview:stateLabel];
        self.statusLabels[@(info.mapType)] = stateLabel;

        UIButton *actionBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        actionBtn.frame = CGRectMake(screenWidth - padding * 2 - 70, 18, 58, 34);
        actionBtn.backgroundColor = isCurrentMap ? kSuccessColor : kPrimaryColor;
        actionBtn.layer.cornerRadius = 8;
        actionBtn.tag = info.mapType;
        [actionBtn setTitle:isCurrentMap ? @"已应用" : @"下载" forState:UIControlStateNormal];
        [actionBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        actionBtn.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
        actionBtn.enabled = !isCurrentMap;
        [actionBtn addTarget:self action:@selector(downloadButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        [card addSubview:actionBtn];
        self.mapButtons[@(info.mapType)] = actionBtn;

        if (i < maps.count - 1) {
            UIView *divider = [[UIView alloc] initWithFrame:CGRectMake(padding, scrollY + cardHeight + cardSpacing/2 - 0.5, screenWidth - padding * 2, 1)];
            divider.backgroundColor = kDividerColor;
            [self.cardContainer addSubview:divider];
        }

        scrollY += cardHeight + cardSpacing;
    }

    self.cardContainer.frame = CGRectMake(0, 0, screenWidth, scrollY + 20);
    self.scrollView.contentSize = CGSizeMake(screenWidth, scrollY + 20);
}

#pragma mark - 状态刷新

- (void)updateStatusLabels {
    // 沙箱逃逸状态
    if (SandboxEscapeIsActive()) {
        self.escapeStatusLabel.text = @"🔓 Sandbox Escape: 已激活 (DarkSword)";
        self.escapeStatusLabel.textColor = kSuccessColor;
    } else {
        self.escapeStatusLabel.text = @"🔒 Sandbox Escape: 未激活 (写入当前 App 沙箱)";
        self.escapeStatusLabel.textColor = [UIColor systemOrangeColor];
    }

    // 目标目录
    NSString *paksDir = [[MapManager sharedManager] targetPaksDirectory];
    if (paksDir) {
        self.statusLabel.text = @"✓ 目标 Paks 目录已就绪";
        self.statusLabel.textColor = kSuccessColor;
    } else {
        self.statusLabel.text = @"⚠ 未找到目标 Paks 目录";
        self.statusLabel.textColor = [UIColor systemOrangeColor];
    }
}

- (NSString *)iconForMapType:(MapType)type {
    NSArray *icons = @[@"🏝", @"🏜", @"🌴", @"❄", @"🗺", @"🏔"];
    return type < icons.count ? icons[type] : @"📦";
}

- (UIColor *)bgColorForMapType:(MapType)type {
    NSArray *colors = @[
        [UIColor colorWithRed:0.9 green:0.95 blue:1.0 alpha:1.0],
        [UIColor colorWithRed:1.0 green:0.95 blue:0.9 alpha:1.0],
        [UIColor colorWithRed:0.9 green:1.0 blue:0.9 alpha:1.0],
        [UIColor colorWithRed:0.92 green:0.94 blue:1.0 alpha:1.0],
        [UIColor colorWithRed:0.95 green:0.92 blue:1.0 alpha:1.0],
        [UIColor colorWithRed:1.0 green:0.92 blue:0.9 alpha:1.0]
    ];
    return type < colors.count ? colors[type] : [UIColor colorWithRed:0.95 green:0.95 blue:0.95 alpha:1.0];
}

#pragma mark - 按钮事件 (与原 UIOverlay 一致)

- (void)downloadButtonTapped:(UIButton *)sender {
    MapType type = (MapType)sender.tag;
    MapInfo *info = nil;
    for (MapInfo *m in [[MapManager sharedManager] availableMaps]) {
        if (m.mapType == type) { info = m; break; }
    }
    if (!info) return;

    sender.enabled = NO;
    sender.backgroundColor = [UIColor colorWithRed:0.85 green:0.85 blue:0.87 alpha:1.0];
    [sender setTitle:@"准备中" forState:UIControlStateNormal];

    UIProgressView *progressView = self.progressViews[@(type)];
    UILabel *stateLabel = self.statusLabels[@(type)];
    progressView.hidden = NO;
    stateLabel.hidden = NO;
    progressView.progress = 0;
    stateLabel.text = @"正在下载...";
    stateLabel.textColor = kPrimaryColor;

    [[MapManager sharedManager] downloadMapWithType:type
                                           progress:^(float progress) {
        dispatch_async(dispatch_get_main_queue(), ^{
            progressView.progress = progress;
            stateLabel.text = [NSString stringWithFormat:@"下载中 %.0f%%", progress * 100];
        });
    } completion:^(BOOL success, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) {
                stateLabel.text = @"✓ 已完成";
                stateLabel.textColor = kSuccessColor;
                sender.backgroundColor = kSuccessColor;
                [sender setTitle:@"已应用" forState:UIControlStateNormal];
                [self refreshAllButtons];
            } else {
                stateLabel.text = [NSString stringWithFormat:@"✗ 失败: %@", error.localizedDescription];
                stateLabel.textColor = [UIColor systemRedColor];
                sender.enabled = YES;
                sender.backgroundColor = kPrimaryColor;
                [sender setTitle:@"重试" forState:UIControlStateNormal];
            }
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                progressView.hidden = YES;
                stateLabel.hidden = YES;
            });
        });
    }];
}

- (void)refreshAllButtons {
    NSInteger currentMap = [[MapManager sharedManager] currentReplacedMapType];
    for (NSNumber *key in self.mapButtons) {
        UIButton *btn = self.mapButtons[key];
        MapType type = (MapType)[key integerValue];
        BOOL isCurrent = (currentMap == type);
        btn.enabled = !isCurrent;
        btn.backgroundColor = isCurrent ? kSuccessColor : kPrimaryColor;
        [btn setTitle:isCurrent ? @"已应用" : @"下载" forState:UIControlStateNormal];
    }
    [self updateStatusLabels];
}

- (void)refreshButtonTapped {
    // 重新探测目标 Paks (若 DarkSword 生效)
    if (SandboxEscapeIsActive()) {
        NSString *paks = SandboxEscapeFindPaksForBundleID(@"com.tencent.ig");
        if (paks) [[MapManager sharedManager] overrideTargetPaksDirectory:paks];
    }
    [self buildCards];
    [self updateStatusLabels];
}

- (void)restoreButtonTapped {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"恢复原始地图"
                                                                   message:@"是否恢复原始 pak 文件并删除当前替换？"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"恢复" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
        NSError *err = nil;
        BOOL ok = [[MapManager sharedManager] restoreOriginalMapWithError:&err];
        UIAlertController *res = [UIAlertController alertControllerWithTitle:ok ? @"完成" : @"失败"
                                                                     message:ok ? @"已恢复原始地图文件" : err.localizedDescription
                                                              preferredStyle:UIAlertControllerStyleAlert];
        [res addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:res animated:YES completion:nil];
        [self refreshAllButtons];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
