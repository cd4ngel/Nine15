#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <dlfcn.h>

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

@interface NCNotificationListView : UIView
@end

@interface NCNotificationListViewController : UIViewController
@end

@interface NCNotificationListCellActionButton : UIButton
@property(nonatomic, strong) UIView *backgroundView;
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
@property(nonatomic, strong) UILabel *notificationCenterTitle;
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

    _notificationCenterTitle = [[UILabel alloc] init];
    _notificationCenterTitle.text = @"Notifications";
    _notificationCenterTitle.textAlignment = NSTextAlignmentCenter;
    _notificationCenterTitle.textColor = UIColor.whiteColor;
    _notificationCenterTitle.font =
        [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    _notificationCenterTitle.hidden = YES;
    [self addSubview:_notificationCenterTitle];

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
        hitView == self.separatorView ||
        hitView == self.notificationCenterTitle) {
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
        CGRectMake(14, safeTop + 37, width - 28, 78);

    self.dateLabel.frame =
        CGRectMake(14, safeTop + 108, width - 28, 30);

    self.separatorView.frame =
        CGRectMake(0, safeTop + 148, width, 0.5);

    CGFloat sliderHeight = 88.0 + safeBottom;
    self.sliderHitView.frame =
        CGRectMake(0, height - sliderHeight, width, sliderHeight);

    self.chevronLabel.frame =
        CGRectMake(18, 0, 44, 72);

    self.slideLabel.frame =
        CGRectMake(56, 0, width - 112, 72);

    self.notificationCenterTitle.frame =
        CGRectMake(0, safeTop + 10, width, 36);

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

    self.sliderHitView.hidden = !showLockUI || mediaShowing;
    self.notificationCenterTitle.hidden = showLockUI;

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
    });
}

#pragma mark - Cover Sheet / Lock Screen

%hook CSCoverSheetViewController

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

%property(nonatomic, strong) N15LockOverlayView *n15Overlay;

- (void)layoutSubviews {
    %orig;

    if (!N15Enabled) {
        self.n15Overlay.hidden = YES;
        return;
    }

    if (!self.n15Overlay) {
        self.n15Overlay = [[N15LockOverlayView alloc] initWithFrame:self.bounds];
        self.n15Overlay.autoresizingMask =
            UIViewAutoresizingFlexibleWidth |
            UIViewAutoresizingFlexibleHeight;

        [self addSubview:self.n15Overlay];
    }

    self.n15Overlay.frame = self.bounds;
    self.n15Overlay.hidden = NO;

    N15CurrentOverlay = self.n15Overlay;

    [self bringSubviewToFront:self.n15Overlay];
    [self.n15Overlay updateLockedState];
}

%end

%hook SBFLockScreenDateView

- (void)layoutSubviews {
    %orig;

    if (N15Enabled && N15Locked) {
        self.alpha = 0.0;
        self.hidden = YES;
    } else {
        self.alpha = 1.0;
        self.hidden = NO;
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

%property(nonatomic, strong) UIVisualEffectView *n15BlurView;
%property(nonatomic, strong) UIView *n15SeparatorView;

- (void)layoutSubviews {
    %orig;

    if (!N15Enabled) {
        return;
    }

    self.clipsToBounds = YES;
    self.layer.cornerRadius = 0.0;

    @try {
        UIView *background = self.backgroundView;

        if ([background isKindOfClass:UIView.class]) {
            background.hidden = YES;
        }
    } @catch (__unused NSException *exception) {
    }

    if (!self.n15BlurView) {
        UIBlurEffect *blur =
            [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterialDark];

        self.n15BlurView =
            [[UIVisualEffectView alloc] initWithEffect:blur];

        self.n15BlurView.userInteractionEnabled = NO;
        [self insertSubview:self.n15BlurView atIndex:0];
    }

    if (!self.n15SeparatorView) {
        self.n15SeparatorView = [[UIView alloc] init];
        self.n15SeparatorView.backgroundColor =
            [UIColor colorWithWhite:1.0 alpha:0.28];

        self.n15SeparatorView.userInteractionEnabled = NO;
        [self addSubview:self.n15SeparatorView];
    }

    self.n15BlurView.frame = self.bounds;
    self.n15SeparatorView.frame =
        CGRectMake(0, CGRectGetHeight(self.bounds) - 0.5,
                   CGRectGetWidth(self.bounds), 0.5);

    [self sendSubviewToBack:self.n15BlurView];
}

%end

%hook NCNotificationListCellActionButton

- (void)layoutSubviews {
    %orig;

    if (!N15Enabled) {
        return;
    }

    @try {
        self.backgroundView.layer.cornerRadius = 0.0;
    } @catch (__unused NSException *exception) {
    }
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
