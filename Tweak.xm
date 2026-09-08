#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/message.h>
#import <objc/runtime.h>

#pragma mark - Private classes

@interface CSMainPageView : UIView
@end

@interface CSCoverSheetViewController : UIViewController
@property(nonatomic, getter=isAuthenticated) BOOL authenticated;
@end

@interface SBLockScreenManager : NSObject
+ (instancetype)sharedInstance;
- (void)lockScreenViewControllerRequestsUnlock;
- (BOOL)_finishUIUnlockFromSource:(int)source withOptions:(id)options;
- (void)lockUIFromSource:(int)source withOptions:(id)options;
@end

@interface SBUICallToActionLabel : UIView
- (void)setText:(id)text
    forLanguage:(id)language
       animated:(BOOL)animated;
@end

#pragma mark - State

static BOOL N15Enabled = YES;
static BOOL N15OnLockScreen = YES;

@class N15SlideToUnlockView;

static __weak N15SlideToUnlockView *N15CurrentSlideView = nil;

static const void *N15SlideAssociationKey =
    &N15SlideAssociationKey;

#pragma mark - Helpers

static id N15SharedLockScreenManager(void) {
    Class managerClass =
        NSClassFromString(@"SBLockScreenManager");

    if (!managerClass) {
        return nil;
    }

    SEL selector =
        NSSelectorFromString(@"sharedInstance");

    if (![managerClass respondsToSelector:selector]) {
        return nil;
    }

    return ((id (*)(id, SEL))objc_msgSend)(
        managerClass,
        selector
    );
}

static void N15RequestUnlock(void) {
    id manager =
        N15SharedLockScreenManager();

    if (!manager) {
        return;
    }

    SEL selector =
        NSSelectorFromString(
            @"lockScreenViewControllerRequestsUnlock"
        );

    if (![manager respondsToSelector:selector]) {
        return;
    }

    ((void (*)(id, SEL))objc_msgSend)(
        manager,
        selector
    );
}

static N15SlideToUnlockView *N15GetSlideView(
    CSMainPageView *view
) {
    if (!view) {
        return nil;
    }

    return objc_getAssociatedObject(
        view,
        N15SlideAssociationKey
    );
}

static void N15SetSlideView(
    CSMainPageView *view,
    N15SlideToUnlockView *slideView
) {
    if (!view) {
        return;
    }

    objc_setAssociatedObject(
        view,
        N15SlideAssociationKey,
        slideView,
        OBJC_ASSOCIATION_RETAIN_NONATOMIC
    );
}

#pragma mark - Glint label

@interface N15GlintLabel : UILabel
@property(nonatomic, strong) CAGradientLayer *glintLayer;
@end

@implementation N15GlintLabel

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];

    if (!self) {
        return nil;
    }

    self.textAlignment =
        NSTextAlignmentCenter;

    self.textColor =
        UIColor.whiteColor;

    self.font =
        [UIFont systemFontOfSize:21.0
                         weight:UIFontWeightLight];

    self.userInteractionEnabled =
        NO;

    self.layer.shadowColor =
        UIColor.blackColor.CGColor;

    self.layer.shadowOpacity =
        0.35;

    self.layer.shadowRadius =
        1.5;

    self.layer.shadowOffset =
        CGSizeMake(0.0, 1.0);

    _glintLayer =
        [CAGradientLayer layer];

    _glintLayer.colors = @[
        (__bridge id)
        [UIColor colorWithWhite:1.0 alpha:0.30].CGColor,

        (__bridge id)
        UIColor.whiteColor.CGColor,

        (__bridge id)
        [UIColor colorWithWhite:1.0 alpha:0.30].CGColor
    ];

    _glintLayer.locations =
        @[@0.0, @0.5, @1.0];

    _glintLayer.startPoint =
        CGPointMake(0.0, 0.5);

    _glintLayer.endPoint =
        CGPointMake(1.0, 0.5);

    self.layer.mask =
        _glintLayer;

    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];

    self.glintLayer.frame =
        self.bounds;

    if (![self.glintLayer
        animationForKey:@"nine15.glint"]) {

        CABasicAnimation *animation =
            [CABasicAnimation
                animationWithKeyPath:@"locations"];

        animation.fromValue =
            @[@-1.0, @-0.5, @0.0];

        animation.toValue =
            @[@1.0, @1.5, @2.0];

        animation.duration =
            2.3;

        animation.repeatCount =
            HUGE_VALF;

        [self.glintLayer
            addAnimation:animation
                  forKey:@"nine15.glint"];
    }
}

