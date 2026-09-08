#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <math.h>

#pragma mark - Private declarations

@interface CSMainPageView : UIView
@end

@interface CSScrollView : UIScrollView
@end

@interface CSCoverSheetViewController : UIViewController
@property(nonatomic, getter=isAuthenticated) BOOL authenticated;
@end

@interface SBUICallToActionLabel : UIView
- (void)setText:(id)text
    forLanguage:(id)language
       animated:(BOOL)animated;
@end

@interface SBLockScreenManager : NSObject
+ (instancetype)sharedInstance;
- (void)lockScreenViewControllerRequestsUnlock;
@end

#pragma mark - State

static BOOL N15Enabled = YES;
static BOOL N15OnLockScreen = YES;

static __weak CSMainPageView *N15CurrentMainPageView = nil;

static const void *N15SlideVisualKey =
    &N15SlideVisualKey;

static const void *N15PanInstalledKey =
    &N15PanInstalledKey;

static const void *N15PanStartOffsetKey =
    &N15PanStartOffsetKey;

static const void *N15PanRequestSentKey =
    &N15PanRequestSentKey;

#pragma mark - Helpers

static void N15SetOnLockScreen(
    BOOL onLockScreen
) {
    N15OnLockScreen =
        onLockScreen;

    CSMainPageView *mainPageView =
        N15CurrentMainPageView;

    if (mainPageView) {
        [mainPageView setNeedsLayout];
    }
}

static void N15RequestUnlock(void) {
    Class managerClass =
        NSClassFromString(
            @"SBLockScreenManager"
        );

    if (!managerClass) {
        return;
    }

    SEL sharedSelector =
        NSSelectorFromString(
            @"sharedInstance"
        );

    if (![managerClass
        respondsToSelector:
            sharedSelector]) {

        return;
    }

    id manager =
        ((id (*)(id, SEL))objc_msgSend)(
            managerClass,
            sharedSelector
        );

    SEL unlockSelector =
        NSSelectorFromString(
            @"lockScreenViewControllerRequestsUnlock"
        );

    if (!manager ||
        ![manager
            respondsToSelector:
                unlockSelector]) {

        return;
    }

    ((void (*)(id, SEL))objc_msgSend)(
        manager,
        unlockSelector
    );
}

#pragma mark - Visual-only Slide to Unlock

@interface N15SlideVisualView : UIView

@property(nonatomic, strong)
UIView *separatorView;

@property(nonatomic, strong)
UILabel *chevronLabel;

@property(nonatomic, strong)
UILabel *textLabel;

@end

@implementation N15SlideVisualView

- (instancetype)initWithFrame:
    (CGRect)frame {

    self =
        [super
            initWithFrame:frame];

    if (!self) {
        return nil;
    }

    /*
     * Important:
     * this entire view is visual only.
     * It never participates in touch handling.
     */
    self.backgroundColor =
        UIColor.clearColor;

    self.userInteractionEnabled =
        NO;

    _separatorView =
        [[UIView alloc]
            initWithFrame:
                CGRectZero];

    _separatorView.backgroundColor =
        [UIColor
            colorWithWhite:1.0
                     alpha:0.18];

    _separatorView.userInteractionEnabled =
        NO;

    [self addSubview:
        _separatorView];

    _chevronLabel =
        [[UILabel alloc]
            initWithFrame:
                CGRectZero];

    _chevronLabel.text =
        @"›";

    _chevronLabel.textAlignment =
        NSTextAlignmentCenter;

    _chevronLabel.textColor =
        [UIColor
            colorWithWhite:1.0
                     alpha:0.88];

    _chevronLabel.font =
        [UIFont
            systemFontOfSize:38.0
                     weight:
                UIFontWeightLight];

    _chevronLabel.userInteractionEnabled =
        NO;

    _chevronLabel.layer.shadowColor =
        UIColor.blackColor.CGColor;

    _chevronLabel.layer.shadowOpacity =
        0.30;

    _chevronLabel.layer.shadowRadius =
        1.5;

    _chevronLabel.layer.shadowOffset =
        CGSizeMake(
            0.0,
            1.0
        );

    [self addSubview:
        _chevronLabel];

    _textLabel =
        [[UILabel alloc]
            initWithFrame:
                CGRectZero];

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
                     weight:
                UIFontWeightLight];

    _textLabel.userInteractionEnabled =
        NO;

    _textLabel.layer.shadowColor =
        UIColor.blackColor.CGColor;

    _textLabel.layer.shadowOpacity =
        0.30;

    _textLabel.layer.shadowRadius =
        1.5;

    _textLabel.layer.shadowOffset =
        CGSizeMake(
            0.0,
            1.0
        );

    [self addSubview:
        _textLabel];

    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat width =
        CGRectGetWidth(
            self.bounds
        );

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
}

@end

#pragma mark - Lock Screen state

%hook CSCoverSheetViewController

- (void)viewWillAppear:
    (BOOL)animated {

    %orig(animated);

    /*
     * This is the same important idea used by
     * NineLS / NineUnlock:
     *
     * decide whether this CoverSheet appearance
     * is the real Lock Screen when it APPEARS.
     *
     * We intentionally do NOT hook
     * setAuthenticated: because Touch ID can
     * authenticate while the Lock Screen remains
     * visually on screen.
     */
    N15SetOnLockScreen(
        !self.authenticated
    );
}

%end

#pragma mark - Slide label

%hook CSMainPageView

