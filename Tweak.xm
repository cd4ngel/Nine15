#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <math.h>

#pragma mark - Private declarations

@interface CSCoverSheetViewController : UIViewController
@property(nonatomic, getter=isAuthenticated) BOOL authenticated;
@end

@interface CSMainPageView : UIView
@end

@interface CSCoverSheetView : UIView
@end

@interface CSFixedFooterViewController : UIViewController
@end

@interface CSTeachableMomentsContainerViewController : UIViewController
@end

@interface SBFLockScreenDateView : UIView
@end

@interface NCNotificationShortLookView : UIView
@property(nonatomic, strong) UIView *backgroundView;
@end

@interface NCNotificationShortLookViewController : UIViewController
@property(nonatomic, weak) id delegate;
@end

@interface NCNotificationContentView : UIView
@property(setter=_setPrimaryLabel:, getter=_primaryLabel, nonatomic, strong) UILabel *primaryLabel;
@property(getter=_secondaryLabel, nonatomic, readonly) UILabel *secondaryLabel;
@property(setter=_setPrimarySubtitleLabel:, getter=_primarySubtitleLabel, nonatomic, strong) UILabel *primarySubtitleLabel;
@end

@interface NCNotificationListView : UIView
@end

@interface NCNotificationListViewController : UIViewController
@end

@interface NCNotificationStructuredListViewController : UIViewController
@end

@interface NCNotificationCombinedListViewController : UIViewController
@end

@interface NCNotificationListCellActionButton : UIControl
@property(nonatomic, strong) UIView *backgroundView;
@end

@interface NCNotificationMasterList : NSObject
@end

@interface NCNotificationGroupList : NSObject
@end

@interface NCToggleControlPair : UIView
@end

@interface NCToggleControl : UIView
@end

@interface NCNotificationListCoalescingHeaderCell : UIView
@end

@interface NCNotificationListCoalescingControlsCell : UIView
@end

@interface NCNotificationListCollectionViewFlowLayout : UICollectionViewFlowLayout
@end

@interface PLPlatterHeaderContentView : UIView
@end

@interface UIView (Nine15Private)
- (UIViewController *)_viewControllerForAncestor;
@end

@interface MRUNowPlayingViewController : UIViewController
@property(nonatomic, readonly) NSInteger context;
@end

#pragma mark - Globals

static BOOL N15Enabled = YES;
static BOOL N15Locked = YES;

static NSString * const N15MediaRemotePath =
    @"/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote";

@class N15LockOverlayView;
static __weak N15LockOverlayView *N15CurrentOverlay = nil;

static const void *N15OverlayAssociationKey = &N15OverlayAssociationKey;
static const void *N15SeparatorAssociationKey = &N15SeparatorAssociationKey;
static const void *N15CoverBlurAssociationKey = &N15CoverBlurAssociationKey;

static __weak CSCoverSheetViewController *N15CurrentCoverController = nil;
static NSUInteger N15NotificationCount = 0;

static N15LockOverlayView *N15GetOverlay(CSMainPageView *view) {
    if (!view) {
        return nil;
    }

    return objc_getAssociatedObject(view, N15OverlayAssociationKey);
}

static void N15SetOverlay(CSMainPageView *view, N15LockOverlayView *overlay) {
    if (!view) {
        return;
    }

    objc_setAssociatedObject(
        view,
        N15OverlayAssociationKey,
        overlay,
        OBJC_ASSOCIATION_RETAIN_NONATOMIC
    );
}

static UIView *N15GetSeparatorView(NCNotificationShortLookView *view) {
    if (!view) {
        return nil;
    }

    return objc_getAssociatedObject(view, N15SeparatorAssociationKey);
}

static void N15SetSeparatorView(
    NCNotificationShortLookView *view,
    UIView *separatorView
) {
    if (!view) {
        return;
    }

    objc_setAssociatedObject(
        view,
        N15SeparatorAssociationKey,
        separatorView,
        OBJC_ASSOCIATION_RETAIN_NONATOMIC
    );
}

static UIVisualEffectView *N15GetCoverBlur(CSCoverSheetViewController *controller) {
    if (!controller) {
        return nil;
    }

    return objc_getAssociatedObject(controller, N15CoverBlurAssociationKey);
}

static void N15SetCoverBlur(
    CSCoverSheetViewController *controller,
    UIVisualEffectView *blurView
) {
    if (!controller) {
        return;
    }

    objc_setAssociatedObject(
        controller,
        N15CoverBlurAssociationKey,
        blurView,
        OBJC_ASSOCIATION_RETAIN_NONATOMIC
    );
}

#pragma mark - ObjC helpers

static id N15SendId(id object, SEL selector) {
    if (!object || !selector || ![object respondsToSelector:selector]) {
        return nil;
    }

    return ((id (*)(id, SEL))objc_msgSend)(object, selector);
}

static void N15SendVoid(id object, SEL selector) {
    if (!object || !selector || ![object respondsToSelector:selector]) {
        return;
    }

    ((void (*)(id, SEL))objc_msgSend)(object, selector);
}

