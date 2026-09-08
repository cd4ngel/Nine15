#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <math.h>

#pragma mark - Private interfaces

@interface CSCoverSheetViewController : UIViewController
@property(nonatomic, assign, getter=isAuthenticated) BOOL authenticated;
@end

@interface SBLockScreenManager : NSObject
@end

@interface SBUICallToActionLabel : UILabel
@end

#pragma mark - State

static BOOL N15Enabled = YES;
static BOOL N15Locked = YES;

static char kN15SliderKey;
static char kN15PanKey;
static char kN15PanDelegateKey;

#pragma mark - SpringBoard helpers

static id N15LockScreenManager(void) {
    Class managerClass =
        NSClassFromString(@"SBLockScreenManager");

    if (!managerClass) {
        return nil;
    }

    SEL sharedSelector =
        NSSelectorFromString(@"sharedInstance");

    if (![managerClass
        respondsToSelector:sharedSelector]) {

        return nil;
    }

    return ((id (*)(id, SEL))objc_msgSend)(
        managerClass,
        sharedSelector
    );
}

static BOOL N15SystemIsLocked(
    BOOL fallback
) {
    id manager =
        N15LockScreenManager();

    if (!manager) {
        return fallback;
    }

    SEL selector =
        NSSelectorFromString(@"isUILocked");

    if (![manager
        respondsToSelector:selector]) {

        return fallback;
    }

    return ((BOOL (*)(id, SEL))objc_msgSend)(
        manager,
        selector
    );
}

static void N15RequestUnlock(void) {
    id manager =
        N15LockScreenManager();

    if (!manager) {
        return;
    }

    SEL selector =
        NSSelectorFromString(
            @"lockScreenViewControllerRequestsUnlock"
        );

    if (![manager
        respondsToSelector:selector]) {

        return;
    }

    ((void (*)(id, SEL))objc_msgSend)(
        manager,
        selector
    );
}

#pragma mark - Slide visual

@interface N15SlideToUnlockView : UIView

@property(nonatomic, strong)
UILabel *chevronLabel;

@property(nonatomic, strong)
UILabel *textLabel;

@property(nonatomic, strong)
CAGradientLayer *shimmerLayer;

@property(nonatomic, assign)
BOOL completing;

- (void)setSlideProgress:(CGFloat)progress;
- (void)resetAnimated:(BOOL)animated;
- (void)restartShimmer;

@end

@implementation N15SlideToUnlockView

- (instancetype)initWithFrame:
    (CGRect)frame {

    self =
        [super initWithFrame:frame];

    if (!self) {
        return nil;
    }

    self.backgroundColor =
        UIColor.clearColor;

    /*
     * Visual only.
     *
     * The gesture itself lives on the entire
     * CoverSheet, not on this bottom view.
     */
    self.userInteractionEnabled =
        NO;

    self.clipsToBounds =
        NO;

    _chevronLabel =
        [[UILabel alloc]
            initWithFrame:CGRectZero];

    _chevronLabel.backgroundColor =
        UIColor.clearColor;

    _chevronLabel.text =
        @"›";

    _chevronLabel.textColor =
        [UIColor
            colorWithWhite:1.0
                     alpha:0.72];

    _chevronLabel.font =
        [UIFont
            systemFontOfSize:32.0
                     weight:
                UIFontWeightUltraLight];

    _chevronLabel.textAlignment =
        NSTextAlignmentCenter;

    _chevronLabel.userInteractionEnabled =
        NO;

    [self addSubview:
        _chevronLabel];

    _textLabel =
        [[UILabel alloc]
            initWithFrame:CGRectZero];

    _textLabel.backgroundColor =
        UIColor.clearColor;

    _textLabel.text =
        @"slide to unlock";

    _textLabel.textColor =
        UIColor.whiteColor;

    _textLabel.font =
        [UIFont
            systemFontOfSize:24.0
                     weight:
                UIFontWeightLight];

    _textLabel.textAlignment =
        NSTextAlignmentCenter;

    _textLabel.userInteractionEnabled =
        NO;

    [self addSubview:
        _textLabel];

    _shimmerLayer =
        [CAGradientLayer layer];

    _shimmerLayer.colors = @[
        (__bridge id)
        [UIColor
            colorWithWhite:1.0
                     alpha:0.22].CGColor,

        (__bridge id)
        [UIColor
            colorWithWhite:1.0
                     alpha:1.0].CGColor,

        (__bridge id)
        [UIColor
            colorWithWhite:1.0
                     alpha:0.22].CGColor
    ];

    _shimmerLayer.locations =
        @[
            @0.0,
            @0.5,
            @1.0
        ];

    _shimmerLayer.startPoint =
        CGPointMake(
            0.0,
            0.5
        );

    _shimmerLayer.endPoint =
        CGPointMake(
            1.0,
            0.5
        );

    _textLabel.layer.mask =
        _shimmerLayer;

    return self;
}