@end

#pragma mark - Slide to Unlock

@interface N15SlideToUnlockView : UIView

@property(nonatomic, strong) UIView *topSeparator;
@property(nonatomic, strong) UILabel *chevronLabel;
@property(nonatomic, strong) N15GlintLabel *slideLabel;
@property(nonatomic, strong) UIPanGestureRecognizer *panGesture;

@property(nonatomic, assign) CGFloat progress;
@property(nonatomic, assign) BOOL completing;

- (void)updateVisibility;
- (void)resetAnimated:(BOOL)animated;

@end

@implementation N15SlideToUnlockView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];

    if (!self) {
        return nil;
    }

    self.backgroundColor =
        UIColor.clearColor;

    self.userInteractionEnabled =
        YES;

    _topSeparator =
        [[UIView alloc] init];

    _topSeparator.backgroundColor =
        [UIColor colorWithWhite:1.0
                          alpha:0.20];

    _topSeparator.userInteractionEnabled =
        NO;

    [self addSubview:_topSeparator];

    _chevronLabel =
        [[UILabel alloc] init];

    _chevronLabel.text =
        @"›";

    _chevronLabel.textAlignment =
        NSTextAlignmentCenter;

    _chevronLabel.textColor =
        [UIColor colorWithWhite:1.0
                          alpha:0.90];

    _chevronLabel.font =
        [UIFont systemFontOfSize:40.0
                         weight:UIFontWeightLight];

    _chevronLabel.userInteractionEnabled =
        NO;

    _chevronLabel.layer.shadowColor =
        UIColor.blackColor.CGColor;

    _chevronLabel.layer.shadowOpacity =
        0.35;

    _chevronLabel.layer.shadowRadius =
        1.5;

    _chevronLabel.layer.shadowOffset =
        CGSizeMake(0.0, 1.0);

    [self addSubview:_chevronLabel];

    _slideLabel =
        [[N15GlintLabel alloc] init];

    _slideLabel.text =
        @"slide to unlock";

    [self addSubview:_slideLabel];

    _panGesture =
        [[UIPanGestureRecognizer alloc]
            initWithTarget:self
                    action:@selector(handlePan:)];

    _panGesture.minimumNumberOfTouches =
        1;

    _panGesture.maximumNumberOfTouches =
        1;

    _panGesture.cancelsTouchesInView =
        YES;

    [self addGestureRecognizer:_panGesture];

    [self updateVisibility];

    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat width =
        CGRectGetWidth(self.bounds);

    CGFloat scale =
        UIScreen.mainScreen.scale;

    CGFloat onePixel =
        scale > 0.0
        ? 1.0 / scale
        : 0.5;

    self.topSeparator.frame =
        CGRectMake(
            0.0,
            0.0,
            width,
            onePixel
        );

    self.chevronLabel.frame =
        CGRectMake(
            14.0,
            2.0,
            48.0,
            70.0
        );

    self.slideLabel.frame =
        CGRectMake(
            54.0,
            2.0,
            MAX(width - 108.0, 0.0),
            70.0
        );

    [self applyProgress];
}

- (void)updateVisibility {
    BOOL shouldShow =
        N15Enabled &&
        N15OnLockScreen;

    self.hidden =
        !shouldShow;

    self.userInteractionEnabled =
        shouldShow;

    if (shouldShow &&
        !self.completing) {

        self.alpha =
            1.0;
    }
}