static void N15RequestUnlock(void) {
    Class managerClass = NSClassFromString(@"SBLockScreenManager");
    if (!managerClass) {
        return;
    }

    id manager = N15SendId(managerClass, NSSelectorFromString(@"sharedInstance"));
    if (!manager) {
        return;
    }

    SEL selector = NSSelectorFromString(@"lockScreenViewControllerRequestsUnlock");
    N15SendVoid(manager, selector);
}


static id N15ObjectIvar(id object, const char *name) {
    if (!object || !name) {
        return nil;
    }

    Ivar ivar = class_getInstanceVariable([object class], name);
    if (!ivar) {
        Class currentClass = class_getSuperclass([object class]);

        while (currentClass && !ivar) {
            ivar = class_getInstanceVariable(currentClass, name);
            currentClass = class_getSuperclass(currentClass);
        }
    }

    return ivar ? object_getIvar(object, ivar) : nil;
}


static void N15ClearNotificationMaterials(UIView *root) {
    if (!root) {
        return;
    }

    root.backgroundColor = UIColor.clearColor;
    root.layer.cornerRadius = 0.0;

    for (UIView *subview in root.subviews) {
        NSString *className = NSStringFromClass([subview class]);

        BOOL isMaterial =
            [className rangeOfString:@"Material" options:NSCaseInsensitiveSearch].location != NSNotFound ||
            [className rangeOfString:@"Platter" options:NSCaseInsensitiveSearch].location != NSNotFound ||
            [className rangeOfString:@"VisualStyling" options:NSCaseInsensitiveSearch].location != NSNotFound;

        if (isMaterial) {
            subview.backgroundColor = UIColor.clearColor;
            subview.layer.cornerRadius = 0.0;
            subview.layer.masksToBounds = NO;
            subview.alpha = 0.0;
        } else {
            subview.layer.cornerRadius = 0.0;
        }

        N15ClearNotificationMaterials(subview);
    }
}

static void N15StyleNotificationText(UIView *root) {
    if (!root) {
        return;
    }

    for (UIView *subview in root.subviews) {
        if ([subview isKindOfClass:UILabel.class]) {
            UILabel *label = (UILabel *)subview;
            label.layer.filters = nil;
            label.textColor = [UIColor colorWithWhite:1.0 alpha:0.96];
        } else if ([subview isKindOfClass:UITextView.class]) {
            UITextView *textView = (UITextView *)subview;
            textView.layer.filters = nil;
            textView.textColor = [UIColor colorWithWhite:1.0 alpha:0.96];
            textView.backgroundColor = UIColor.clearColor;
        }

        N15StyleNotificationText(subview);
    }
}

static BOOL N15IsBannerShortLook(NCNotificationShortLookView *view) {
    if (!view) {
        return NO;
    }

    UIViewController *controller = nil;

    @try {
        controller = [view _viewControllerForAncestor];
    } @catch (__unused NSException *exception) {
        controller = nil;
    }

    id delegate = nil;

    @try {
        if ([controller respondsToSelector:NSSelectorFromString(@"delegate")]) {
            delegate = [controller valueForKey:@"delegate"];
        }
    } @catch (__unused NSException *exception) {
        delegate = nil;
    }

    Class bannerClass = NSClassFromString(@"SBNotificationBannerDestination");
    return bannerClass && [delegate isKindOfClass:bannerClass];
}

static void N15EnsureCoverBlur(CSCoverSheetViewController *controller) {
    if (!controller || !N15Enabled) {
        return;
    }

    UIVisualEffectView *blurView = N15GetCoverBlur(controller);

    if (!blurView) {
        UIBlurEffect *effect =
            [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];

        blurView = [[UIVisualEffectView alloc] initWithEffect:effect];
        blurView.userInteractionEnabled = NO;
        blurView.alpha = 0.0;
        blurView.autoresizingMask =
            UIViewAutoresizingFlexibleWidth |
            UIViewAutoresizingFlexibleHeight;

        N15SetCoverBlur(controller, blurView);
        [controller.view insertSubview:blurView atIndex:0];
    }

    blurView.frame = controller.view.bounds;
}

static void N15UpdateNotificationBackdrop(void) {
    CSCoverSheetViewController *controller = N15CurrentCoverController;
    if (!controller) {
        return;
    }

    N15EnsureCoverBlur(controller);

    UIVisualEffectView *blurView = N15GetCoverBlur(controller);
    if (!blurView) {
        return;
    }

    // Lock Screen: blur only when notifications are present.
    // Notification Center (authenticated CoverSheet): keep the classic blurred backdrop.
    BOOL shouldShow = N15Enabled && (!N15Locked || N15NotificationCount > 0);
    CGFloat targetAlpha = shouldShow ? 1.0 : 0.0;

    if (fabs(blurView.alpha - targetAlpha) < 0.01) {
        return;
    }

    [UIView animateWithDuration:0.20
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseInOut |
                                UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        blurView.alpha = targetAlpha;
    } completion:nil];
}

static void N15SetNotificationCount(NSUInteger count) {
    N15NotificationCount = count;

    dispatch_async(dispatch_get_main_queue(), ^{
    N15SendVoid((id)N15CurrentOverlay, NSSelectorFromString(@"updateLockedState"));        N15UpdateNotificationBackdrop();
    });
}

#pragma mark - MediaRemote bridge

