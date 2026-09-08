#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <math.h>

#pragma mark - Private interfaces

@interface CSMainPageView : UIView
@end

@interface CSCoverSheetViewController : UIViewController
@property(nonatomic, assign, getter=isAuthenticated) BOOL authenticated;
@end

@interface SBUICallToActionLabel : UILabel
@end

#pragma mark - State

static BOOL NLSLocked = YES;

static char kNLSSlideViewKey;
static char kNLSFullScreenPanKey;
static char kNLSFullScreenPanDelegateKey;

#pragma mark - Unlock helper

static void NLSRequestUnlock(void) {
    Class managerClass =
        NSClassFromString(@"SBLockScreenManager");

    if (!managerClass) {
        return;
    }

    SEL sharedSelector =
        NSSelectorFromString(@"sharedInstance");

    if (![managerClass
        respondsToSelector:sharedSelector]) {

        return;
    }

    id manager =
        ((id (*)(id, SEL))objc_msgSend)(
            managerClass,
            sharedSelector
        );

    if (!manager) {
        return;
    }

    SEL unlockSelector =
        NSSelectorFromString(
            @"lockScreenViewControllerRequestsUnlock"
        );

    if (![manager
        respondsToSelector:unlockSelector]) {

        return;
    }

    ((void (*)(id, SEL))objc_msgSend)(
        manager,
        unlockSelector
    );
}

#pragma mark - Slide visual

@interface NLSSlideToUnlockView : UIView

@property(nonatomic, strong) UILabel *chevronLabel;
@property(nonatomic, strong) UILabel *textLabel;
@property(nonatomic, strong) CAGradientLayer *shimmerLayer;

@property(nonatomic, assign) BOOL completing;

- (void)restartShimmer;
- (void)setSlideProgress:(CGFloat)progress;
- (void)resetAnimated:(BOOL)animated;

@end

@implementation NLSSlideToUnlockView

- (instancetype)initWithFrame:(CGRect)frame {
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
     * It does NOT capture touches.
     * The full-screen gesture belongs to
     * CSMainPageView.
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
                     weight:UIFontWeightUltraLight];

    _chevronLabel.textAlignment =
        NSTextAlignmentCenter;

    _chevronLabel.userInteractionEnabled =
        NO;

    [self addSubview:_chevronLabel];

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
                     weight:UIFontWeightLight];

    _textLabel.textAlignment =
        NSTextAlignmentCenter;

    _textLabel.userInteractionEnabled =
        NO;

    [self addSubview:_textLabel];

    _shimmerLayer =
        [CAGradientLayer layer];

    _shimmerLayer.colors = @[
        (__bridge id)
        [UIColor
            colorWithWhite:1.0
                     alpha:0.22].CGColor,

        (__bridge id)
        UIColor.whiteColor.CGColor,

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
        CGPointMake(0.0, 0.5);

    _shimmerLayer.endPoint =
        CGPointMake(1.0, 0.5);

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
        CGRectGetWidth(self.bounds);

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
    if (CGRectGetWidth(
            self.textLabel.bounds
        ) <= 0.0) {

        [self setNeedsLayout];

        return;
    }

    [self.shimmerLayer
        removeAnimationForKey:
            @"ninels.slide.shimmer"];

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
            @"ninels.slide.shimmer"];
}

- (void)setSlideProgress:
    (CGFloat)progress {

    CGFloat value =
        MIN(
            MAX(
                progress,
                0.0
            ),
            1.0
        );

    CGFloat translation =
        value * 36.0;

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
            value * 0.40;
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
                 animations:changes
                 completion:nil];
}

@end

#pragma mark - Full screen gesture delegate

@interface NLSFullScreenPanDelegate :
    NSObject <UIGestureRecognizerDelegate>
@end

@implementation NLSFullScreenPanDelegate

- (BOOL)gestureRecognizerShouldBegin:
    (UIGestureRecognizer *)gestureRecognizer {

    /*
     * Do NOT test initial velocity or direction.
     *
     * That was one of the reasons previous
     * implementations felt random.
     */

    return
        NLSLocked &&
        [gestureRecognizer
            isKindOfClass:
                UIPanGestureRecognizer.class];
}

- (BOOL)gestureRecognizer:
    (UIGestureRecognizer *)gestureRecognizer
    shouldRecognizeSimultaneouslyWithGestureRecognizer:
    (UIGestureRecognizer *)otherGestureRecognizer {

    /*
     * The full-screen recognizer is an observer.
     *
     * Vertical notification scrolling and other
     * SpringBoard gestures remain available.
     */

    (void)gestureRecognizer;
    (void)otherGestureRecognizer;

    return YES;
}

@end

#pragma mark - Main page

%hook CSMainPageView