- (void)handlePan:
    (UIPanGestureRecognizer *)gesture {

    if (!N15OnLockScreen ||
        self.completing) {

        return;
    }

    CGFloat width =
        CGRectGetWidth(self.bounds);

    CGFloat availableDistance =
        MAX(
            width - 82.0,
            1.0
        );

    CGPoint translation =
        [gesture translationInView:self];

    if (gesture.state ==
        UIGestureRecognizerStateBegan) {

        self.progress =
            0.0;

        self.slideLabel.alpha =
            1.0;

        return;
    }

    if (gesture.state ==
        UIGestureRecognizerStateChanged) {

        CGFloat horizontalDistance =
            MAX(
                translation.x,
                0.0
            );

        self.progress =
            MIN(
                horizontalDistance /
                availableDistance,
                1.0
            );

        [self applyProgress];

        return;
    }

    if (gesture.state ==
            UIGestureRecognizerStateEnded ||
        gesture.state ==
            UIGestureRecognizerStateCancelled ||
        gesture.state ==
            UIGestureRecognizerStateFailed) {

        CGFloat velocity =
            [gesture velocityInView:self].x;

        BOOL completed =
            self.progress >= 0.72 ||
            (
                self.progress >= 0.35 &&
                velocity > 850.0
            );

        if (completed) {
            [self completeSlide];
        } else {
            [self resetAnimated:YES];
        }
    }
}

- (void)completeSlide {
    if (self.completing) {
        return;
    }

    self.completing =
        YES;

    self.progress =
        1.0;

    [UIView
        animateWithDuration:0.16
                      delay:0.0
                    options:
            UIViewAnimationOptionCurveEaseOut |
            UIViewAnimationOptionBeginFromCurrentState
                 animations:^{

        [self applyProgress];

        self.slideLabel.alpha =
            0.0;

    } completion:^(__unused BOOL finished) {

        /*
         * Important:
         * This only makes Apple's normal unlock request.
         * It does NOT block Home, Touch ID, passcode,
         * or any SpringBoard unlock method.
         */
        N15RequestUnlock();

        /*
         * If unlock requires a passcode, the Lock Screen
         * still exists. Restore the slider if necessary.
         *
         * If unlock succeeds, _finishUIUnlockFromSource:
         * will change N15OnLockScreen to NO and hide us.
         */
        dispatch_after(
            dispatch_time(
                DISPATCH_TIME_NOW,
                (int64_t)(
                    0.55 *
                    NSEC_PER_SEC
                )
            ),
            dispatch_get_main_queue(),
            ^{
                if (N15OnLockScreen) {
                    [self resetAnimated:YES];
                }
            }
        );
    }];
}

- (void)resetAnimated:
    (BOOL)animated {

    self.completing =
        NO;

    self.progress =
        0.0;

    void (^changes)(void) = ^{
        self.chevronLabel.transform =
            CGAffineTransformIdentity;

        self.slideLabel.alpha =
            1.0;
    };

    if (!animated) {
        changes();
        return;
    }

    [UIView
        animateWithDuration:0.22
                      delay:0.0
                    options:
            UIViewAnimationOptionCurveEaseOut |
            UIViewAnimationOptionBeginFromCurrentState
                 animations:
            changes
                 completion:nil];
}

- (void)applyProgress {
    CGFloat width =
        CGRectGetWidth(self.bounds);

    CGFloat availableDistance =
        MAX(
            width - 82.0,
            1.0
        );

    CGFloat translation =
        availableDistance *
        self.progress;

    self.chevronLabel.transform =
        CGAffineTransformMakeTranslation(
            translation,
            0.0
        );

    if (!self.completing) {
        self.slideLabel.alpha =
            MAX(
                1.0 -
                self.progress * 0.70,
                0.20
            );
    }
}

@end

#pragma mark - State updates

static void N15SetOnLockScreen(
    BOOL onLockScreen
) {
    if (N15OnLockScreen ==
        onLockScreen) {

        return;
    }

    N15OnLockScreen =
        onLockScreen;

    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            N15SlideToUnlockView *slideView =
                N15CurrentSlideView;

            if (!slideView) {
                return;
            }

            [slideView updateVisibility];

            if (onLockScreen) {
                [slideView resetAnimated:NO];
            }
        }
    );
}

