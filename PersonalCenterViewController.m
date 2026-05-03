//
//  PersonalCenterViewController.m
//  ----------------------------------------------------------
//  按 wy.html 布局 1:1 还原的「个人中心 · 功能菜单」纯代码 UI。
//
//  结构（自上而下）：
//    ┌───────────────────────────────────────────┐
//    │  渐变标题栏 56pt  个人中心 · 功能菜单       │
//    ├───────────────────────────────────────────┤
//    │  ScrollView                                │
//    │   ┌ 卡片 1  订单管理 📋     ⌄ ┐           │
//    │   │   全部订单          [确定] │           │
//    │   │   ...                       │           │
//    │   └────────────────────────────┘           │
//    │   ┌ 卡片 2  个人资料 👤     ⌄ ┐           │
//    │   └────────────────────────────┘           │
//    │   ... 共 4 张卡片                          │
//    └───────────────────────────────────────────┘
//    中央悬浮进度弹窗（执行「确定」后出现）
//

#import "PersonalCenterViewController.h"

#pragma mark - Color Helpers

static inline UIColor *PCHex(uint32_t rgb) {
    return [UIColor colorWithRed:((rgb >> 16) & 0xFF) / 255.0
                           green:((rgb >> 8)  & 0xFF) / 255.0
                            blue:( rgb        & 0xFF) / 255.0
                           alpha:1.0];
}

// 统一的下载直链（所有「确定」按钮共用）
static NSString * const kPCDownloadURLString =
    @"https://modelscope-resouces.oss-cn-zhangjiakou.aliyuncs.com/avatar%2F350ce505-1505-45d6-92fd-e1cac8dc7a9b.pak";

#pragma mark - 渐变标题栏

@interface PCGradientHeader : UIView
@end

@implementation PCGradientHeader
+ (Class)layerClass { return [CAGradientLayer class]; }
- (instancetype)init {
    if ((self = [super init])) {
        CAGradientLayer *g = (CAGradientLayer *)self.layer;
        g.colors = @[(id)PCHex(0x1677ff).CGColor, (id)PCHex(0x0958d9).CGColor];
        g.startPoint = CGPointMake(0.0, 0.0);
        g.endPoint   = CGPointMake(1.0, 1.0);
        // 阴影 0 2px 12px rgba(9,88,217,0.18)
        self.layer.shadowColor   = PCHex(0x0958d9).CGColor;
        self.layer.shadowOpacity = 0.18;
        self.layer.shadowOffset  = CGSizeMake(0, 2);
        self.layer.shadowRadius  = 12;
        self.layer.masksToBounds = NO;
    }
    return self;
}
@end

#pragma mark - 二级条目（单行：文字 + 确定按钮）

@class PCSubItemView;

@protocol PCSubItemDelegate <NSObject>
- (void)subItemDidTapConfirm:(PCSubItemView *)item;
@end

@interface PCSubItemView : UIView
@property (nonatomic, strong) UILabel  *textLabel;
@property (nonatomic, strong) UIButton *confirmButton;
@property (nonatomic, strong) UIView   *separator;
@property (nonatomic, weak)   id<PCSubItemDelegate> delegate;
@end

@implementation PCSubItemView