typedef void (*N15MRGetNowPlayingInfoFunction)(
    dispatch_queue_t queue,
    void (^completion)(CFDictionaryRef information)
);

typedef Boolean (*N15MRSendCommandFunction)(NSInteger command, id userInfo);

static void *N15MediaRemoteHandle(void) {
    static void *handle = NULL;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        handle = dlopen(N15MediaRemotePath.UTF8String, RTLD_LAZY);
    });

    return handle;
}

static N15MRGetNowPlayingInfoFunction N15GetNowPlayingInfoFunction(void) {
    void *handle = N15MediaRemoteHandle();
    if (!handle) {
        return NULL;
    }

    return (N15MRGetNowPlayingInfoFunction)dlsym(
        handle,
        "MRMediaRemoteGetNowPlayingInfo"
    );
}

static N15MRSendCommandFunction N15SendCommandFunction(void) {
    void *handle = N15MediaRemoteHandle();
    if (!handle) {
        return NULL;
    }

    return (N15MRSendCommandFunction)dlsym(
        handle,
        "MRMediaRemoteSendCommand"
    );
}

static CFStringRef N15MediaRemoteKey(const char *symbolName) {
    void *handle = N15MediaRemoteHandle();
    if (!handle) {
        return NULL;
    }

    CFStringRef *keyPointer = (CFStringRef *)dlsym(handle, symbolName);
    return keyPointer ? *keyPointer : NULL;
}

static id N15InfoValue(NSDictionary *info, const char *symbolName) {
    if (!info) {
        return nil;
    }

    CFStringRef key = N15MediaRemoteKey(symbolName);
    if (!key) {
        return nil;
    }

    return info[(__bridge NSString *)key];
}

typedef NS_ENUM(NSInteger, N15MediaRemoteCommand) {
    N15MediaRemoteCommandPlay = 0,
    N15MediaRemoteCommandPause = 1,
    N15MediaRemoteCommandTogglePlayPause = 2,
    N15MediaRemoteCommandStop = 3,
    N15MediaRemoteCommandNextTrack = 4,
    N15MediaRemoteCommandPreviousTrack = 5
};

static void N15SendMediaCommand(N15MediaRemoteCommand command) {
    N15MRSendCommandFunction function = N15SendCommandFunction();
    if (!function) {
        return;
    }

    function(command, nil);
}

#pragma mark - Reusable UI

@interface N15GlintLabel : UILabel
@property(nonatomic, strong) CAGradientLayer *glintLayer;
@end

@implementation N15GlintLabel

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) {
        return nil;
    }

    self.textAlignment = NSTextAlignmentCenter;
    self.font = [UIFont systemFontOfSize:21.0 weight:UIFontWeightLight];
    self.textColor = UIColor.whiteColor;

    _glintLayer = [CAGradientLayer layer];
    _glintLayer.colors = @[
        (__bridge id)[UIColor colorWithWhite:1 alpha:0.36].CGColor,
        (__bridge id)UIColor.whiteColor.CGColor,
        (__bridge id)[UIColor colorWithWhite:1 alpha:0.36].CGColor
    ];
    _glintLayer.locations = @[@0.0, @0.5, @1.0];
    _glintLayer.startPoint = CGPointMake(0, 0.5);
    _glintLayer.endPoint = CGPointMake(1, 0.5);
    self.layer.mask = _glintLayer;

    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.glintLayer.frame = self.bounds;

    if (![self.glintLayer animationForKey:@"nine15.glint"]) {
        CABasicAnimation *animation =
            [CABasicAnimation animationWithKeyPath:@"locations"];

        animation.fromValue = @[@-1.0, @-0.5, @0.0];
        animation.toValue = @[@1.0, @1.5, @2.0];
        animation.duration = 2.2;
        animation.repeatCount = HUGE_VALF;
        [self.glintLayer addAnimation:animation forKey:@"nine15.glint"];
    }
}

@end

#pragma mark - Classic media view

@interface N15MediaView : UIView
@property(nonatomic, strong) UIVisualEffectView *blurView;
@property(nonatomic, strong) UILabel *titleLabel;
@property(nonatomic, strong) UILabel *artistLabel;
@property(nonatomic, strong) UIImageView *artworkView;
@property(nonatomic, strong) UIButton *previousButton;
@property(nonatomic, strong) UIButton *playPauseButton;
@property(nonatomic, strong) UIButton *nextButton;
@property(nonatomic, strong) NSTimer *refreshTimer;
@property(nonatomic, assign) BOOL hasContent;
@end

