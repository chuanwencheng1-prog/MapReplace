#import "MapViewController.h"
#import "MapManager.h"

// ============================================================
// 颜色常量 - 与原 dylib 保持一致
// ============================================================
#define kPrimaryColor    [UIColor colorWithRed:0.0 green:0.48 blue:1.0 alpha:1.0]
#define kAccentColor     [UIColor colorWithRed:0.0 green:0.75 blue:0.5 alpha:1.0]
#define kBgColor         [UIColor colorWithRed:0.96 green:0.96 blue:0.98 alpha:1.0]
#define kCardBgColor     [UIColor whiteColor]
#define kTextPrimary     [UIColor colorWithRed:0.1 green:0.1 blue:0.12 alpha:1.0]
#define kTextSecondary   [UIColor colorWithRed:0.4 green:0.4 blue:0.45 alpha:1.0]
#define kSuccessColor    [UIColor colorWithRed:0.2 green:0.7 blue:0.3 alpha:1.0]
#define kDividerColor    [UIColor colorWithRed:0.9 green:0.9 blue:0.92 alpha:1.0]

@interface MapViewController ()
@property (nonatomic, strong) UIView *headerView;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) NSMutableDictionary<NSNumber*, UIButton*> *mapButtons;
@property (nonatomic, strong) NSMutableDictionary<NSNumber*, UIProgressView*> *progressViews;
@property (nonatomic, strong) NSMutableDictionary<NSNumber*, UILabel*> *statusLabels;
@end

@implementation MapViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = kBgColor;

    self.mapButtons = [NSMutableDictionary dictionary];
    self.progressViews = [NSMutableDictionary dictionary];
    self.statusLabels = [NSMutableDictionary dictionary];

    [self buildUI];
}

- (UIEdgeInsets)safeInsets {
    if (@available(iOS 11.0, *)) {
        return self.view.safeAreaInsets;
    }
    return UIEdgeInsetsMake(20, 0, 0, 0);
}

- (void)viewSafeAreaInsetsDidChange {
    if (@available(iOS 11.0, *)) {
        [super viewSafeAreaInsetsDidChange];
    }
    [self layoutContent];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self layoutContent];
}

- (void)buildUI {
    CGFloat width = self.view.bounds.size.width;

    // ---- 标题栏 ----
    self.headerView = [[UIView alloc] init];
    self.headerView.backgroundColor = kCardBgColor;
    [self.view addSubview:self.headerView];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.tag = 1001;
    titleLabel.text = @"地图资源管理器";
    titleLabel.textColor = kTextPrimary;
    titleLabel.font = [UIFont systemFontOfSize:22 weight:UIFontWeightSemibold];
    [self.headerView addSubview:titleLabel];

    UILabel *subtitle = [[UILabel alloc] init];
    subtitle.tag = 1002;
    subtitle.text = @"MapReplacer · IPA 版";
    subtitle.textColor = kTextSecondary;
    subtitle.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    [self.headerView addSubview:subtitle];

    // 状态标签
    UIView *infoView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 44)];
    infoView.tag = 2000;
    [self.view addSubview:infoView];

    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
    [infoView addSubview:self.statusLabel];
    [self refreshStatusLabel];

    // 滚动区
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.showsVerticalScrollIndicator = NO;
    [self.view addSubview:self.scrollView];

    [self buildCards];
}

- (void)refreshStatusLabel {
    NSString *paksDir = [[MapManager sharedManager] targetPaksDirectory];
    if (paksDir) {
        self.statusLabel.text = @"✓ 目标目录已就绪";
        self.statusLabel.textColor = kSuccessColor;
    } else {
        self.statusLabel.text = @"⚠ 未找到目标目录";
        self.statusLabel.textColor = [UIColor systemOrangeColor];
    }
}

- (void)layoutContent {
    UIEdgeInsets safe = [self safeInsets];
    CGFloat width = self.view.bounds.size.width;
    CGFloat height = self.view.bounds.size.height;
    CGFloat padding = 20;

    CGFloat headerH = 64;
    self.headerView.frame = CGRectMake(0, safe.top, width, headerH);

    UILabel *titleLabel = (UILabel *)[self.headerView viewWithTag:1001];
    UILabel *subtitle = (UILabel *)[self.headerView viewWithTag:1002];
    titleLabel.frame = CGRectMake(padding, 10, width - padding * 2, 28);
    subtitle.frame = CGRectMake(padding, 38, width - padding * 2, 18);

    // 底部分割线
    static NSInteger const kDividerTag = 1003;
    UIView *line = [self.headerView viewWithTag:kDividerTag];
    if (!line) {
        line = [[UIView alloc] init];
        line.tag = kDividerTag;
        line.backgroundColor = kDividerColor;
        [self.headerView addSubview:line];
    }
    line.frame = CGRectMake(0, headerH - 0.5, width, 0.5);

    // 状态信息条
    UIView *infoView = [self.view viewWithTag:2000];
    CGFloat infoY = safe.top + headerH;
    infoView.frame = CGRectMake(0, infoY, width, 40);
    self.statusLabel.frame = CGRectMake(padding, 8, width - padding * 2, 24);

    // 滚动区
    CGFloat scrollY = infoY + 40;
    CGFloat scrollH = height - scrollY - safe.bottom;
    self.scrollView.frame = CGRectMake(0, scrollY, width, scrollH);

    [self layoutCards];
}