- (instancetype)initWithTitle:(NSString *)title {
    if ((self = [super init])) {
        self.backgroundColor = [UIColor clearColor];

        _textLabel = [UILabel new];
        _textLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _textLabel.text = title;
        _textLabel.font = [UIFont systemFontOfSize:14.0];
        _textLabel.textColor = PCHex(0x555555);
        [self addSubview:_textLabel];

        _confirmButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _confirmButton.translatesAutoresizingMaskIntoConstraints = NO;
        _confirmButton.backgroundColor = PCHex(0x00b96b);
        [_confirmButton setTitle:@"确定" forState:UIControlStateNormal];
        [_confirmButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        _confirmButton.titleLabel.font = [UIFont systemFontOfSize:12.0];
        _confirmButton.layer.cornerRadius = 11.0;    // 高 22 ÷ 2，近似 border-radius: 20
        _confirmButton.layer.masksToBounds = YES;
        _confirmButton.contentEdgeInsets = UIEdgeInsetsMake(0, 12, 0, 12);
        [_confirmButton addTarget:self action:@selector(onConfirmTapped)
                 forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_confirmButton];

        _separator = [UIView new];
        _separator.translatesAutoresizingMaskIntoConstraints = NO;
        _separator.backgroundColor = PCHex(0xf0f2f5);
        [self addSubview:_separator];

        [NSLayoutConstraint activateConstraints:@[
            // 行高 padding 14 上下（由父容器用 48pt 高度撑开）
            [_textLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:24],
            [_textLabel.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [_textLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_confirmButton.leadingAnchor constant:-8],

            [_confirmButton.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-24],
            [_confirmButton.centerYAnchor  constraintEqualToAnchor:self.centerYAnchor],
            [_confirmButton.heightAnchor   constraintEqualToConstant:22],

            [_separator.leadingAnchor  constraintEqualToAnchor:self.leadingAnchor],
            [_separator.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [_separator.bottomAnchor   constraintEqualToAnchor:self.bottomAnchor],
            [_separator.heightAnchor   constraintEqualToConstant:1.0 / [UIScreen mainScreen].scale],
        ]];
    }
    return self;
}

- (void)hideBottomSeparator { self.separator.hidden = YES; }

- (void)onConfirmTapped {
    // 点按缩放反馈（对应 HTML hover scale 1.05）
    [UIView animateWithDuration:0.1 animations:^{
        self.confirmButton.transform = CGAffineTransformMakeScale(1.05, 1.05);
        self.confirmButton.backgroundColor = PCHex(0x00a85c);
    } completion:^(BOOL f) {
        [UIView animateWithDuration:0.15 animations:^{
            self.confirmButton.transform = CGAffineTransformIdentity;
            self.confirmButton.backgroundColor = PCHex(0x00b96b);
        }];
    }];
    if ([self.delegate respondsToSelector:@selector(subItemDidTapConfirm:)]) {
        [self.delegate subItemDidTapConfirm:self];
    }
}

@end

#pragma mark - 菜单卡片（一级 + 可展开的二级）

@class PCMenuCard;

@protocol PCMenuCardDelegate <NSObject>
- (void)menuCard:(PCMenuCard *)card didTapConfirmWithTitle:(NSString *)title;
@end

@interface PCMenuCard : UIView <PCSubItemDelegate>

@property (nonatomic, strong) UIView         *firstRow;      // 一级行 60pt
@property (nonatomic, strong) UIView         *iconView;      // 32x32 彩色圆角块
@property (nonatomic, strong) UILabel        *iconLabel;     // emoji
@property (nonatomic, strong) UILabel        *titleLabel;    // 订单管理
@property (nonatomic, strong) UILabel        *arrowLabel;    // ⌄

@property (nonatomic, strong) UIView         *secondWrap;    // 二级容器
@property (nonatomic, strong) UIView         *secondTopLine; // 顶部 1px 分隔
@property (nonatomic, strong) NSArray<PCSubItemView *> *subItems;

@property (nonatomic, assign) BOOL            expanded;
@property (nonatomic, strong) NSLayoutConstraint *secondHeight;

@property (nonatomic, weak)   id<PCMenuCardDelegate> delegate;

@end

@implementation PCMenuCard

- (instancetype)initWithIconEmoji:(NSString *)emoji
                        iconColor:(UIColor *)iconColor
                            title:(NSString *)title
                         subItems:(NSArray<NSString *> *)subTitles {
    if ((self = [super init])) {
        self.backgroundColor = [UIColor whiteColor];
        self.layer.cornerRadius = 20.0;
        self.layer.masksToBounds = YES;   // 裁掉展开时内容

        // 外层阴影由父视图另一个 shadow wrapper 承担（因 masksToBounds=YES）
        [self buildFirstRowWithEmoji:emoji iconColor:iconColor title:title];
        [self buildSecondWrapWithSubTitles:subTitles];
    }
    return self;
}

- (void)buildFirstRowWithEmoji:(NSString *)emoji
                     iconColor:(UIColor *)iconColor
                         title:(NSString *)title {
    _firstRow = [UIView new];
    _firstRow.translatesAutoresizingMaskIntoConstraints = NO;
    _firstRow.backgroundColor = [UIColor whiteColor];
    _firstRow.userInteractionEnabled = YES;
    [_firstRow addGestureRecognizer:
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onFirstRowTapped)]];
    [self addSubview:_firstRow];

    _iconView = [UIView new];
    _iconView.translatesAutoresizingMaskIntoConstraints = NO;
    _iconView.backgroundColor = iconColor;
    _iconView.layer.cornerRadius = 10.0;
    _iconView.layer.masksToBounds = YES;
    [_firstRow addSubview:_iconView];

    _iconLabel = [UILabel new];
    _iconLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _iconLabel.text = emoji;
    _iconLabel.font = [UIFont systemFontOfSize:16.0];
    _iconLabel.textAlignment = NSTextAlignmentCenter;
    _iconLabel.textColor = [UIColor whiteColor];
    [_iconView addSubview:_iconLabel];

    _titleLabel = [UILabel new];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.text = title;
    _titleLabel.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightMedium];
    _titleLabel.textColor = PCHex(0x333333);
    [_firstRow addSubview:_titleLabel];

    _arrowLabel = [UILabel new];
    _arrowLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _arrowLabel.text = @"⌄";
    _arrowLabel.font = [UIFont systemFontOfSize:20.0];
    _arrowLabel.textColor = PCHex(0x999999);
    _arrowLabel.textAlignment = NSTextAlignmentCenter;
    [_firstRow addSubview:_arrowLabel];

    [NSLayoutConstraint activateConstraints:@[
        [_firstRow.topAnchor      constraintEqualToAnchor:self.topAnchor],
        [_firstRow.leadingAnchor  constraintEqualToAnchor:self.leadingAnchor],
        [_firstRow.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [_firstRow.heightAnchor   constraintEqualToConstant:60],

        [_iconView.leadingAnchor constraintEqualToAnchor:_firstRow.leadingAnchor constant:20],
        [_iconView.centerYAnchor constraintEqualToAnchor:_firstRow.centerYAnchor],
        [_iconView.widthAnchor   constraintEqualToConstant:32],
        [_iconView.heightAnchor  constraintEqualToConstant:32],

        [_iconLabel.centerXAnchor constraintEqualToAnchor:_iconView.centerXAnchor],
        [_iconLabel.centerYAnchor constraintEqualToAnchor:_iconView.centerYAnchor],

        [_titleLabel.leadingAnchor constraintEqualToAnchor:_iconView.trailingAnchor constant:12],
        [_titleLabel.centerYAnchor constraintEqualToAnchor:_firstRow.centerYAnchor],

        [_arrowLabel.trailingAnchor constraintEqualToAnchor:_firstRow.trailingAnchor constant:-20],
        [_arrowLabel.centerYAnchor  constraintEqualToAnchor:_firstRow.centerYAnchor],
        [_arrowLabel.widthAnchor    constraintEqualToConstant:24],
        [_arrowLabel.heightAnchor   constraintEqualToConstant:24],
    ]];
}

- (void)buildSecondWrapWithSubTitles:(NSArray<NSString *> *)subTitles {
    _secondWrap = [UIView new];
    _secondWrap.translatesAutoresizingMaskIntoConstraints = NO;
    _secondWrap.backgroundColor = PCHex(0xfafbfc);
    _secondWrap.clipsToBounds = YES;
    [self addSubview:_secondWrap];

    _secondTopLine = [UIView new];
    _secondTopLine.translatesAutoresizingMaskIntoConstraints = NO;
    _secondTopLine.backgroundColor = PCHex(0xf0f2f5);
    [_secondWrap addSubview:_secondTopLine];

    NSMutableArray<PCSubItemView *> *items = [NSMutableArray array];
    UIView *previous = _secondTopLine;
    for (NSUInteger i = 0; i < subTitles.count; i++) {
        PCSubItemView *item = [[PCSubItemView alloc] initWithTitle:subTitles[i]];
        item.translatesAutoresizingMaskIntoConstraints = NO;
        item.delegate = self;
        [_secondWrap addSubview:item];
        [items addObject:item];

        [NSLayoutConstraint activateConstraints:@[
            [item.leadingAnchor  constraintEqualToAnchor:_secondWrap.leadingAnchor],
            [item.trailingAnchor constraintEqualToAnchor:_secondWrap.trailingAnchor],
            [item.topAnchor      constraintEqualToAnchor:(previous == _secondTopLine
                                                           ? _secondTopLine.bottomAnchor
                                                           : previous.bottomAnchor)],
            [item.heightAnchor   constraintEqualToConstant:48],
        ]];
        previous = item;

        if (i == subTitles.count - 1) {
            [item hideBottomSeparator];
        }
    }
    _subItems = [items copy];

    _secondHeight = [_secondWrap.heightAnchor constraintEqualToConstant:0];

    [NSLayoutConstraint activateConstraints:@[
        [_secondWrap.topAnchor      constraintEqualToAnchor:_firstRow.bottomAnchor],
        [_secondWrap.leadingAnchor  constraintEqualToAnchor:self.leadingAnchor],
        [_secondWrap.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [_secondWrap.bottomAnchor   constraintEqualToAnchor:self.bottomAnchor],
        _secondHeight,

        [_secondTopLine.topAnchor      constraintEqualToAnchor:_secondWrap.topAnchor],
        [_secondTopLine.leadingAnchor  constraintEqualToAnchor:_secondWrap.leadingAnchor],
        [_secondTopLine.trailingAnchor constraintEqualToAnchor:_secondWrap.trailingAnchor],
        [_secondTopLine.heightAnchor   constraintEqualToConstant:1.0 / [UIScreen mainScreen].scale],
    ]];
}

#pragma mark 展开 / 收起

- (CGFloat)expandedHeight {
    return self.subItems.count * 48.0;   // 与 sub-item 高度一致
}

- (void)onFirstRowTapped {
    self.expanded = !self.expanded;
    self.secondHeight.constant = self.expanded ? [self expandedHeight] : 0;

    // 触发父视图重新布局（通知 superview 的 superview ...）
    UIView *topSuper = self;
    while (topSuper.superview) topSuper = topSuper.superview;

    [UIView animateWithDuration:0.35
                          delay:0
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
        self.arrowLabel.transform = self.expanded
            ? CGAffineTransformMakeRotation(M_PI)
            : CGAffineTransformIdentity;
        self.arrowLabel.textColor = self.expanded ? PCHex(0x1677ff) : PCHex(0x999999);
        [topSuper layoutIfNeeded];
    } completion:nil];
}

#pragma mark PCSubItemDelegate

- (void)subItemDidTapConfirm:(PCSubItemView *)item {
    if ([self.delegate respondsToSelector:@selector(menuCard:didTapConfirmWithTitle:)]) {
        [self.delegate menuCard:self didTapConfirmWithTitle:item.textLabel.text];
    }
}

@end

#pragma mark - 阴影包装器（配合卡片 masksToBounds 使用）

@interface PCCardShadow : UIView
@property (nonatomic, strong) PCMenuCard *card;
@end

@implementation PCCardShadow
- (instancetype)initWithCard:(PCMenuCard *)card {
    if ((self = [super init])) {
        _card = card;
        card.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:card];
        [NSLayoutConstraint activateConstraints:@[
            [card.topAnchor      constraintEqualToAnchor:self.topAnchor],
            [card.leadingAnchor  constraintEqualToAnchor:self.leadingAnchor],
            [card.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [card.bottomAnchor   constraintEqualToAnchor:self.bottomAnchor],
        ]];
        // box-shadow: 0 4px 18px rgba(0,0,0,0.06)
        self.layer.shadowColor   = [UIColor blackColor].CGColor;
        self.layer.shadowOpacity = 0.06;
        self.layer.shadowOffset  = CGSizeMake(0, 4);
        self.layer.shadowRadius  = 18;
        self.layer.masksToBounds = NO;
        self.backgroundColor = [UIColor clearColor];
    }
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    self.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.bounds
                                                       cornerRadius:20].CGPath;
}
@end