@implementation N15MediaView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) {
        return nil;
    }

    self.clipsToBounds = YES;
    self.hidden = YES;

    UIBlurEffect *effect =
        [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterialDark];

    _blurView = [[UIVisualEffectView alloc] initWithEffect:effect];
    [self addSubview:_blurView];

    _titleLabel = [[UILabel alloc] init];
    _titleLabel.textColor = UIColor.whiteColor;
    _titleLabel.textAlignment = NSTextAlignmentCenter;
    _titleLabel.font = [UIFont systemFontOfSize:21 weight:UIFontWeightSemibold];
    _titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [self addSubview:_titleLabel];

    _artistLabel = [[UILabel alloc] init];
    _artistLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.70];
    _artistLabel.textAlignment = NSTextAlignmentCenter;
    _artistLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightRegular];
    _artistLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [self addSubview:_artistLabel];

    _artworkView = [[UIImageView alloc] init];
    _artworkView.contentMode = UIViewContentModeScaleAspectFill;
    _artworkView.clipsToBounds = YES;
    _artworkView.layer.cornerRadius = 3.0;
    [self addSubview:_artworkView];

    UIImageSymbolConfiguration *configuration =
        [UIImageSymbolConfiguration configurationWithPointSize:28
                                                        weight:UIImageSymbolWeightRegular];

    _previousButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [_previousButton setImage:[UIImage systemImageNamed:@"backward.fill"
                                      withConfiguration:configuration]
                     forState:UIControlStateNormal];
    _previousButton.tintColor = UIColor.whiteColor;
    [_previousButton addTarget:self
                        action:@selector(previousTapped)
              forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:_previousButton];

    _playPauseButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [_playPauseButton setImage:[UIImage systemImageNamed:@"playpause.fill"
                                       withConfiguration:configuration]
                      forState:UIControlStateNormal];
    _playPauseButton.tintColor = UIColor.whiteColor;
    [_playPauseButton addTarget:self
                         action:@selector(playPauseTapped)
               forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:_playPauseButton];

    _nextButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [_nextButton setImage:[UIImage systemImageNamed:@"forward.fill"
                                  withConfiguration:configuration]
                 forState:UIControlStateNormal];
    _nextButton.tintColor = UIColor.whiteColor;
    [_nextButton addTarget:self
                    action:@selector(nextTapped)
          forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:_nextButton];

    _refreshTimer =
        [NSTimer scheduledTimerWithTimeInterval:1.5
                                         target:self
                                       selector:@selector(refreshNowPlaying)
                                       userInfo:nil
                                        repeats:YES];

    [self refreshNowPlaying];

    return self;
}

- (void)dealloc {
    [self.refreshTimer invalidate];
}

- (void)layoutSubviews {
    [super layoutSubviews];

    self.blurView.frame = self.bounds;

    CGFloat width = CGRectGetWidth(self.bounds);
    CGFloat safeTop = self.safeAreaInsets.top;
    CGFloat artworkSize = MIN(width - 54.0, 320.0);

    self.titleLabel.frame = CGRectMake(28, safeTop + 32, width - 56, 28);
    self.artistLabel.frame = CGRectMake(28, safeTop + 62, width - 56, 24);

    self.artworkView.frame = CGRectMake(
        (width - artworkSize) / 2.0,
        safeTop + 110,
        artworkSize,
        artworkSize
    );

    CGFloat controlsY = CGRectGetMaxY(self.artworkView.frame) + 24.0;
    CGFloat buttonWidth = 72.0;

    self.previousButton.frame =
        CGRectMake(width / 2.0 - 120.0, controlsY, buttonWidth, 56.0);

    self.playPauseButton.frame =
        CGRectMake(width / 2.0 - buttonWidth / 2.0, controlsY, buttonWidth, 56.0);

    self.nextButton.frame =
        CGRectMake(width / 2.0 + 48.0, controlsY, buttonWidth, 56.0);
}

- (void)previousTapped {
    N15SendMediaCommand(N15MediaRemoteCommandPreviousTrack);
}

- (void)playPauseTapped {
    N15SendMediaCommand(N15MediaRemoteCommandTogglePlayPause);
}

- (void)nextTapped {
    N15SendMediaCommand(N15MediaRemoteCommandNextTrack);
}

- (void)refreshNowPlaying {
    N15MRGetNowPlayingInfoFunction function = N15GetNowPlayingInfoFunction();
    if (!function) {
        self.hidden = YES;
        self.hasContent = NO;
        return;
    }

    __weak typeof(self) weakSelf = self;

    function(dispatch_get_main_queue(), ^(CFDictionaryRef information) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }

        NSDictionary *info = (__bridge NSDictionary *)information;

        NSString *title =
            N15InfoValue(info, "kMRMediaRemoteNowPlayingInfoTitle");

        NSString *artist =
            N15InfoValue(info, "kMRMediaRemoteNowPlayingInfoArtist");

        NSData *artworkData =
            N15InfoValue(info, "kMRMediaRemoteNowPlayingInfoArtworkData");

        BOOL hasContent =
            title.length > 0 || artist.length > 0 || artworkData.length > 0;

        strongSelf.hasContent = hasContent;
        strongSelf.hidden = !hasContent || !N15Locked;

        strongSelf.titleLabel.text = title.length ? title : @"Now Playing";
        strongSelf.artistLabel.text = artist ?: @"";

        if (artworkData.length > 0) {
            strongSelf.artworkView.image = [UIImage imageWithData:artworkData];
        } else {
            strongSelf.artworkView.image =
                [UIImage systemImageNamed:@"music.note"];
            strongSelf.artworkView.tintColor =
                [UIColor colorWithWhite:1.0 alpha:0.65];
            strongSelf.artworkView.contentMode = UIViewContentModeScaleAspectFit;
        }

        [strongSelf.superview setNeedsLayout];
    });
}

@end

#pragma mark - Lock screen overlay