- (void)layoutSubviews {
    %orig;

    if (!N15Enabled) {
        return;
    }

    N15CurrentMainPageView =
        self;

    N15SlideVisualView *slideView =
        objc_getAssociatedObject(
            self,
            N15SlideVisualKey
        );

    if (!slideView) {
        slideView =
            [[N15SlideVisualView alloc]
                initWithFrame:
                    CGRectZero];

        slideView.autoresizingMask =
            UIViewAutoresizingFlexibleWidth |
            UIViewAutoresizingFlexibleTopMargin;

        objc_setAssociatedObject(
            self,
            N15SlideVisualKey,
            slideView,
            OBJC_ASSOCIATION_RETAIN_NONATOMIC
        );

        [self addSubview:
            slideView];
    }

    CGFloat width =
        CGRectGetWidth(
            self.bounds
        );

    CGFloat height =
        CGRectGetHeight(
            self.bounds
        );

    CGFloat safeBottom =
        self.safeAreaInsets.bottom;

    CGFloat slideHeight =
        76.0 +
        safeBottom;

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
     * No isUILocked polling here.
     * No authentication polling here.
     *
     * Therefore layoutSubviews cannot randomly
     * make the text appear/disappear.
     */
    slideView.hidden =
        !N15OnLockScreen;

    if (N15OnLockScreen) {
        [self
            bringSubviewToFront:
                slideView];
    }
}

%end

#pragma mark - Native SpringBoard scrolling

%hook CSScrollView

- (void)didMoveToWindow {
    %orig;

    if (!N15Enabled ||
        !self.window) {

        return;
    }

    NSNumber *installed =
        objc_getAssociatedObject(
            self,
            N15PanInstalledKey
        );

    if (installed.boolValue) {
        return;
    }

    /*
     * Crucial difference from the previous builds:
     *
     * DO NOT create another gesture recognizer.
     *
     * We simply add ourselves as another target of
     * SpringBoard's existing UIScrollView pan.
     */
    UIPanGestureRecognizer *pan =
        self.panGestureRecognizer;

    if (!pan) {
        return;
    }

    [pan
        addTarget:self
           action:
            @selector(
                n15_handleNativePan:
            )];

    objc_setAssociatedObject(
        self,
        N15PanInstalledKey,
        @YES,
        OBJC_ASSOCIATION_RETAIN_NONATOMIC
    );
}

%new
- (void)n15_handleNativePan:
    (UIPanGestureRecognizer *)gesture {

    if (!N15Enabled) {
        return;
    }

    UIGestureRecognizerState state =
        gesture.state;

    /*
     * Remember where this specific swipe began.
     *
     * Your iOS 15.8.8 runtime shows:
     *
     * main page:   contentOffset.x = 0
     * second page: approximately screen width
     *
     * This prevents a swipe returning from the
     * second page from accidentally unlocking.
     */
    if (state ==
        UIGestureRecognizerStateBegan) {

        objc_setAssociatedObject(
            self,
            N15PanStartOffsetKey,
            @(self.contentOffset.x),
            OBJC_ASSOCIATION_RETAIN_NONATOMIC
        );

        objc_setAssociatedObject(
            self,
            N15PanRequestSentKey,
            @NO,
            OBJC_ASSOCIATION_RETAIN_NONATOMIC
        );

        return;
    }

    /*
     * We only make the decision once Apple's
     * native pan has actually ended.
     */
    if (state !=
        UIGestureRecognizerStateEnded) {

        return;
    }

    if (!N15OnLockScreen) {
        return;
    }

    NSNumber *requestSent =
        objc_getAssociatedObject(
            self,
            N15PanRequestSentKey
        );

    if (requestSent.boolValue) {
        return;
    }

    NSNumber *startOffsetNumber =
        objc_getAssociatedObject(
            self,
            N15PanStartOffsetKey
        );

    CGFloat startOffsetX =
        startOffsetNumber
        ? startOffsetNumber.doubleValue
        : self.contentOffset.x;

    CGFloat width =
        MAX(
            CGRectGetWidth(
                self.bounds
            ),
            1.0
        );

    /*
     * We only accept a gesture that STARTED from
     * the main Lock Screen page.
     */
    BOOL startedOnMainPage =
        fabs(startOffsetX) <=
        width * 0.20;

    if (!startedOnMainPage) {
        return;
    }

    CGPoint translation =
        [gesture
            translationInView:
                self];

    CGPoint velocity =
        [gesture
            velocityInView:
                self];

    /*
     * Normal slide:
     * around 28% of the screen width.
     *
     * On the 320pt device from your log this is
     * about 90pt.
     */
    CGFloat distanceThreshold =
        MAX(
            width * 0.28,
            80.0
        );

    /*
     * It must be a predominantly horizontal,
     * rightward swipe.
     */
    BOOL horizontalRightSwipe =
        translation.x > 0.0 &&
        fabs(translation.x) >
        fabs(translation.y) *
        1.20;

    BOOL enoughDistance =
        translation.x >=
        distanceThreshold;

    /*
     * Allow a deliberate fast flick without
     * requiring the full distance.
     */
    BOOL quickFlick =
        translation.x >=
        44.0 &&
        velocity.x >=
        700.0;

    if (!horizontalRightSwipe ||
        (!enoughDistance &&
         !quickFlick)) {

        return;
    }

    objc_setAssociatedObject(
        self,
        N15PanRequestSentKey,
        @YES,
        OBJC_ASSOCIATION_RETAIN_NONATOMIC
    );

    /*
     * Do not request unlock from inside the
     * UIScrollView recognizer's own processing.
     *
     * Queue it for the next main-loop turn so
     * SpringBoard finishes handling the swipe first.
     */
    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            N15RequestUnlock();
        }
    );
}

%end

#pragma mark - Hide only Apple's stock CTA text

%hook SBUICallToActionLabel

- (void)setText:
    (id)text
    forLanguage:
    (id)language
    animated:
    (BOOL)animated {

    /*
     * This only removes "Press home to unlock".
     * It does NOT disable the Home Button.
     */
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