- (void)didMoveToWindow {
    [super didMoveToWindow];

    if (self.window) {
        [self restartShimmer];
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat width =
        CGRectGetWidth(
            self.bounds
        );

    CGFloat textWidth =
        MIN(
            MAX(
                width - 70.0,
                0.0
            ),
            220.0
        );

    CGFloat combinedWidth =
        textWidth + 24.0;

    CGFloat startX =
        floor(
            (
                width -
                combinedWidth
            ) / 2.0
        );

    self.chevronLabel.frame =
        CGRectMake(
            startX,
            18.0,
            24.0,
            40.0
        );

    self.textLabel.frame =
        CGRectMake(
            startX + 22.0,
            20.0,
            textWidth,
            38.0
        );

    self.shimmerLayer.frame =
        self.textLabel.bounds;
}

- (void)restartShimmer {
    [self.shimmerLayer
        removeAnimationForKey:
            @"nine15.shimmer"];

    CABasicAnimation *animation =
        [CABasicAnimation
            animationWithKeyPath:
                @"locations"];

    animation.fromValue =
        @[
            @(-0.8),
            @(-0.4),
            @(0.0)
        ];

    animation.toValue =
        @[
            @(1.0),
            @(1.4),
            @(1.8)
        ];

    animation.duration =
        2.2;

    animation.repeatCount =
        HUGE_VALF;

    animation.timingFunction =
        [CAMediaTimingFunction
            functionWithName:
                kCAMediaTimingFunctionEaseInEaseOut];

    [self.shimmerLayer
        addAnimation:animation
              forKey:
            @"nine15.shimmer"];
}

- (void)setSlideProgress:
    (CGFloat)progress {

    CGFloat clamped =
        MIN(
            MAX(
                progress,
                0.0
            ),
            1.0
        );

    /*
     * The finger can start anywhere on screen.
     * Only the bottom visual moves slightly to
     * provide feedback.
     */

    CGFloat translation =
        clamped * 36.0;

    CGAffineTransform transform =
        CGAffineTransformMakeTranslation(
            translation,
            0.0
        );

    self.chevronLabel.transform =
        transform;

    self.textLabel.transform =
        transform;

    if (!self.completing) {
        self.alpha =
            1.0 -
            clamped * 0.38;
    }
}

- (void)resetAnimated:
    (BOOL)animated {

    self.completing =
        NO;

    void (^changes)(void) = ^{
        self.alpha =
            1.0;

        self.chevronLabel.transform =
            CGAffineTransformIdentity;

        self.textLabel.transform =
            CGAffineTransformIdentity;
    };

    if (!animated) {
        changes();
        return;
    }

    [UIView
        animateWithDuration:0.20
                      delay:0.0
                    options:
            UIViewAnimationOptionCurveEaseOut |
            UIViewAnimationOptionBeginFromCurrentState
                 animations:
            changes
                 completion:nil];
}

@end

#pragma mark - Global pan delegate

@interface N15GlobalPanDelegate :
    NSObject <UIGestureRecognizerDelegate>
@end

@implementation N15GlobalPanDelegate

- (BOOL)gestureRecognizerShouldBegin:
    (UIGestureRecognizer *)gestureRecognizer {

    /*
     * Do NOT inspect initial velocity here.
     *
     * Previous versions could reject the swipe
     * during the first few millimeters of movement.
     *
     * We let the pan begin and decide whether it
     * was a valid slide only when the finger moves
     * or is released.
     */

    return
        N15Enabled &&
        N15Locked &&
        [gestureRecognizer
            isKindOfClass:
                UIPanGestureRecognizer.class];
}

- (BOOL)gestureRecognizer:
    (UIGestureRecognizer *)gestureRecognizer
    shouldRecognizeSimultaneouslyWithGestureRecognizer:
    (UIGestureRecognizer *)otherGestureRecognizer {

    /*
     * Do not destroy SpringBoard's own vertical
     * scrolling / notification gestures.
     */

    (void)gestureRecognizer;
    (void)otherGestureRecognizer;

    return YES;
}

@end

#pragma mark - CoverSheet

%hook CSCoverSheetViewController

- (void)viewDidLoad {
    %orig;

    if (!N15Enabled) {
        return;
    }

    /*
     * Bottom VISUAL.
     *
     * There is deliberately no separator line.
     */

    N15SlideToUnlockView *slider =
        objc_getAssociatedObject(
            self,
            &kN15SliderKey
        );

    if (!slider) {
        slider =
            [[N15SlideToUnlockView alloc]
                initWithFrame:CGRectZero];

        slider.autoresizingMask =
            UIViewAutoresizingFlexibleWidth |
            UIViewAutoresizingFlexibleTopMargin;

        objc_setAssociatedObject(
            self,
            &kN15SliderKey,
            slider,
            OBJC_ASSOCIATION_RETAIN_NONATOMIC
        );

        [self.view
            addSubview:slider];
    }

    /*
     * FULL-SCREEN gesture.
     *
     * The recognizer belongs to CoverSheet itself,
     * therefore the swipe can begin anywhere:
     *
     * - clock
     * - wallpaper
     * - notifications
     * - bottom area
     */

    UIPanGestureRecognizer *pan =
        objc_getAssociatedObject(
            self,
            &kN15PanKey
        );

    if (!pan) {
        N15GlobalPanDelegate *delegate =
            [[N15GlobalPanDelegate alloc]
                init];

        pan =
            [[UIPanGestureRecognizer alloc]
                initWithTarget:self
                        action:
                    @selector(
                        n15_handleFullScreenPan:
                    )];

        pan.delegate =
            delegate;

        pan.minimumNumberOfTouches =
            1;

        pan.maximumNumberOfTouches =
            1;

        pan.cancelsTouchesInView =
            NO;

        pan.delaysTouchesBegan =
            NO;

        pan.delaysTouchesEnded =
            NO;

        objc_setAssociatedObject(
            self,
            &kN15PanDelegateKey,
            delegate,
            OBJC_ASSOCIATION_RETAIN_NONATOMIC
        );

        objc_setAssociatedObject(
            self,
            &kN15PanKey,
            pan,
            OBJC_ASSOCIATION_RETAIN_NONATOMIC
        );

        [self.view
            addGestureRecognizer:pan];
    }
}

- (void)viewWillAppear:
    (BOOL)animated {

    %orig(animated);

    if (!N15Enabled) {
        return;
    }

    /*
     * Determine the state ONCE when CoverSheet
     * appears.
     *
     * We do not poll isUILocked from layoutSubviews.
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

    BOOL fallbackLocked =
        !authenticated;

    N15Locked =
        N15SystemIsLocked(
            fallbackLocked
        );

    N15SlideToUnlockView *slider =
        objc_getAssociatedObject(
            self,
            &kN15SliderKey
        );

    slider.hidden =
        !N15Locked;

    if (N15Locked) {
        [slider
            resetAnimated:NO];
    }
}

- (void)viewDidAppear:
    (BOOL)animated {

    %orig(animated);

    if (!N15Enabled) {
        return;
    }

    /*
     * One second state confirmation when CoverSheet
     * has actually finished appearing.
     *
     * Again: no continuous polling.
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

    N15Locked =
        N15SystemIsLocked(
            !authenticated
        );

    N15SlideToUnlockView *slider =
        objc_getAssociatedObject(
            self,
            &kN15SliderKey
        );

    slider.hidden =
        !N15Locked;

    if (N15Locked) {
        [self.view
            bringSubviewToFront:
                slider];

        [slider
            resetAnimated:NO];
    }
}

- (void)viewDidLayoutSubviews {
    %orig;

    if (!N15Enabled) {
        return;
    }

    N15SlideToUnlockView *slider =
        objc_getAssociatedObject(
            self,
            &kN15SliderKey
        );

    if (!slider) {
        return;
    }

    CGFloat width =
        CGRectGetWidth(
            self.view.bounds
        );

    CGFloat height =
        CGRectGetHeight(
            self.view.bounds
        );

    CGFloat bottomInset =
        MAX(
            self.view.safeAreaInsets.bottom,
            5.0
        );

    /*
     * Only the VISUAL stays near the bottom.
     *
     * The gesture area is NOT this frame.
     * The gesture area is the entire self.view.
     */

    slider.frame =
        CGRectMake(
            0.0,
            MAX(
                height -
                bottomInset -
                112.0,
                0.0
            ),
            width,
            82.0
        );

    slider.hidden =
        !N15Locked;

    if (N15Locked) {
        [self.view
            bringSubviewToFront:
                slider];
    }
}

%new
- (void)n15_handleFullScreenPan:
    (UIPanGestureRecognizer *)gesture {

    if (!N15Enabled ||
        !N15Locked) {

        return;
    }

    N15SlideToUnlockView *slider =
        objc_getAssociatedObject(
            self,
            &kN15SliderKey
        );

    if (!slider ||
        slider.completing) {

        return;
    }

    CGPoint translation =
        [gesture
            translationInView:
                self.view];

    CGFloat width =
        MAX(
            CGRectGetWidth(
                self.view.bounds
            ),
            1.0
        );

    /*
     * Deterministic threshold.
     *
     * No "sometimes velocity is enough",
     * no initial-direction decision.
     *
     * On a 320pt screen:
     * 0.42 * 320 = 134.4pt.
     */

    CGFloat requiredDistance =
        MAX(
            width * 0.42,
            120.0
        );

    CGFloat rightDistance =
        MAX(
            translation.x,
            0.0
        );

    CGFloat progress =
        MIN(
            rightDistance /
                requiredDistance,
            1.0
        );

    if (gesture.state ==
        UIGestureRecognizerStateBegan) {

        [slider
            resetAnimated:NO];

        return;
    }

    if (gesture.state ==
        UIGestureRecognizerStateChanged) {

        [slider
            setSlideProgress:
                progress];

        return;
    }

    if (gesture.state ==
        UIGestureRecognizerStateEnded) {

        /*
         * We evaluate the COMPLETE gesture,
         * not its first few milliseconds.
         *
         * Require an actual predominantly-right
         * swipe so vertical notification scrolling
         * doesn't accidentally unlock.
         */

        CGFloat verticalDistance =
            fabs(
                translation.y
            );

        BOOL enoughDistance =
            rightDistance >=
            requiredDistance;

        BOOL sufficientlyHorizontal =
            rightDistance >=
            verticalDistance;

        BOOL shouldUnlock =
            enoughDistance &&
            sufficientlyHorizontal;

        if (!shouldUnlock) {
            [slider
                resetAnimated:YES];

            return;
        }

        slider.completing =
            YES;

        [slider
            setSlideProgress:1.0];

        [UIView
            animateWithDuration:0.14
                          delay:0.0
                        options:
                UIViewAnimationOptionCurveEaseOut |
                UIViewAnimationOptionBeginFromCurrentState
                     animations:^{

            slider.alpha =
                0.0;

            CGAffineTransform transform =
                CGAffineTransformMakeTranslation(
                    48.0,
                    0.0
                );

            slider.chevronLabel.transform =
                transform;

            slider.textLabel.transform =
                transform;

        } completion:^(__unused BOOL finished) {

            /*
             * Only request Apple's normal unlock.
             *
             * No unlock method is intercepted,
             * overridden or blocked.
             */

            N15RequestUnlock();

            /*
             * If a passcode is required or the
             * unlock isn't completed, make the
             * slider available again.
             */

            dispatch_after(
                dispatch_time(
                    DISPATCH_TIME_NOW,
                    (int64_t)(
                        0.60 *
                        NSEC_PER_SEC
                    )
                ),
                dispatch_get_main_queue(),
                ^{
                    if (slider.window) {
                        [slider
                            resetAnimated:NO];
                    }
                }
            );
        }];

        return;
    }

    if (gesture.state ==
            UIGestureRecognizerStateCancelled ||
        gesture.state ==
            UIGestureRecognizerStateFailed) {

        [slider
            resetAnimated:YES];
    }
}

%end

#pragma mark - Hide stock call-to-action

%hook SBUICallToActionLabel

- (void)layoutSubviews {
    %orig;

    if (!N15Enabled) {
        return;
    }

    self.hidden =
        N15Locked;

    self.alpha =
        N15Locked
        ? 0.0
        : 1.0;
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
    }
}