@interface N15LockOverlayView : UIView <UIGestureRecognizerDelegate>
@property(nonatomic, strong) UILabel *timeLabel;
@property(nonatomic, strong) UILabel *dateLabel;
@property(nonatomic, strong) UIView *separatorView;
@property(nonatomic, strong) UIView *sliderHitView;
@property(nonatomic, strong) UILabel *chevronLabel;
@property(nonatomic, strong) N15GlintLabel *slideLabel;
@property(nonatomic, strong) UIPanGestureRecognizer *slideGesture;
@property(nonatomic, strong) N15MediaView *mediaView;
@property(nonatomic, strong) NSTimer *clockTimer;
@property(nonatomic, assign) CGFloat slideProgress;
- (void)updateLockedState;
@end

@implementation N15LockOverlayView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) {
        return nil;
    }

    self.backgroundColor = UIColor.clearColor;
    self.userInteractionEnabled = YES;

    _timeLabel = [[UILabel alloc] init];
    _timeLabel.textAlignment = NSTextAlignmentCenter;
    _timeLabel.textColor = UIColor.whiteColor;
    _timeLabel.font = [UIFont systemFontOfSize:64 weight:UIFontWeightThin];
    _timeLabel.adjustsFontSizeToFitWidth = YES;
    [self addSubview:_timeLabel];

    _dateLabel = [[UILabel alloc] init];
    _dateLabel.textAlignment = NSTextAlignmentCenter;
    _dateLabel.textColor = UIColor.whiteColor;
    _dateLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightRegular];
    [self addSubview:_dateLabel];

    _separatorView = [[UIView alloc] init];
    _separatorView.backgroundColor =
        [UIColor colorWithWhite:1.0 alpha:0.28];
    [self addSubview:_separatorView];

    _sliderHitView = [[UIView alloc] init];
    _sliderHitView.backgroundColor = UIColor.clearColor;
    _sliderHitView.userInteractionEnabled = YES;
    [self addSubview:_sliderHitView];

    _chevronLabel = [[UILabel alloc] init];
    _chevronLabel.text = @"›";
    _chevronLabel.textAlignment = NSTextAlignmentCenter;
    _chevronLabel.textColor = [UIColor colorWithWhite:1 alpha:0.85];
    _chevronLabel.font = [UIFont systemFontOfSize:38 weight:UIFontWeightLight];
    [_sliderHitView addSubview:_chevronLabel];

    _slideLabel = [[N15GlintLabel alloc] init];
    _slideLabel.text = @"slide to unlock";
    [_sliderHitView addSubview:_slideLabel];

    _slideGesture =
        [[UIPanGestureRecognizer alloc] initWithTarget:self
                                               action:@selector(handleSlide:)];
    _slideGesture.delegate = self;
    [_sliderHitView addGestureRecognizer:_slideGesture];


    _mediaView = [[N15MediaView alloc] init];
    [self addSubview:_mediaView];

    _clockTimer =
        [NSTimer scheduledTimerWithTimeInterval:15.0
                                         target:self
                                       selector:@selector(updateClock)
                                       userInfo:nil
                                        repeats:YES];

    [self updateClock];
    [self updateLockedState];

    return self;
}

- (void)dealloc {
    [self.clockTimer invalidate];
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hitView = [super hitTest:point withEvent:event];

    if (hitView == self ||
        hitView == self.timeLabel ||
        hitView == self.dateLabel ||
        hitView == self.separatorView) {
        return nil;
    }

    return hitView;
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat width = CGRectGetWidth(self.bounds);
    CGFloat height = CGRectGetHeight(self.bounds);
    CGFloat safeTop = self.safeAreaInsets.top;
    CGFloat safeBottom = self.safeAreaInsets.bottom;

    self.timeLabel.frame =
        CGRectMake(14, safeTop + 18, width - 28, 82);

    self.dateLabel.frame =
        CGRectMake(14, safeTop + 91, width - 28, 30);

    self.separatorView.frame =
        CGRectMake(0, safeTop + 130, width, 0.5);

    CGFloat sliderHeight = 88.0 + safeBottom;
    self.sliderHitView.frame =
        CGRectMake(0, height - sliderHeight, width, sliderHeight);

    self.chevronLabel.frame =
        CGRectMake(18, 0, 44, 72);

    self.slideLabel.frame =
        CGRectMake(56, 0, width - 112, 72);

    self.mediaView.frame = self.bounds;

    [self updateSlideTransformAnimated:NO];
}

- (void)updateClock {
    NSDate *now = [NSDate date];

    NSDateFormatter *timeFormatter = [[NSDateFormatter alloc] init];
    timeFormatter.locale = NSLocale.currentLocale;
    timeFormatter.dateFormat =
        [NSDateFormatter dateFormatFromTemplate:@"j:mm"
                                         options:0
                                          locale:NSLocale.currentLocale];

    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.locale = NSLocale.currentLocale;
    dateFormatter.dateFormat =
        [NSDateFormatter dateFormatFromTemplate:@"EEEE d MMMM"
                                         options:0
                                          locale:NSLocale.currentLocale];

    self.timeLabel.text = [timeFormatter stringFromDate:now];
    self.dateLabel.text = [dateFormatter stringFromDate:now];
}