#pragma mark - Main Lock Screen view

%hook CSMainPageView

- (void)layoutSubviews {
    %orig;

    if (!N15Enabled) {
        return;
    }

    N15SlideToUnlockView *slideView =
        N15GetSlideView(self);

    if (!slideView) {
        slideView =
            [[N15SlideToUnlockView alloc]
                initWithFrame:CGRectZero];

        slideView.autoresizingMask =
            UIViewAutoresizingFlexibleWidth |
            UIViewAutoresizingFlexibleTopMargin;

        N15SetSlideView(
            self,
            slideView
        );

        [self addSubview:slideView];
    }

    N15CurrentSlideView =
        slideView;

    CGFloat width =
        CGRectGetWidth(self.bounds);

    CGFloat height =
        CGRectGetHeight(self.bounds);

    CGFloat safeBottom =
        self.safeAreaInsets.bottom;

    CGFloat slideHeight =
        76.0 + safeBottom;

    slideView.frame =
        CGRectMake(
            0.0,
            MAX(
                height - slideHeight,
                0.0
            ),
            width,
            slideHeight
        );

    /*
     * We are NOT asking SpringBoard whether it is locked
     * here. layoutSubviews can run dozens of times during
     * Touch ID/authentication/transitions.
     *
     * Visibility comes only from N15OnLockScreen.
     */
    [slideView updateVisibility];

    if (N15OnLockScreen) {
        [self bringSubviewToFront:slideView];
    }
}

%end

#pragma mark - Lock Screen state

%hook CSCoverSheetViewController

- (void)viewWillAppear:
    (BOOL)animated {

    %orig;

    /*
     * Same basic approach used by NineLS:
     * when CoverSheet appears, authenticated == NO means
     * this is the actual Lock Screen.
     *
     * We intentionally do NOT hook setAuthenticated:.
     * Touch ID can authenticate while the Lock Screen is
     * still visible, and the slider must remain present.
     */
    BOOL authenticated =
        NO;

    @try {
        authenticated =
            self.authenticated;
    } @catch (__unused NSException *exception) {
        authenticated =
            NO;
    }

    N15SetOnLockScreen(
        !authenticated
    );
}

%end

#pragma mark - Observe lock/unlock completion only

%hook SBLockScreenManager

- (void)lockUIFromSource:
    (int)source
            withOptions:
    (id)options {

    /*
     * Never block or alter Apple's locking call.
     */
    %orig(source, options);

    if (N15Enabled) {
        N15SetOnLockScreen(YES);
    }
}

- (BOOL)_finishUIUnlockFromSource:
    (int)source
                      withOptions:
    (id)options {

    /*
     * Never block or modify the unlock.
     * First let SpringBoard finish normally.
     */
    BOOL result =
        %orig(source, options);

    if (N15Enabled &&
        result) {

        N15SetOnLockScreen(NO);
    }

    return result;
}

%end

#pragma mark - Hide Apple's "Press home to unlock" text

%hook SBUICallToActionLabel

- (void)setText:
    (id)text
    forLanguage:
    (id)language
    animated:
    (BOOL)animated {

    if (N15Enabled &&
        N15OnLockScreen) {

        %orig(
            @"",
            language,
            animated
        );

        return;
    }

    %orig(
        text,
        language,
        animated
    );
}

%end

#pragma mark - Constructor

%ctor {
    @autoreleasepool {
        NSString *version =
            UIDevice.currentDevice.systemVersion;

        BOOL iOS15OrNewer =
            [version
                compare:@"15.0"
                options:NSNumericSearch] !=
            NSOrderedAscending;

        BOOL beforeIOS16 =
            [version
                compare:@"16.0"
                options:NSNumericSearch] ==
            NSOrderedAscending;

        N15Enabled =
            iOS15OrNewer &&
            beforeIOS16;

        N15OnLockScreen =
            YES;
    }
}
