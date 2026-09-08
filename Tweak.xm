#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <math.h>

#pragma mark - Private declarations

@interface CSCoverSheetViewController : UIViewController
@property(nonatomic, getter=isAuthenticated) BOOL authenticated;
@end

@interface SBLockScreenManager : NSObject
@end

@interface SBUICallToActionLabel : UIView
- (void)setText:(id)text
    forLanguage:(id)language
       animated:(BOOL)animated;
@end

#pragma mark - State

static BOOL N15Enabled = YES;
static BOOL N15OnLockScreen = NO;

@class N15SlideToUnlockView;

static __weak N15SlideToUnlockView *N15CurrentSlideView = nil;

static const void *N15SlideViewKey =
    &N15SlideViewKey;

#pragma mark - SpringBoard helpers

static id N15LockScreenManager(void) {
    Class managerClass =
        NSClassFromString(@"SBLockScreenManager");

    if (!managerClass) {
        return nil;
    }

    SEL sharedSelector =
        NSSelectorFromString(@"sharedInstance");

    if (![managerClass respondsToSelector:sharedSelector]) {
        return nil;
    }

    return ((id (*)(id, SEL))objc_msgSend)(
        managerClass,
        sharedSelector
    );
}

static BOOL N15SystemUILocked(BOOL fallback) {
    id manager =
        N15LockScreenManager();

    if (!manager) {
        return fallback;
    }

    SEL selector =
        NSSelectorFromString(@"isUILocked");

    if (![manager respondsToSelector:selector]) {
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

    if (![manager respondsToSelector:selector]) {
        return;
    }

    ((void (*)(id, SEL))objc_msgSend)(
        manager,
        selector
    );
}

static void N15SetOnLockScreen(
    BOOL onLockScreen
);

#pragma mark - Slide to unlock view

@interface N15SlideToUnlockView :
    UIView <UIGestureRecognizerDelegate>

@property(nonatomic, strong)
UIView *separatorView;

@property(nonatomic, strong)
UILabel *chevronLabel;

@property(nonatomic, strong)
UILabel *textLabel;

@property(nonatomic, strong)
UIPanGestureRecognizer *panGesture;

@property(nonatomic, assign)
CGFloat progress;

@property(nonatomic, assign)
BOOL completing;

- (void)installGesturePriority;
- (void)resetAnimated:(BOOL)animated;

@end

@implementation N15SlideToUnlockView

- (instancetype)initWithFrame:(CGRect)frame {
    self =
        [super initWithFrame:frame];

    if (!self) {
        return nil;
    }

    self.backgroundColor =
        UIColor.clearColor;

    self.userInteractionEnabled =
        YES;

    self.clipsToBounds =
        NO;

    _separatorView =
        [[UIView alloc]
            initWithFrame:CGRectZero];

    _separatorView.backgroundColor =
        [UIColor
            colorWithWhite:1.0
                     alpha:0.20];

    _separatorView.userInteractionEnabled =
        NO;

    [self addSubview:_separatorView];

    _chevronLabel =
        [[UILabel alloc]
            initWithFrame:CGRectZero];

    _chevronLabel.text =
        @"›";

    _chevronLabel.textAlignment =
        NSTextAlignmentCenter;

    _chevronLabel.textColor =
        [UIColor
            colorWithWhite:1.0
                     alpha:0.92];

    _chevronLabel.font =
        [UIFont
            systemFontOfSize:40.0
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

    _textLabel =
        [[UILabel alloc]
            initWithFrame:CGRectZero];

    _textLabel.text =
        @"slide to unlock";

    _textLabel.textAlignment =
        NSTextAlignmentCenter;

    _textLabel.textColor =
        [UIColor
            colorWithWhite:1.0
                     alpha:0.90];

    _textLabel.font =
        [UIFont
            systemFontOfSize:21.0
                     weight:UIFontWeightLight];

    _textLabel.userInteractionEnabled =
        NO;

    _textLabel.layer.shadowColor =
        UIColor.blackColor.CGColor;

    _textLabel.layer.shadowOpacity =
        0.35;

    _textLabel.layer.shadowRadius =
        1.5;

    _textLabel.layer.shadowOffset =
        CGSizeMake(0.0, 1.0);

    [self addSubview:_textLabel];

    _panGesture =
        [[UIPanGestureRecognizer alloc]
            initWithTarget:self
                    action:@selector(handlePan:)];

    _panGesture.delegate =
        self;

    _panGesture.minimumNumberOfTouches =
        1;

    _panGesture.maximumNumberOfTouches =
        1;

    _panGesture.cancelsTouchesInView =
        YES;

    [self addGestureRecognizer:_panGesture];

    return self;
}

- (void)installGesturePriority {
    /*
     The slider is a direct child of the CoverSheet root.

     Native lock-screen scroll views are underneath it,
     so they don't receive touches that start here.

     Gesture recognizers installed on parent/ancestor
     views can still see the touch. Make those pan
     recognizers wait for our slider.
     */

    UIView *ancestor =
        self.superview;

    while (ancestor) {
        for (UIGestureRecognizer *recognizer
             in ancestor.gestureRecognizers) {

            if (recognizer ==
                    self.panGesture ||
                ![recognizer
                    isKindOfClass:
                        UIPanGestureRecognizer.class]) {

                continue;
            }

            [recognizer
                requireGestureRecognizerToFail:
                    self.panGesture];
        }

        ancestor =
            ancestor.superview;
    }
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

    self.separatorView.frame =
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

    self.textLabel.frame =
        CGRectMake(
            54.0,
            2.0,
            MAX(
                width - 108.0,
                0.0
            ),
            70.0
        );

    [self applyProgress];
}

- (BOOL)gestureRecognizerShouldBegin:
    (UIGestureRecognizer *)gestureRecognizer {

    if (gestureRecognizer !=
            self.panGesture ||
        !N15Enabled ||
        !N15OnLockScreen ||
        self.completing) {

        return NO;
    }

    CGPoint velocity =
        [self.panGesture
            velocityInView:self];

    /*
     Only take a deliberate horizontal swipe
     towards the right.
     */

    return
        velocity.x > 0.0 &&
        fabs(velocity.x) >
            fabs(velocity.y) * 1.10;
}

- (void)handlePan:
    (UIPanGestureRecognizer *)gesture {

    if (!N15OnLockScreen ||
        self.completing) {

        return;
    }

    CGFloat availableDistance =
        MAX(
            CGRectGetWidth(self.bounds) -
                82.0,
            1.0
        );

    CGPoint translation =
        [gesture
            translationInView:self];

    if (gesture.state ==
        UIGestureRecognizerStateBegan) {

        self.progress =
            0.0;

        self.textLabel.alpha =
            1.0;

        [self applyProgress];

        return;
    }

    if (gesture.state ==
        UIGestureRecognizerStateChanged) {

        self.progress =
            MIN(
                MAX(
                    translation.x /
                        availableDistance,
                    0.0
                ),
                1.0
            );

        [self applyProgress];

        return;
    }

    if (gesture.state ==
        UIGestureRecognizerStateEnded) {

        CGFloat velocityX =
            [gesture
                velocityInView:self].x;

        /*
         Normal completion:
         68% of the available distance.

         A fast deliberate flick is accepted after
         about one third of the track.
         */

        BOOL completed =
            self.progress >= 0.68 ||
            (
                self.progress >= 0.32 &&
                velocityX >= 850.0
            );

        if (completed) {
            [self completeSlide];
        } else {
            [self resetAnimated:YES];
        }

        return;
    }

    if (gesture.state ==
            UIGestureRecognizerStateCancelled ||
        gesture.state ==
            UIGestureRecognizerStateFailed) {

        [self resetAnimated:YES];
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

        self.textLabel.alpha =
            0.0;

    } completion:^(__unused BOOL finished) {

        /*
         This is the ONLY unlock-related action.

         It asks SpringBoard to perform its normal
         unlock flow.

         It does not:
         - bypass a passcode
         - disable Touch ID
         - disable Home
         - intercept unlockUIFromSource:
         */

        N15RequestUnlock();

        /*
         Prepare it again behind any passcode UI.

         If passcode entry appears, that UI was
         presented afterwards and remains above this
         slider. If passcode entry is cancelled, the
         slider is already usable again.
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
                if (N15OnLockScreen &&
                    self.window) {

                    [self
                        resetAnimated:NO];
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

    void (^changes)(void) =
        ^{
            self.chevronLabel.transform =
                CGAffineTransformIdentity;

            self.textLabel.alpha =
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
    CGFloat availableDistance =
        MAX(
            CGRectGetWidth(self.bounds) -
                82.0,
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
        self.textLabel.alpha =
            MAX(
                1.0 -
                    self.progress * 0.72,
                0.18
            );
    }
}

@end

#pragma mark - State update

static void N15SetOnLockScreen(
    BOOL onLockScreen
) {
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

            slideView.hidden =
                !onLockScreen;

            slideView.userInteractionEnabled =
                onLockScreen;

            if (onLockScreen) {
                [slideView
                    resetAnimated:NO];
            }
        }
    );
}

#pragma mark - CoverSheet

%hook CSCoverSheetViewController

- (void)viewDidAppear:
    (BOOL)animated {

    %orig(animated);

    if (!N15Enabled) {
        return;
    }

    /*
     Check the UI-lock state only when CoverSheet
     appears.

     Do NOT query this from layoutSubviews. Repeated
     polling during authentication/transitions was
     one of the previous bugs.
     */

    BOOL fallback =
        !self.authenticated;

    N15SetOnLockScreen(
        N15SystemUILocked(
            fallback
        )
    );

    N15SlideToUnlockView *slideView =
        objc_getAssociatedObject(
            self,
            N15SlideViewKey
        );

    if (!slideView) {
        slideView =
            [[N15SlideToUnlockView alloc]
                initWithFrame:CGRectZero];

        objc_setAssociatedObject(
            self,
            N15SlideViewKey,
            slideView,
            OBJC_ASSOCIATION_RETAIN_NONATOMIC
        );
    }

    /*
     Put the slider directly on the CoverSheet root,
     not inside CSMainPageView / CSScrollView.
     */

    if (slideView.superview !=
        self.view) {

        [slideView
            removeFromSuperview];

        [self.view
            addSubview:slideView];
    }

    N15CurrentSlideView =
        slideView;

    CGFloat width =
        CGRectGetWidth(
            self.view.bounds
        );

    CGFloat height =
        CGRectGetHeight(
            self.view.bounds
        );

    CGFloat safeBottom =
        self.view.safeAreaInsets.bottom;

    CGFloat sliderHeight =
        78.0 +
        safeBottom;

    slideView.frame =
        CGRectMake(
            0.0,
            MAX(
                height -
                    sliderHeight,
                0.0
            ),
            width,
            sliderHeight
        );

    slideView.hidden =
        !N15OnLockScreen;

    slideView.userInteractionEnabled =
        N15OnLockScreen;

    if (N15OnLockScreen) {
        /*
         Put it above the normal Lock Screen once.
         Do not continuously force it above future
         passcode UI.
         */

        [self.view
            bringSubviewToFront:
                slideView];

        [slideView
            resetAnimated:NO];

        [slideView
            installGesturePriority];
    }

    [self.view
        setNeedsLayout];
}

- (void)viewDidLayoutSubviews {
    %orig;

    if (!N15Enabled) {
        return;
    }

    N15SlideToUnlockView *slideView =
        objc_getAssociatedObject(
            self,
            N15SlideViewKey
        );

    if (!slideView) {
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

    CGFloat safeBottom =
        self.view.safeAreaInsets.bottom;

    CGFloat sliderHeight =
        78.0 +
        safeBottom;

    slideView.frame =
        CGRectMake(
            0.0,
            MAX(
                height -
                    sliderHeight,
                0.0
            ),
            width,
            sliderHeight
        );

    slideView.hidden =
        !N15OnLockScreen;

    slideView.userInteractionEnabled =
        N15OnLockScreen;

    /*
     Deliberately no bringSubviewToFront here.

     If SpringBoard presents a passcode screen after
     the slide, that UI must remain above the slider.
     */
}

%end

#pragma mark - Observe Apple's normal lock/unlock

%hook SBLockScreenManager

- (void)lockUIFromSource:
    (int)source
            withOptions:
    (id)options {

    /*
     Observe only.
     Never prevent or replace Apple's lock method.
     */

    %orig(
        source,
        options
    );

    if (N15Enabled) {
        N15SetOnLockScreen(
            YES
        );
    }
}

- (BOOL)_finishUIUnlockFromSource:
    (int)source
                      withOptions:
    (id)options {

    /*
     Apple performs the real unlock first.
     We only update our UI state afterwards.
     */

    BOOL result =
        %orig(
            source,
            options
        );

    if (N15Enabled &&
        result) {

        N15SetOnLockScreen(
            NO
        );
    }

    return result;
}

%end

#pragma mark - Hide stock "Press home to unlock"

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
            UIDevice.currentDevice
                .systemVersion;

        BOOL isIOS15OrNewer =
            [version
                compare:@"15.0"
                options:
                    NSNumericSearch] !=
            NSOrderedAscending;

        BOOL isBeforeIOS16 =
            [version
                compare:@"16.0"
                options:
                    NSNumericSearch] ==
            NSOrderedAscending;

        N15Enabled =
            isIOS15OrNewer &&
            isBeforeIOS16;
    }
}