- (void)updateLockedState {
    BOOL showLockUI = N15Enabled && N15Locked;
    BOOL mediaShowing = showLockUI && self.mediaView.hasContent;

    self.timeLabel.hidden = !showLockUI || mediaShowing;
    self.dateLabel.hidden = !showLockUI || mediaShowing;
    self.separatorView.hidden = !showLockUI || mediaShowing;

    BOOL hideSliderForNotifications = N15NotificationCount > 0;

    self.sliderHitView.hidden =
        !showLockUI || mediaShowing || hideSliderForNotifications;

    self.mediaView.hidden = !mediaShowing;
    [self.mediaView refreshNowPlaying];
}

- (void)handleSlide:(UIPanGestureRecognizer *)gesture {
    if (!N15Locked || self.mediaView.hasContent) {
        return;
    }

    CGPoint translation = [gesture translationInView:self.sliderHitView];

    CGFloat availableDistance =
        MAX(CGRectGetWidth(self.sliderHitView.bounds) - 90.0, 1.0);

    if (gesture.state == UIGestureRecognizerStateChanged) {
        self.slideProgress =
            MIN(MAX(translation.x / availableDistance, 0.0), 1.0);

        [self updateSlideTransformAnimated:NO];
        return;
    }

    if (gesture.state == UIGestureRecognizerStateEnded ||
        gesture.state == UIGestureRecognizerStateCancelled ||
        gesture.state == UIGestureRecognizerStateFailed) {

        BOOL completed =
            self.slideProgress >= 0.72 ||
            [gesture velocityInView:self.sliderHitView].x > 900.0;

        if (completed) {
            self.slideProgress = 1.0;
            [self updateSlideTransformAnimated:YES];

            dispatch_after(
                dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.12 * NSEC_PER_SEC)),
                dispatch_get_main_queue(),
                ^{
                    N15RequestUnlock();
                }
            );
        }

        self.slideProgress = 0.0;
        [self updateSlideTransformAnimated:YES];
    }
}

