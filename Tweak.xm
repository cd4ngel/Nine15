#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>

#pragma mark - Private classes

@interface CSMainPageView : UIView
@end

@interface SBLockScreenManager : NSObject
@end

#pragma mark - Globals

static BOOL N15Enabled = YES;

static const void *N15SlideViewKey = &N15SlideViewKey;

#pragma mark - SpringBoard helpers

static id N15LockScreenManager(void) {
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

static BOOL N15IsUILocked(void) {
    id manager = N15LockScreenManager();

    if (!manager) {
        return YES;
    }

    SEL selector =
        NSSelectorFromString(@"isUILocked");

    if (![manager respondsToSelector:selector]) {
        return YES;
    }

    return ((BOOL (*)(id, SEL))objc_msgSend)(
        manager,
        selector
    );
}

static void N15RequestUnlock(void) {
    id manager = N15LockScreenManager();

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

#pragma mark - Slide to unlock

@interface N15SlideToUnlockView : UIView

@property(nonatomic, strong) UILabel *arrowLabel;
@property(nonatomic, strong) UILabel *textLabel;
@property(nonatomic, strong) UIView *topLine;
@property(nonatomic, strong) UIPanGestureRecognizer *panGesture;

@property(nonatomic, assign) CGFloat progress;
@property(nonatomic, assign) BOOL completing;

- (void)resetAnimated:(BOOL)animated;

@end

@implementation N15SlideToUnlockView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];

    if (!self) {
        return nil;
    }

    self.backgroundColor = UIColor.clearColor;
    self.userInteractionEnabled = YES;

    _topLine = [[UIView alloc] init];
    _topLine.backgroundColor =
        [UIColor colorWithWhite:1.0 alpha:0.18];

    [self addSubview:_topLine];

    _arrowLabel = [[UILabel alloc] init];

    _arrowLabel.text = @"›";
    _arrowLabel.textAlignment = NSTextAlignmentCenter;
    _arrowLabel.textColor =
        [UIColor colorWithWhite:1.0 alpha:0.92];

    _arrowLabel.font =
        [UIFont systemFontOfSize:40.0
                         weight:UIFontWeightLight];

    _arrowLabel.userInteractionEnabled = NO;

    _arrowLabel.layer.shadowColor =
        UIColor.blackColor.CGColor;

    _arrowLabel.layer.shadowOpacity = 0.35;
    _arrowLabel.layer.shadowRadius = 2.0;
    _arrowLabel.layer.shadowOffset =
        CGSizeMake(0.0, 1.0);

    [self addSubview:_arrowLabel];

    _textLabel = [[UILabel alloc] init];

    _textLabel.text = @"slide to unlock";
    _textLabel.textAlignment = NSTextAlignmentCenter;

    _textLabel.textColor =
        [UIColor colorWithWhite:1.0 alpha:0.88];

    _textLabel.font =
        [UIFont systemFontOfSize:21.0
                         weight:UIFontWeightLight];

    _textLabel.userInteractionEnabled = NO;

    _textLabel.layer.shadowColor =
        UIColor.blackColor.CGColor;

    _textLabel.layer.shadowOpacity = 0.30;
    _textLabel.layer.shadowRadius = 2.0;
    _textLabel.layer.shadowOffset =
        CGSizeMake(0.0, 1.0);

    [self addSubview:_textLabel];

    _panGesture =
        [[UIPanGestureRecognizer alloc]
            initWithTarget:self
                    action:@selector(handlePan:)];

    _panGesture.minimumNumberOfTouches = 1;
    _panGesture.maximumNumberOfTouches = 1;

    [self addGestureRecognizer:_panGesture];

    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat width =
        CGRectGetWidth(self.bounds);

    CGFloat height =
        CGRectGetHeight(self.bounds);

    CGFloat scale =
        UIScreen.mainScreen.scale;

    CGFloat onePixel =
        scale > 0.0 ? 1.0 / scale : 0.5;

    self.topLine.frame =
        CGRectMake(
            0.0,
            0.0,
            width,
            onePixel
        );

    CGFloat contentHeight =
        MIN(height, 74.0);

    self.arrowLabel.frame =
        CGRectMake(
            14.0,
            2.0,
            48.0,
            contentHeight - 4.0
        );

    self.textLabel.frame =
        CGRectMake(
            54.0,
            2.0,
            MAX(width - 108.0, 0.0),
            contentHeight - 4.0
        );

    [self applyProgressAnimated:NO];
}