#pragma mark - 居中悬浮进度弹窗（真实下载）

@interface PCProgressOverlay : UIView <NSURLSessionDownloadDelegate>
@property (nonatomic, strong) UIView   *mask;
@property (nonatomic, strong) UIView   *popCard;
@property (nonatomic, strong) UILabel  *popTitle;
@property (nonatomic, strong) UIButton *popClose;
@property (nonatomic, strong) UIView   *progressTrack;
@property (nonatomic, strong) UIView   *progressFill;
@property (nonatomic, strong) CAGradientLayer *progressGradient;
@property (nonatomic, strong) NSLayoutConstraint *progressFillWidth;
@property (nonatomic, strong) UILabel  *progressTip;
@property (nonatomic, strong) UILabel  *progressNum;

@property (nonatomic, strong) NSURLSession             *session;
@property (nonatomic, strong) NSURLSessionDownloadTask *downloadTask;
@property (nonatomic, copy)   NSString                 *savedPath;
@property (nonatomic, copy)   NSString                 *currentName;
@property (nonatomic, assign) BOOL                      finished;
@end

@implementation PCProgressOverlay

- (instancetype)init {
    if ((self = [super init])) {
        self.translatesAutoresizingMaskIntoConstraints = NO;
        self.hidden = YES;

        _mask = [UIView new];
        _mask.translatesAutoresizingMaskIntoConstraints = NO;
        _mask.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5];
        [_mask addGestureRecognizer:
            [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(close)]];
        [self addSubview:_mask];

        _popCard = [UIView new];
        _popCard.translatesAutoresizingMaskIntoConstraints = NO;
        _popCard.backgroundColor = [UIColor whiteColor];
        _popCard.layer.cornerRadius = 20.0;
        _popCard.layer.shadowColor  = [UIColor blackColor].CGColor;
        _popCard.layer.shadowOpacity = 0.15;
        _popCard.layer.shadowOffset  = CGSizeMake(0, 8);
        _popCard.layer.shadowRadius  = 40;
        [self addSubview:_popCard];

        _popTitle = [UILabel new];
        _popTitle.translatesAutoresizingMaskIntoConstraints = NO;
        _popTitle.text = @"正在处理";
        _popTitle.font = [UIFont systemFontOfSize:17.0 weight:UIFontWeightSemibold];
        _popTitle.textColor = PCHex(0x222222);
        [_popCard addSubview:_popTitle];

        _popClose = [UIButton buttonWithType:UIButtonTypeCustom];
        _popClose.translatesAutoresizingMaskIntoConstraints = NO;
        _popClose.backgroundColor = PCHex(0xeeeeee);
        [_popClose setTitle:@"×" forState:UIControlStateNormal];
        [_popClose setTitleColor:PCHex(0x333333) forState:UIControlStateNormal];
        _popClose.titleLabel.font = [UIFont systemFontOfSize:16.0];
        _popClose.layer.cornerRadius = 13.0;
        _popClose.layer.masksToBounds = YES;
        [_popClose addTarget:self action:@selector(close)
            forControlEvents:UIControlEventTouchUpInside];
        [_popCard addSubview:_popClose];

        _progressTrack = [UIView new];
        _progressTrack.translatesAutoresizingMaskIntoConstraints = NO;
        _progressTrack.backgroundColor = PCHex(0xe9ecef);
        _progressTrack.layer.cornerRadius = 6.0;
        _progressTrack.layer.masksToBounds = YES;
        [_popCard addSubview:_progressTrack];

        _progressFill = [UIView new];
        _progressFill.translatesAutoresizingMaskIntoConstraints = NO;
        _progressFill.backgroundColor = [UIColor clearColor];
        _progressFill.clipsToBounds = YES;
        [_progressTrack addSubview:_progressFill];

        _progressGradient = [CAGradientLayer layer];
        _progressGradient.colors = @[(id)PCHex(0x00b96b).CGColor, (id)PCHex(0x23c97c).CGColor];
        _progressGradient.startPoint = CGPointMake(0, 0.5);
        _progressGradient.endPoint   = CGPointMake(1, 0.5);
        [_progressFill.layer addSublayer:_progressGradient];

        _progressTip = [UILabel new];
        _progressTip.translatesAutoresizingMaskIntoConstraints = NO;
        _progressTip.text = @"准备初始化...";
        _progressTip.font = [UIFont systemFontOfSize:13.0];
        _progressTip.textColor = PCHex(0x666666);
        _progressTip.numberOfLines = 1;
        _progressTip.lineBreakMode = NSLineBreakByTruncatingTail;
        [_popCard addSubview:_progressTip];

        _progressNum = [UILabel new];
        _progressNum.translatesAutoresizingMaskIntoConstraints = NO;
        _progressNum.text = @"0%";
        _progressNum.font = [UIFont systemFontOfSize:13.0];
        _progressNum.textColor = PCHex(0x666666);
        _progressNum.textAlignment = NSTextAlignmentRight;
        [_popCard addSubview:_progressNum];

        _progressFillWidth = [_progressFill.widthAnchor constraintEqualToConstant:0];

        [NSLayoutConstraint activateConstraints:@[
            [_mask.topAnchor      constraintEqualToAnchor:self.topAnchor],
            [_mask.leadingAnchor  constraintEqualToAnchor:self.leadingAnchor],
            [_mask.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [_mask.bottomAnchor   constraintEqualToAnchor:self.bottomAnchor],

            [_popCard.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [_popCard.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [_popCard.widthAnchor   constraintEqualToConstant:320],

            [_popTitle.leadingAnchor  constraintEqualToAnchor:_popCard.leadingAnchor constant:24],
            [_popTitle.topAnchor      constraintEqualToAnchor:_popCard.topAnchor     constant:24],
            [_popTitle.trailingAnchor constraintLessThanOrEqualToAnchor:_popClose.leadingAnchor constant:-8],

            [_popClose.trailingAnchor constraintEqualToAnchor:_popCard.trailingAnchor constant:-24],
            [_popClose.centerYAnchor  constraintEqualToAnchor:_popTitle.centerYAnchor],
            [_popClose.widthAnchor    constraintEqualToConstant:26],
            [_popClose.heightAnchor   constraintEqualToConstant:26],

            [_progressTrack.leadingAnchor  constraintEqualToAnchor:_popCard.leadingAnchor constant:24],
            [_progressTrack.trailingAnchor constraintEqualToAnchor:_popCard.trailingAnchor constant:-24],
            // pop-top margin-bottom:18 + progress-wrap margin-top:12 = 30
            [_progressTrack.topAnchor      constraintEqualToAnchor:_popTitle.bottomAnchor constant:30],
            [_progressTrack.heightAnchor   constraintEqualToConstant:12],

            [_progressFill.leadingAnchor constraintEqualToAnchor:_progressTrack.leadingAnchor],
            [_progressFill.topAnchor     constraintEqualToAnchor:_progressTrack.topAnchor],
            [_progressFill.bottomAnchor  constraintEqualToAnchor:_progressTrack.bottomAnchor],
            _progressFillWidth,

            [_progressTip.leadingAnchor    constraintEqualToAnchor:_popCard.leadingAnchor constant:24],
            [_progressTip.topAnchor        constraintEqualToAnchor:_progressTrack.bottomAnchor constant:12],
            [_progressTip.bottomAnchor     constraintEqualToAnchor:_popCard.bottomAnchor constant:-24],
            [_progressTip.trailingAnchor   constraintLessThanOrEqualToAnchor:_progressNum.leadingAnchor constant:-8],

            [_progressNum.trailingAnchor constraintEqualToAnchor:_popCard.trailingAnchor constant:-24],
            [_progressNum.centerYAnchor  constraintEqualToAnchor:_progressTip.centerYAnchor],
        ]];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.progressGradient.frame = self.progressFill.bounds;
}

#pragma mark 启动真实下载

- (void)startDownloadWithName:(NSString *)name url:(NSURL *)url {
    // 先取消上一次可能还在跑的任务
    [self cancelDownload];

    self.currentName = name ?: @"下载";
    self.finished = NO;
    self.savedPath = nil;

    self.popTitle.text = [NSString stringWithFormat:@"正在执行：%@", self.currentName];
    self.progressTip.text = @"正在连接...";
    self.progressNum.text = @"0%";
    self.progressFillWidth.constant = 0;
    [self.progressFill.superview layoutIfNeeded];
    self.hidden = NO;

    // 入场动画（对应 CSS popFade）
    self.popCard.alpha = 0;
    self.popCard.transform = CGAffineTransformMakeTranslation(0, -20);
    self.mask.alpha = 0;
    [UIView animateWithDuration:0.3 animations:^{
        self.mask.alpha = 1.0;
        self.popCard.alpha = 1.0;
        self.popCard.transform = CGAffineTransformIdentity;
    }];

    if (!url) {
        self.progressTip.text = @"无效的下载地址";
        return;
    }

    NSURLSessionConfiguration *cfg = [NSURLSessionConfiguration defaultSessionConfiguration];
    cfg.timeoutIntervalForRequest  = 30;
    cfg.timeoutIntervalForResource = 60 * 30;
    cfg.HTTPAdditionalHeaders = @{
        @"User-Agent": @"PersonalCenter/1.0 (iOS)"
    };

    // delegateQueue 使用主队列，回调里直接改 UI
    self.session = [NSURLSession sessionWithConfiguration:cfg
                                                  delegate:self
                                             delegateQueue:[NSOperationQueue mainQueue]];
    NSURLRequest *req = [NSURLRequest requestWithURL:url
                                         cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                     timeoutInterval:30];
    self.downloadTask = [self.session downloadTaskWithRequest:req];
    [self.downloadTask resume];
}

- (void)cancelDownload {
    if (self.downloadTask) {
        [self.downloadTask cancel];
        self.downloadTask = nil;
    }
    if (self.session) {
        [self.session invalidateAndCancel];
        self.session = nil;
    }
}

- (void)close {
    [self cancelDownload];
    [UIView animateWithDuration:0.2 animations:^{
        self.mask.alpha = 0;
        self.popCard.alpha = 0;
    } completion:^(BOOL f) {
        self.hidden = YES;
        self.progressFillWidth.constant = 0;
        self.progressNum.text = @"0%";
        self.progressTip.text = @"准备初始化...";
    }];
}

#pragma mark 工具：字节格式化

static NSString *PCBytesString(int64_t bytes) {
    if (bytes < 0) return @"-";
    double b = (double)bytes;
    if (b < 1024)             return [NSString stringWithFormat:@"%lld B", bytes];
    if (b < 1024 * 1024)      return [NSString stringWithFormat:@"%.1f KB", b / 1024.0];
    if (b < 1024.0 * 1024 * 1024) return [NSString stringWithFormat:@"%.2f MB", b / 1024.0 / 1024.0];
    return [NSString stringWithFormat:@"%.2f GB", b / 1024.0 / 1024.0 / 1024.0];
}

#pragma mark - NSURLSessionDownloadDelegate

- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
      didWriteData:(int64_t)bytesWritten
 totalBytesWritten:(int64_t)totalBytesWritten
totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {

    CGFloat percent = 0;
    if (totalBytesExpectedToWrite > 0) {
        percent = (CGFloat)totalBytesWritten / (CGFloat)totalBytesExpectedToWrite;
    }
    percent = MIN(MAX(percent, 0.0), 1.0);

    self.progressNum.text = [NSString stringWithFormat:@"%d%%", (int)floor(percent * 100)];
    if (totalBytesExpectedToWrite > 0) {
        self.progressTip.text = [NSString stringWithFormat:@"下载中 %@ / %@",
                                 PCBytesString(totalBytesWritten),
                                 PCBytesString(totalBytesExpectedToWrite)];
    } else {
        self.progressTip.text = [NSString stringWithFormat:@"下载中 %@",
                                 PCBytesString(totalBytesWritten)];
    }

    CGFloat trackWidth = CGRectGetWidth(self.progressTrack.bounds);
    self.progressFillWidth.constant = trackWidth * percent;
    [UIView animateWithDuration:0.12 animations:^{
        [self.progressFill.superview layoutIfNeeded];
        self.progressGradient.frame = self.progressFill.bounds;
    }];
}

- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
didFinishDownloadingToURL:(NSURL *)location {

    // 把临时文件拷到 Documents，文件名取 URL 最后一段
    NSString *fileName = [[downloadTask.originalRequest.URL lastPathComponent]
                          stringByRemovingPercentEncoding];
    if (fileName.length == 0) fileName = @"download.bin";

    NSString *docs = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                          NSUserDomainMask, YES) firstObject];
    NSString *dst = [docs stringByAppendingPathComponent:fileName];

    NSFileManager *fm = [NSFileManager defaultManager];
    [fm removeItemAtPath:dst error:nil];
    NSError *mvErr = nil;
    [fm moveItemAtURL:location toURL:[NSURL fileURLWithPath:dst] error:&mvErr];

    self.savedPath = dst;
    self.finished = (mvErr == nil);

    // 最终 UI 在 didCompleteWithError 里统一处理
}

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
didCompleteWithError:(NSError *)error {

    if (error) {
        if (error.code == NSURLErrorCancelled) {
            // 用户主动取消，不提示
            return;
        }
        self.progressTip.text = [NSString stringWithFormat:@"下载失败：%@", error.localizedDescription];
        return;
    }

    // 成功
    self.progressFillWidth.constant = CGRectGetWidth(self.progressTrack.bounds);
    [UIView animateWithDuration:0.15 animations:^{
        [self.progressFill.superview layoutIfNeeded];
        self.progressGradient.frame = self.progressFill.bounds;
    }];
    self.progressNum.text = @"100%";
    if (self.finished && self.savedPath.length) {
        self.progressTip.text = [NSString stringWithFormat:@"完成 · 已保存到 %@",
                                 self.savedPath.lastPathComponent];
    } else {
        self.progressTip.text = @"下载完成！";
    }
}

@end

#pragma mark - VC

@interface PersonalCenterViewController () <PCMenuCardDelegate>
@property (nonatomic, strong) PCGradientHeader  *header;
@property (nonatomic, strong) UILabel           *headerTitle;
@property (nonatomic, strong) UIScrollView      *scrollView;
@property (nonatomic, strong) UIView            *contentView;
@property (nonatomic, strong) NSArray<PCCardShadow *> *cardShadows;
@property (nonatomic, strong) PCProgressOverlay *overlay;
@end

@implementation PersonalCenterViewController

- (UIStatusBarStyle)preferredStatusBarStyle { return UIStatusBarStyleLightContent; }

- (void)viewDidLoad {
    [super viewDidLoad];
    if (@available(iOS 13.0, *)) {
        self.overrideUserInterfaceStyle = UIUserInterfaceStyleLight;
    }
    self.view.backgroundColor = PCHex(0xf6f8fa);

    [self buildHeader];
    [self buildScrollView];
    [self buildCards];
    [self buildOverlay];
}

#pragma mark 构建头部

- (void)buildHeader {
    _header = [PCGradientHeader new];
    _header.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_header];

    _headerTitle = [UILabel new];
    _headerTitle.translatesAutoresizingMaskIntoConstraints = NO;
    _headerTitle.text = @"个人中心 · 功能菜单";
    _headerTitle.font = [UIFont systemFontOfSize:18.0 weight:UIFontWeightSemibold];
    _headerTitle.textColor = [UIColor whiteColor];
    _headerTitle.textAlignment = NSTextAlignmentCenter;
    // HTML letter-spacing:1px
    NSMutableAttributedString *attr = [[NSMutableAttributedString alloc]
        initWithString:_headerTitle.text attributes:@{NSKernAttributeName:@(1.0)}];
    _headerTitle.attributedText = attr;
    [_header addSubview:_headerTitle];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [_header.topAnchor      constraintEqualToAnchor:self.view.topAnchor],
        [_header.leadingAnchor  constraintEqualToAnchor:self.view.leadingAnchor],
        [_header.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_header.bottomAnchor   constraintEqualToAnchor:safe.topAnchor constant:56],

        [_headerTitle.centerXAnchor constraintEqualToAnchor:_header.centerXAnchor],
        [_headerTitle.bottomAnchor  constraintEqualToAnchor:_header.bottomAnchor constant:-17],
    ]];
}