- (void)updateSlideTransformAnimated:(BOOL)animated {
    CGFloat availableDistance =
        MAX(CGRectGetWidth(self.sliderHitView.bounds) - 90.0, 1.0);

    CGFloat x = availableDistance * self.slideProgress;
    CGAffineTransform transform = CGAffineTransformMakeTranslation(x, 0);

    void (^changes)(void) = ^{
        self.chevronLabel.transform = transform;
        self.slideLabel.alpha = 1.0 - (self.slideProgress * 0.65);
    };

    if (animated) {
        [UIView animateWithDuration:0.22
                              delay:0
                            options:UIViewAnimationOptionCurveEaseOut |
                                    UIViewAnimationOptionBeginFromCurrentState
                         animations:changes
                         completion:nil];
    } else {
        changes();
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
       shouldRecognizeSimultaneouslyWithGestureRecognizer:
           (UIGestureRecognizer *)otherGestureRecognizer {
    return NO;
}

@end

static void N15SetLocked(BOOL locked) {
    N15Locked = locked;

    dispatch_async(dispatch_get_main_queue(), ^{
        [N15CurrentOverlay updateLockedState];
        N15UpdateNotificationBackdrop();
    });
}

#pragma mark - Cover Sheet / Lock Screen

%hook CSCoverSheetViewController

- (void)viewDidLoad {
    %orig;

    N15CurrentCoverController = self;
    N15EnsureCoverBlur(self);
    N15UpdateNotificationBackdrop();
}

- (void)viewDidLayoutSubviews {
    %orig;

    N15CurrentCoverController = self;
    N15EnsureCoverBlur(self);
}

- (void)viewWillAppear:(BOOL)animated {
    %orig;

    BOOL authenticated = NO;

    @try {
        authenticated = self.isAuthenticated;
    } @catch (__unused NSException *exception) {
        authenticated = NO;
    }

    N15SetLocked(!authenticated);
}

- (void)setAuthenticated:(BOOL)authenticated {
    %orig(authenticated);
    N15SetLocked(!authenticated);
}

%end

%hook CSMainPageView

- (void)layoutSubviews {
    %orig;

    N15LockOverlayView *overlay = N15GetOverlay(self);

    if (!N15Enabled) {
        overlay.hidden = YES;
        return;
    }

    if (!overlay) {
        overlay = [[N15LockOverlayView alloc] initWithFrame:self.bounds];
        overlay.autoresizingMask =
            UIViewAutoresizingFlexibleWidth |
            UIViewAutoresizingFlexibleHeight;

        N15SetOverlay(self, overlay);
        [self addSubview:overlay];
    }

    overlay.frame = self.bounds;
    overlay.hidden = NO;

    N15CurrentOverlay = overlay;

    [self bringSubviewToFront:overlay];
    [overlay updateLockedState];
}

%end

%hook SBFLockScreenDateView

- (void)layoutSubviews {
    %orig;

    if (N15Enabled) {
        self.alpha = 0.0;
        self.hidden = YES;
    }
}

%end

%hook CSFixedFooterViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;

    if (N15Enabled && N15Locked) {
        self.view.hidden = YES;
        self.view.alpha = 0.0;
    }
}

%end

%hook CSTeachableMomentsContainerViewController

- (void)viewDidLoad {
    %orig;

    if (N15Enabled) {
        self.view.hidden = YES;
        self.view.alpha = 0.0;
    }
}

%end

%hook CSCoverSheetView

- (void)layoutSubviews {
    %orig;

    if (!N15Enabled) {
        return;
    }

    @try {
        UIView *quickActions = [self valueForKey:@"_quickActionsView"];

        if ([quickActions isKindOfClass:UIView.class]) {
            quickActions.hidden = YES;
            quickActions.alpha = 0.0;
        }
    } @catch (__unused NSException *exception) {
    }
}

%end

#pragma mark - Notifications / banners

%hook NCNotificationShortLookView

- (void)layoutSubviews {
    %orig;

    if (!N15Enabled) {
        return;
    }

    BOOL isBanner = N15IsBannerShortLook(self);

    self.backgroundColor = UIColor.clearColor;
    self.layer.cornerRadius = 0.0;
    self.layer.masksToBounds = NO;
    self.clipsToBounds = NO;

    @try {
        UIView *background = self.backgroundView;

        if ([background isKindOfClass:UIView.class]) {
            background.layer.cornerRadius = 0.0;

            if (isBanner) {
                // Keep one continuous banner material, but square it like iOS 9.
                background.hidden = NO;
                background.alpha = 1.0;
            } else {
                // Lock Screen / Notification Center use one shared backdrop,
                // not a blur platter for each individual notification.
                background.hidden = YES;
                background.alpha = 0.0;
            }
        }
    } @catch (__unused NSException *exception) {
    }

    if (!isBanner) {
        N15ClearNotificationMaterials(self);
        N15StyleNotificationText(self);

        UIView *separatorView = N15GetSeparatorView(self);

        if (!separatorView) {
            separatorView = [[UIView alloc] init];
            separatorView.backgroundColor =
                [UIColor colorWithWhite:1.0 alpha:0.28];
            separatorView.userInteractionEnabled = NO;

            N15SetSeparatorView(self, separatorView);
            [self addSubview:separatorView];
        }

        CGFloat onePixel = 1.0 / UIScreen.mainScreen.scale;

        separatorView.frame =
            CGRectMake(
                0,
                MAX(CGRectGetHeight(self.bounds) - onePixel, 0),
                CGRectGetWidth(self.bounds),
                onePixel
            );

        [self bringSubviewToFront:separatorView];

        if (self.window && N15NotificationCount == 0) {
            // Gives immediate visual feedback even before MasterList recounts.
            N15SetNotificationCount(1);
        }
    } else {
        // Banners should be full-width/square rather than the modern pill/card.
        for (UIView *subview in self.subviews) {
            subview.layer.cornerRadius = 0.0;
        }
        N15StyleNotificationText(self);
    }
}

%end

%hook NCNotificationContentView

- (void)layoutSubviews {
    %orig;

    if (!N15Enabled) {
        return;
    }

    self.backgroundColor = UIColor.clearColor;
    N15StyleNotificationText(self);

    UILabel *primary = nil;
    UILabel *secondary = nil;
    UILabel *subtitle = nil;

    @try {
        primary = self.primaryLabel;
        secondary = self.secondaryLabel;
        subtitle = self.primarySubtitleLabel;
    } @catch (__unused NSException *exception) {
    }

    NSArray<UILabel *> *labels = @[
        primary ?: (UILabel *)[NSNull null],
        secondary ?: (UILabel *)[NSNull null],
        subtitle ?: (UILabel *)[NSNull null]
    ];

    for (id object in labels) {
        if (![object isKindOfClass:UILabel.class]) {
            continue;
        }

        UILabel *label = (UILabel *)object;
        label.layer.filters = nil;
        label.textColor = [UIColor colorWithWhite:1.0 alpha:0.96];
    }

    UITextView *secondaryTextView = N15ObjectIvar(self, "_secondaryTextView");
    if ([secondaryTextView isKindOfClass:UITextView.class]) {
        secondaryTextView.layer.filters = nil;
        secondaryTextView.textColor =
            [UIColor colorWithWhite:1.0 alpha:0.96];
        secondaryTextView.backgroundColor = UIColor.clearColor;
    }
}

%end

%hook PLPlatterHeaderContentView

- (void)layoutSubviews {
    %orig;

    if (!N15Enabled) {
        return;
    }

    N15StyleNotificationText(self);

    UILabel *titleLabel = N15ObjectIvar(self, "_titleLabel");
    UILabel *dateLabel = N15ObjectIvar(self, "_dateLabel");
    UIImageView *iconView = N15ObjectIvar(self, "_iconView");

    if ([titleLabel isKindOfClass:UILabel.class]) {
        titleLabel.layer.filters = nil;
        titleLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.90];
        titleLabel.font =
            [UIFont systemFontOfSize:14.0 weight:UIFontWeightRegular];
    }

    if ([dateLabel isKindOfClass:UILabel.class]) {
        dateLabel.layer.filters = nil;
        dateLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.82];
        dateLabel.font =
            [UIFont systemFontOfSize:14.0 weight:UIFontWeightRegular];
    }

    if ([iconView isKindOfClass:UIImageView.class]) {
        CGPoint center = iconView.center;
        iconView.bounds = CGRectMake(0, 0, 26.0, 26.0);
        iconView.center = center;
        iconView.layer.cornerRadius = 5.0;
        iconView.clipsToBounds = YES;
    }
}