- (void)handlePan:
    (UIPanGestureRecognizer *)gesture {

    if (self.completing ||
        !N15IsUILocked()) {

        return;
    }

    CGPoint translation =
        [gesture translationInView:self];

    CGFloat availableDistance =
        MAX(
            CGRectGetWidth(self.bounds) - 82.0,
            1.0
        );

    if (gesture.state ==
        UIGestureRecognizerStateBegan) {

        self.progress = 0.0;

        [gesture
            setTranslation:CGPointZero
                    inView:self];

        return;
    }

    if (gesture.state ==
        UIGestureRecognizerStateChanged) {

        CGFloat x =
            MAX(translation.x, 0.0);

        self.progress =
            MIN(
                x / availableDistance,
                1.0
            );

        [self applyProgressAnimated:NO];

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
                velocity >= 850.0
            );

        if (completed) {
            [self completeUnlock];
        } else {
            [self resetAnimated:YES];
        }
    }
}

- (void)completeUnlock {
    if (self.completing) {
        return;
    }

    self.completing = YES;
    self.progress = 1.0;

    [UIView
        animateWithDuration:0.16
                      delay:0.0
                    options:
            UIViewAnimationOptionCurveEaseOut |
            UIViewAnimationOptionBeginFromCurrentState
                 animations:^{

        [self applyProgressAnimated:NO];

        self.textLabel.alpha = 0.0;

    } completion:^(__unused BOOL finished) {

        N15RequestUnlock();

        dispatch_after(
            dispatch_time(
                DISPATCH_TIME_NOW,
                (int64_t)(0.65 * NSEC_PER_SEC)
            ),
            dispatch_get_main_queue(),
            ^{
                if (!N15IsUILocked()) {
                    self.hidden = YES;
                    return;
                }

                self.completing = NO;

                [self resetAnimated:YES];
            }
        );
    }];
}

- (void)resetAnimated:(BOOL)animated {
    self.completing = NO;
    self.progress = 0.0;

    void (^changes)(void) = ^{
        self.textLabel.alpha = 1.0;

        [self applyProgressAnimated:NO];
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
                 animations:changes
                 completion:nil];
}

- (void)applyProgressAnimated:
    (__unused BOOL)animated {

    CGFloat width =
        CGRectGetWidth(self.bounds);

    CGFloat availableDistance =
        MAX(width - 82.0, 1.0);

    CGFloat translation =
        availableDistance *
        self.progress;

    self.arrowLabel.transform =
        CGAffineTransformMakeTranslation(
            translation,
            0.0
        );

    if (!self.completing) {
        self.textLabel.alpha =
            1.0 -
            (self.progress * 0.72);
    }
}

@end

#pragma mark - Associated object

static N15SlideToUnlockView *
N15GetSlideView(
    CSMainPageView *view
) {
    if (!view) {
        return nil;
    }

    return objc_getAssociatedObject(
        view,
        N15SlideViewKey
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
        N15SlideViewKey,
        slideView,
        OBJC_ASSOCIATION_RETAIN_NONATOMIC
    );
}

#pragma mark - Lock Screen

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

    CGFloat width =
        CGRectGetWidth(self.bounds);

    CGFloat height =
        CGRectGetHeight(self.bounds);

    CGFloat safeBottom =
        self.safeAreaInsets.bottom;

    CGFloat sliderHeight =
        78.0 + safeBottom;

    slideView.frame =
        CGRectMake(
            0.0,
            MAX(
                height - sliderHeight,
                0.0
            ),
            width,
            sliderHeight
        );

    BOOL locked =
        N15IsUILocked();

    slideView.hidden =
        !locked;

    if (locked) {
        [self
            bringSubviewToFront:
                slideView];
    }
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
                options:NSNumericSearch] !=
            NSOrderedAscending;

        BOOL isBeforeIOS16 =
            [version
                compare:@"16.0"
                options:NSNumericSearch] ==
            NSOrderedAscending;

        N15Enabled =
            isIOS15OrNewer &&
            isBeforeIOS16;
    }
}