- (void)layoutSubviews {
    %orig;

    /*
     * ------------------------------------------------
     * VISUAL
     * ------------------------------------------------
     */

    NLSSlideToUnlockView *slideView =
        objc_getAssociatedObject(
            self,
            &kNLSSlideViewKey
        );

    if (!slideView) {
        slideView =
            [[NLSSlideToUnlockView alloc]
                initWithFrame:CGRectZero];

        slideView.autoresizingMask =
            UIViewAutoresizingFlexibleWidth |
            UIViewAutoresizingFlexibleTopMargin;

        objc_setAssociatedObject(
            self,
            &kNLSSlideViewKey,
            slideView,
            OBJC_ASSOCIATION_RETAIN_NONATOMIC
        );

        [self addSubview:slideView];
    }

    /*
     * ------------------------------------------------
     * FULL-SCREEN GESTURE
     * ------------------------------------------------
     *
     * The pan recognizer is on CSMainPageView,
     * NOT on the small bottom slider.
     *
     * Therefore the swipe can start anywhere
     * inside the Lock Screen.
     */

    UIPanGestureRecognizer *pan =
        objc_getAssociatedObject(
            self,
            &kNLSFullScreenPanKey
        );

    if (!pan) {
        NLSFullScreenPanDelegate *delegate =
            [[NLSFullScreenPanDelegate alloc]
                init];

        pan =
            [[UIPanGestureRecognizer alloc]
                initWithTarget:self
                        action:
                    @selector(
                        nls_handleFullScreenSlide:
                    )];

        pan.delegate =
            delegate;

        pan.minimumNumberOfTouches =
            1;

        pan.maximumNumberOfTouches =
            1;

        /*
         * Critical:
         *
         * Do not cancel touches received by
         * notifications / SpringBoard.
         */

        pan.cancelsTouchesInView =
            NO;

        pan.delaysTouchesBegan =
            NO;

        pan.delaysTouchesEnded =
            NO;

        objc_setAssociatedObject(
            self,
            &kNLSFullScreenPanDelegateKey,
            delegate,
            OBJC_ASSOCIATION_RETAIN_NONATOMIC
        );

        objc_setAssociatedObject(
            self,
            &kNLSFullScreenPanKey,
            pan,
            OBJC_ASSOCIATION_RETAIN_NONATOMIC
        );

        [self addGestureRecognizer:pan];
    }

    /*
     * ------------------------------------------------
     * LAYOUT
     * ------------------------------------------------
     */

    CGFloat width =
        CGRectGetWidth(self.bounds);

    CGFloat height =
        CGRectGetHeight(self.bounds);

    CGFloat bottom =
        MAX(
            self.safeAreaInsets.bottom,
            5.0
        );

    slideView.frame =
        CGRectMake(
            0.0,
            MAX(
                height -
                bottom -
                125.0,
                0.0
            ),
            width,
            82.0
        );

    slideView.hidden =
        !NLSLocked;

    if (NLSLocked) {
        [self
            bringSubviewToFront:
                slideView];
    }
}

%new
- (void)nls_handleFullScreenSlide:
    (UIPanGestureRecognizer *)gesture {

    if (!NLSLocked) {
        return;
    }

    NLSSlideToUnlockView *slideView =
        objc_getAssociatedObject(
            self,
            &kNLSSlideViewKey
        );

    if (!slideView ||
        slideView.completing) {

        return;
    }

    CGPoint translation =
        [gesture
            translationInView:self];

    CGFloat screenWidth =
        MAX(
            CGRectGetWidth(
                self.bounds
            ),
            1.0
        );

    /*
     * About 30% of screen width.
     *
     * On your 320pt device this is ~96pt.
     */

    CGFloat requiredDistance =
        MAX(
            screenWidth * 0.30,
            90.0
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

        [slideView
            resetAnimated:NO];

        return;
    }

    if (gesture.state ==
        UIGestureRecognizerStateChanged) {

        [slideView
            setSlideProgress:
                progress];

        return;
    }

    if (gesture.state ==
        UIGestureRecognizerStateEnded) {

        CGFloat verticalDistance =
            fabs(
                translation.y
            );

        /*
         * Require:
         *
         * 1. enough movement towards the right
         * 2. the gesture is reasonably horizontal
         *
         * We intentionally do NOT use velocity
         * as a completion condition.
         */

        BOOL enoughDistance =
            rightDistance >=
            requiredDistance;

        BOOL horizontalEnough =
            rightDistance >=
            verticalDistance * 0.75;

        if (!enoughDistance ||
            !horizontalEnough) {

            [slideView
                resetAnimated:YES];

            return;
        }

        slideView.completing =
            YES;

        [slideView
            setSlideProgress:1.0];

        [UIView
            animateWithDuration:0.14
                          delay:0.0
                        options:
                UIViewAnimationOptionCurveEaseOut |
                UIViewAnimationOptionBeginFromCurrentState
                     animations:^{

            slideView.alpha =
                0.0;

            CGAffineTransform transform =
                CGAffineTransformMakeTranslation(
                    42.0,
                    0.0
                );

            slideView.chevronLabel.transform =
                transform;

            slideView.textLabel.transform =
                transform;

        } completion:^(__unused BOOL finished) {

            /*
             * Ask SpringBoard for its normal
             * unlock flow.
             */

            NLSRequestUnlock();

            /*
             * If a passcode is required or the
             * CoverSheet stays visible, restore
             * the slider.
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
                    if (slideView.window &&
                        NLSLocked) {

                        [slideView
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

        [slideView
            resetAnimated:YES];
    }
}

%end

#pragma mark - Determine Lock Screen vs Notification Center

%hook CSCoverSheetViewController

- (void)viewWillAppear:
    (BOOL)animated {

    %orig(animated);

    BOOL authenticated =
        NO;

    @try {
        authenticated =
            self.authenticated;
    } @catch (__unused NSException *exception) {
        authenticated =
            NO;
    }

    /*
     * Important:
     *
     * We only establish this when CoverSheet
     * appears.
     *
     * We do NOT continuously watch authenticated.
     * Touch ID can authenticate while the Lock
     * Screen itself is still visible.
     */

    NLSLocked =
        !authenticated;
}

%end

#pragma mark - Hide stock CTA

%hook SBUICallToActionLabel

- (void)layoutSubviews {
    %orig;

    if (NLSLocked) {
        self.hidden =
            YES;

        self.alpha =
            0.0;
    } else {
        self.hidden =
            NO;

        self.alpha =
            1.0;
    }
}

%end

#pragma mark - Constructor

%ctor {
    @autoreleasepool {
        NLSLocked =
            YES;
    }
}