%end

%hook NCNotificationListCellActionButton

- (void)_configureBackgroundViewIfNecessary {
    %orig;

    if (!N15Enabled) {
        return;
    }

    @try {
        self.backgroundView.alpha = 0.0;
        self.backgroundView.hidden = YES;
        self.backgroundView.layer.cornerRadius = 0.0;
    } @catch (__unused NSException *exception) {
    }
}

- (void)layoutSubviews {
    %orig;

    if (!N15Enabled) {
        return;
    }

    @try {
        self.backgroundView.alpha = 0.0;
        self.backgroundView.hidden = YES;
        self.backgroundView.layer.cornerRadius = 0.0;
    } @catch (__unused NSException *exception) {
    }

    N15StyleNotificationText(self);
}

%end

// Match NineLS' no-coalescing approach so "Show Less"/group cards disappear.
%hook NCToggleControlPair

- (void)layoutSubviews {
    %orig;

    if (N15Enabled) {
        self.hidden = YES;
        self.alpha = 0.0;
    }
}

%end

%hook NCToggleControl

- (void)layoutSubviews {
    %orig;

    if (N15Enabled) {
        self.hidden = YES;
        self.alpha = 0.0;
    }
}

%end

%hook NCNotificationListCoalescingHeaderCell

- (void)layoutSubviews {
    %orig;

    if (N15Enabled) {
        self.hidden = YES;
        self.alpha = 0.0;
    }
}

%end

%hook NCNotificationListCoalescingControlsCell

- (void)layoutSubviews {
    %orig;

    if (N15Enabled) {
        self.hidden = YES;
        self.alpha = 0.0;
    }
}

%end

%hook NCNotificationGroupList

- (BOOL)isGrouped {
    return N15Enabled ? NO : %orig;
}

- (void)setGrouped:(BOOL)grouped {
    if (N15Enabled) {
        %orig(NO);
        return;
    }

    %orig(grouped);
}

- (BOOL)notificationListViewIsGroup:(id)view {
    return N15Enabled ? NO : %orig(view);
}

- (BOOL)_isContentRevealedForNotificationRequest:(id)request {
    return N15Enabled ? YES : %orig(request);
}

%end

%hook NCNotificationListView

- (double)_headerViewHeight {
    return N15Enabled ? 0.0 : %orig;
}

- (double)_footerViewHeight {
    return N15Enabled ? 0.0 : %orig;
}

- (BOOL)_isGrouping {
    return N15Enabled ? NO : %orig;
}

- (BOOL)isPerformingGroupingAnimation {
    return N15Enabled ? NO : %orig;
}

%end

%hook NCNotificationListViewController

- (BOOL)isGrouped {
    return N15Enabled ? NO : %orig;
}

- (void)setGrouped:(BOOL)grouped {
    if (N15Enabled) {
        %orig(NO);
        return;
    }

    %orig(grouped);
}

- (BOOL)notificationListViewIsGroup:(id)view {
    return N15Enabled ? NO : %orig(view);
}

- (BOOL)_isContentRevealedForNotificationRequest:(id)request {
    return N15Enabled ? YES : %orig(request);
}

%end

// Eliminate the modern gap between rounded cards.
%hook NCNotificationListCollectionViewFlowLayout

- (void)prepareLayout {
    %orig;

    if (!N15Enabled) {
        return;
    }

    self.minimumLineSpacing = 0.0;
    self.minimumInteritemSpacing = 0.0;
}

%end

// NineLS uses MasterList's count to show a single blur behind notifications.
%hook NCNotificationMasterList

- (unsigned long long)notificationCount {
    unsigned long long count = %orig;

    if (N15Enabled) {
        N15SetNotificationCount((NSUInteger)count);
    }

    return count;
}

%end

#pragma mark - Hide stock Lock Screen media controls

%hook MRUNowPlayingViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;

    if (!N15Enabled) {
        return;
    }

    NSInteger context = 0;

    @try {
        context = self.context;
    } @catch (__unused NSException *exception) {
        context = 0;
    }

    // MediaControls context 2 is the Lock Screen on the iOS 14/15-era stack.
    if (context == 2) {
        self.view.hidden = YES;
        self.view.alpha = 0.0;
    }
}

- (void)viewWillLayoutSubviews {
    %orig;

    if (!N15Enabled) {
        return;
    }

    NSInteger context = 0;

    @try {
        context = self.context;
    } @catch (__unused NSException *exception) {
        context = 0;
    }

    if (context == 2) {
        self.view.hidden = YES;
        self.view.alpha = 0.0;
    }
}

%end

#pragma mark - Constructor

%ctor {
    @autoreleasepool {
        NSString *systemVersion = UIDevice.currentDevice.systemVersion;

        if ([systemVersion compare:@"15.0" options:NSNumericSearch] == NSOrderedAscending ||
            [systemVersion compare:@"16.0" options:NSNumericSearch] != NSOrderedAscending) {
            N15Enabled = NO;
            return;
        }

        N15Enabled = YES;
    }
}