- (void)buildCards {
    NSArray<MapInfo *> *maps = [[MapManager sharedManager] availableMaps];
    NSInteger currentMap = [[MapManager sharedManager] currentReplacedMapType];

    for (NSInteger i = 0; i < maps.count; i++) {
        MapInfo *info = maps[i];

        UIView *card = [[UIView alloc] init];
        card.tag = 3000 + info.mapType;
        card.backgroundColor = kCardBgColor;
        card.layer.cornerRadius = 12;
        card.layer.shadowColor = [UIColor blackColor].CGColor;
        card.layer.shadowOffset = CGSizeMake(0, 2);
        card.layer.shadowOpacity = 0.08;
        card.layer.shadowRadius = 6;
        [self.scrollView addSubview:card];

        UILabel *iconLabel = [[UILabel alloc] init];
        iconLabel.tag = 10;
        iconLabel.text = [self iconForMapType:info.mapType];
        iconLabel.font = [UIFont systemFontOfSize:28];
        iconLabel.textAlignment = NSTextAlignmentCenter;
        iconLabel.backgroundColor = [self bgColorForMapType:info.mapType];
        iconLabel.layer.cornerRadius = 10;
        iconLabel.clipsToBounds = YES;
        [card addSubview:iconLabel];

        UILabel *nameLabel = [[UILabel alloc] init];
        nameLabel.tag = 11;
        nameLabel.text = info.displayName;
        nameLabel.textColor = kTextPrimary;
        nameLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
        [card addSubview:nameLabel];

        UILabel *descLabel = [[UILabel alloc] init];
        descLabel.tag = 12;
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

        UIProgressView *progressView = [[UIProgressView alloc] init];
        progressView.tag = 13;
        progressView.progressTintColor = kPrimaryColor;
        progressView.trackTintColor = [UIColor colorWithRed:0.92 green:0.92 blue:0.94 alpha:1.0];
        progressView.hidden = YES;
        [card addSubview:progressView];
        self.progressViews[@(info.mapType)] = progressView;

        UILabel *stateLabel = [[UILabel alloc] init];
        stateLabel.tag = 14;
        stateLabel.textAlignment = NSTextAlignmentCenter;
        stateLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
        stateLabel.textColor = kTextSecondary;
        stateLabel.hidden = YES;
        [card addSubview:stateLabel];
        self.statusLabels[@(info.mapType)] = stateLabel;

        UIButton *actionBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        actionBtn.tag = info.mapType;
        actionBtn.backgroundColor = isCurrentMap ? kSuccessColor : kPrimaryColor;
        actionBtn.layer.cornerRadius = 8;
        [actionBtn setTitle:isCurrentMap ? @"已应用" : @"下载" forState:UIControlStateNormal];
        [actionBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        actionBtn.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
        actionBtn.enabled = !isCurrentMap;
        [actionBtn addTarget:self action:@selector(downloadButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        [card addSubview:actionBtn];
        self.mapButtons[@(info.mapType)] = actionBtn;
    }
}

- (void)layoutCards {
    CGFloat width = self.scrollView.bounds.size.width;
    CGFloat padding = 20;
    CGFloat cardHeight = 76;
    CGFloat cardSpacing = 12;
    CGFloat cardWidth = width - padding * 2;
    CGFloat y = 12;

    NSArray<MapInfo *> *maps = [[MapManager sharedManager] availableMaps];
    for (MapInfo *info in maps) {
        UIView *card = [self.scrollView viewWithTag:3000 + info.mapType];
        if (!card) continue;
        card.frame = CGRectMake(padding, y, cardWidth, cardHeight);

        UILabel *iconLabel = (UILabel *)[card viewWithTag:10];
        UILabel *nameLabel = (UILabel *)[card viewWithTag:11];
        UILabel *descLabel = (UILabel *)[card viewWithTag:12];
        UIProgressView *progressView = (UIProgressView *)[card viewWithTag:13];
        UILabel *stateLabel = (UILabel *)[card viewWithTag:14];
        UIButton *btn = self.mapButtons[@(info.mapType)];

        iconLabel.frame = CGRectMake(12, 12, 44, 44);
        nameLabel.frame = CGRectMake(66, 14, cardWidth - 66 - 90, 22);
        descLabel.frame = CGRectMake(66, 38, cardWidth - 66 - 90, 18);
        btn.frame = CGRectMake(cardWidth - 82, 21, 70, 34);
        progressView.frame = CGRectMake(12, cardHeight - 6, cardWidth - 24, 3);
        stateLabel.frame = CGRectMake(12, cardHeight - 22, cardWidth - 24, 14);

        y += cardHeight + cardSpacing;
    }
    self.scrollView.contentSize = CGSizeMake(width, y + 12);
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

#pragma mark - 按钮事件

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
                stateLabel.text = [NSString stringWithFormat:@"✗ 下载失败: %@", error.localizedDescription];
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

        // 同步更新卡片描述
        UIView *card = [self.scrollView viewWithTag:3000 + type];
        UILabel *descLabel = (UILabel *)[card viewWithTag:12];
        if (isCurrent) {
            descLabel.text = @"✓ 当前使用";
            descLabel.textColor = kSuccessColor;
        } else {
            descLabel.text = @"点击下载";
            descLabel.textColor = kTextSecondary;
        }
    }
}

@end