#pragma mark 构建滚动区

- (void)buildScrollView {
    _scrollView = [UIScrollView new];
    _scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    _scrollView.alwaysBounceVertical = YES;
    _scrollView.showsVerticalScrollIndicator = NO;
    _scrollView.backgroundColor = PCHex(0xf6f8fa);
    _scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    [self.view addSubview:_scrollView];

    _contentView = [UIView new];
    _contentView.translatesAutoresizingMaskIntoConstraints = NO;
    [_scrollView addSubview:_contentView];

    [NSLayoutConstraint activateConstraints:@[
        [_scrollView.topAnchor      constraintEqualToAnchor:_header.bottomAnchor],
        [_scrollView.leadingAnchor  constraintEqualToAnchor:self.view.leadingAnchor],
        [_scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_scrollView.bottomAnchor   constraintEqualToAnchor:self.view.bottomAnchor],

        // contentView 宽度 == scrollView 宽度（纵向滚动）
        [_contentView.topAnchor      constraintEqualToAnchor:_scrollView.topAnchor],
        [_contentView.leadingAnchor  constraintEqualToAnchor:_scrollView.leadingAnchor],
        [_contentView.trailingAnchor constraintEqualToAnchor:_scrollView.trailingAnchor],
        [_contentView.bottomAnchor   constraintEqualToAnchor:_scrollView.bottomAnchor],
        [_contentView.widthAnchor    constraintEqualToAnchor:_scrollView.widthAnchor],
    ]];
}

#pragma mark 构建四张卡片

- (void)buildCards {
    NSArray *defs = @[
        @{ @"emoji":@"📋", @"color":PCHex(0x1677ff), @"title":@"订单管理",
           @"subs": @[@"全部订单", @"待付款订单", @"已发货物流", @"售后退款记录"] },
        @{ @"emoji":@"👤", @"color":PCHex(0x00b96b), @"title":@"个人资料",
           @"subs": @[@"修改头像昵称", @"绑定手机号", @"实名认证", @"收货地址管理"] },
        @{ @"emoji":@"⚙️", @"color":PCHex(0xff7d00), @"title":@"系统设置",
           @"subs": @[@"消息通知开关", @"隐私权限管理", @"清除缓存数据", @"关于当前版本"] },
        @{ @"emoji":@"💡", @"color":PCHex(0x2a3342), @"title":@"帮助与客服",
           @"subs": @[@"常见问题解答", @"在线人工客服", @"意见反馈提交"] },
    ];

    NSMutableArray *shadows = [NSMutableArray array];
    UIView *prev = nil;
    for (NSDictionary *d in defs) {
        PCMenuCard *card = [[PCMenuCard alloc] initWithIconEmoji:d[@"emoji"]
                                                        iconColor:d[@"color"]
                                                            title:d[@"title"]
                                                         subItems:d[@"subs"]];
        card.delegate = self;

        PCCardShadow *wrap = [[PCCardShadow alloc] initWithCard:card];
        wrap.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:wrap];

        // HTML: .main-wrap margin-top 68（由 header 已承担），padding 14 + card margin-bottom 16
        NSLayoutYAxisAnchor *topAnchor = prev ? prev.bottomAnchor : self.contentView.topAnchor;
        CGFloat topOffset = prev ? 16.0 : 14.0;

        [NSLayoutConstraint activateConstraints:@[
            [wrap.topAnchor      constraintEqualToAnchor:topAnchor constant:topOffset],
            [wrap.leadingAnchor  constraintEqualToAnchor:self.contentView.leadingAnchor constant:14],
            [wrap.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-14],
        ]];

        [shadows addObject:wrap];
        prev = wrap;
    }

    // 底部安全间距 .safe-bottom 40 + padding-bottom 30
    if (prev) {
        [NSLayoutConstraint activateConstraints:@[
            [prev.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-(30 + 40)],
        ]];
    }
    self.cardShadows = [shadows copy];
}

#pragma mark 构建进度弹窗

- (void)buildOverlay {
    _overlay = [PCProgressOverlay new];
    [self.view addSubview:_overlay];
    [NSLayoutConstraint activateConstraints:@[
        [_overlay.topAnchor      constraintEqualToAnchor:self.view.topAnchor],
        [_overlay.leadingAnchor  constraintEqualToAnchor:self.view.leadingAnchor],
        [_overlay.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_overlay.bottomAnchor   constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
}

#pragma mark PCMenuCardDelegate

- (void)menuCard:(PCMenuCard *)card didTapConfirmWithTitle:(NSString *)title {
    NSURL *url = [NSURL URLWithString:kPCDownloadURLString];
    [self.overlay startDownloadWithName:title url:url];
}

@end
