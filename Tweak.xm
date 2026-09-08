#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <objc/message.h>

#pragma mark - Private interfaces

@interface CSCoverSheetViewController : UIViewController
@property(nonatomic, getter=isAuthenticated) BOOL authenticated;
@end

@interface NCNotificationShortLookView : UIView
@end

@interface NCNotificationListCell : UICollectionViewCell
@end

@interface NCNotificationListViewController : UIViewController
@end

@interface NCNotificationCombinedListViewController : UIViewController
@end

@interface NCNotificationStructuredListViewController : UIViewController
@end

@interface CSCombinedListViewController : UIViewController
@end

@interface NCNotificationRootList : NSObject
@end

#pragma mark - Globals

static NSString * const N15LogDirectory =
    @"/var/mobile/Library/Logs";

static NSString * const N15LogPath =
    @"/var/mobile/Library/Logs/Nine15-diagnostic.txt";

static NSTimeInterval N15LastNotificationDump = 0.0;
static NSTimeInterval N15LastCoverSheetDump = 0.0;

#pragma mark - Logging

static NSString *N15Timestamp(void) {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss.SSS";

    return [formatter stringFromDate:[NSDate date]];
}

static void N15EnsureLogDirectory(void) {
    NSFileManager *manager = [NSFileManager defaultManager];

    BOOL isDirectory = NO;

    if ([manager fileExistsAtPath:N15LogDirectory
                      isDirectory:&isDirectory] &&
        isDirectory) {
        return;
    }

    NSError *error = nil;

    [manager createDirectoryAtPath:N15LogDirectory
       withIntermediateDirectories:YES
                        attributes:nil
                             error:&error];
}

static void N15WriteLog(NSString *message) {
    if (message.length == 0) {
        return;
    }

    N15EnsureLogDirectory();

    NSString *line = [NSString stringWithFormat:
        @"[%@] %@\n",
        N15Timestamp(),
        message
    ];

    NSData *data = [line dataUsingEncoding:NSUTF8StringEncoding];

    NSFileManager *manager = [NSFileManager defaultManager];

    if (![manager fileExistsAtPath:N15LogPath]) {
        [data writeToFile:N15LogPath atomically:YES];
        return;
    }

    NSFileHandle *handle =
        [NSFileHandle fileHandleForWritingAtPath:N15LogPath];

    if (!handle) {
        return;
    }

    @try {
        [handle seekToEndOfFile];
        [handle writeData:data];
        [handle closeFile];
    } @catch (__unused NSException *exception) {
    }
}

#pragma mark - Formatting

static NSString *N15RectString(CGRect rect) {
    return [NSString stringWithFormat:
        @"{x=%.1f y=%.1f w=%.1f h=%.1f}",
        rect.origin.x,
        rect.origin.y,
        rect.size.width,
        rect.size.height
    ];
}

static NSString *N15InsetsString(UIEdgeInsets insets) {
    return [NSString stringWithFormat:
        @"{top=%.1f left=%.1f bottom=%.1f right=%.1f}",
        insets.top,
        insets.left,
        insets.bottom,
        insets.right
    ];
}

static NSString *N15ColorDescription(UIColor *color) {
    if (!color) {
        return @"nil";
    }

    CGFloat red = 0;
    CGFloat green = 0;
    CGFloat blue = 0;
    CGFloat alpha = 0;

    if ([color getRed:&red
                green:&green
                 blue:&blue
                alpha:&alpha]) {

        return [NSString stringWithFormat:
            @"rgba(%.2f %.2f %.2f %.2f)",
            red,
            green,
            blue,
            alpha
        ];
    }

    CGFloat white = 0;

    if ([color getWhite:&white alpha:&alpha]) {
        return [NSString stringWithFormat:
            @"white(%.2f %.2f)",
            white,
            alpha
        ];
    }

    return color.description ?: @"unknown";
}

#pragma mark - Runtime inspection

static NSString *N15ViewDescription(UIView *view) {
    if (!view) {
        return @"<nil>";
    }

    NSMutableString *description =
        [NSMutableString string];

    [description appendFormat:
        @"%@ frame=%@ bounds=%@ alpha=%.2f hidden=%d "
         "cornerRadius=%.2f masks=%d clips=%d bg=%@",
        NSStringFromClass(view.class),
        N15RectString(view.frame),
        N15RectString(view.bounds),
        view.alpha,
        view.hidden,
        view.layer.cornerRadius,
        view.layer.masksToBounds,
        view.clipsToBounds,
        N15ColorDescription(view.backgroundColor)
    ];

    if ([view isKindOfClass:UIScrollView.class]) {
        UIScrollView *scrollView = (UIScrollView *)view;

        [description appendFormat:
            @" contentSize={%.1f %.1f}"
             " contentOffset={%.1f %.1f}"
             " contentInset=%@"
             " adjustedInset=%@",
            scrollView.contentSize.width,
            scrollView.contentSize.height,
            scrollView.contentOffset.x,
            scrollView.contentOffset.y,
            N15InsetsString(scrollView.contentInset),
            N15InsetsString(scrollView.adjustedContentInset)
        ];
    }

    return description;
}

static void N15DumpSuperviewChain(UIView *view) {
    if (!view) {
        return;
    }

    N15WriteLog(@"----- SUPERVIEW CHAIN -----");

    UIView *current = view;
    NSInteger level = 0;

    while (current && level < 20) {
        NSString *indent =
            [@"" stringByPaddingToLength:(NSUInteger)(level * 2)
                              withString:@" "
                         startingAtIndex:0];

        N15WriteLog(
            [NSString stringWithFormat:
                @"%@%@",
                indent,
                N15ViewDescription(current)
            ]
        );

        current = current.superview;
        level++;
    }

    N15WriteLog(@"----- END SUPERVIEW CHAIN -----");
}

static void N15DumpViewTreeRecursive(
    UIView *view,
    NSInteger depth,
    NSInteger maxDepth
) {
    if (!view || depth > maxDepth) {
        return;
    }

    NSString *indent =
        [@"" stringByPaddingToLength:(NSUInteger)(depth * 2)
                          withString:@" "
                     startingAtIndex:0];

    N15WriteLog(
        [NSString stringWithFormat:
            @"%@%@",
            indent,
            N15ViewDescription(view)
        ]
    );

    for (UIView *subview in view.subviews) {
        N15DumpViewTreeRecursive(
            subview,
            depth + 1,
            maxDepth
        );
    }
}

static void N15DumpViewTree(
    UIView *view,
    NSString *reason,
    NSInteger maxDepth
) {
    if (!view) {
        return;
    }

    N15WriteLog(
        [NSString stringWithFormat:
            @"===== VIEW TREE: %@ =====",
            reason ?: @"unknown"
        ]
    );

    N15DumpViewTreeRecursive(view, 0, maxDepth);

    N15WriteLog(@"===== END VIEW TREE =====");
}

static void N15DumpIvars(id object) {
    if (!object) {
        return;
    }

    N15WriteLog(
        [NSString stringWithFormat:
            @"----- IVARS %@ -----",
            NSStringFromClass([object class])
        ]
    );

    Class currentClass = [object class];

    NSInteger classDepth = 0;

    while (currentClass &&
           currentClass != [NSObject class] &&
           classDepth < 8) {

        unsigned int count = 0;

        Ivar *ivars =
            class_copyIvarList(currentClass, &count);

        N15WriteLog(
            [NSString stringWithFormat:
                @"Class %@ (%u ivars)",
                NSStringFromClass(currentClass),
                count
            ]
        );

        for (unsigned int index = 0;
             index < count;
             index++) {

            Ivar ivar = ivars[index];

            const char *name = ivar_getName(ivar);
            const char *type = ivar_getTypeEncoding(ivar);

            if (!name) {
                continue;
            }

            NSString *ivarName =
                [NSString stringWithUTF8String:name];

            NSString *typeName =
                type
                ? [NSString stringWithUTF8String:type]
                : @"?";

            NSString *valueDescription = @"";

            if (type && type[0] == '@') {
                id value = nil;

                @try {
                    value = object_getIvar(object, ivar);
                } @catch (__unused NSException *exception) {
                    value = nil;
                }

                if (value) {
                    valueDescription =
                        [NSString stringWithFormat:
                            @" -> %@",
                            NSStringFromClass([value class])
                        ];
                }
            }

            N15WriteLog(
                [NSString stringWithFormat:
                    @"  %@@%@%@",
                    ivarName,
                    typeName,
                    valueDescription
                ]
            );
        }

        if (ivars) {
            free(ivars);
        }

        currentClass =
            class_getSuperclass(currentClass);

        classDepth++;
    }

    N15WriteLog(@"----- END IVARS -----");
}

#pragma mark - Notification inspection

static void N15DumpNotificationView(
    NCNotificationShortLookView *view
) {
    if (!view) {
        return;
    }

    NSTimeInterval now =
        [NSDate date].timeIntervalSince1970;

    if (now - N15LastNotificationDump < 2.0) {
        return;
    }

    N15LastNotificationDump = now;

    N15WriteLog(@"");
    N15WriteLog(@"########################################");
    N15WriteLog(@"### NOTIFICATION SHORT LOOK DETECTED ###");
    N15WriteLog(@"########################################");

    N15WriteLog(
        [NSString stringWithFormat:
            @"ShortLook: %@",
            N15ViewDescription(view)
        ]
    );

    N15DumpSuperviewChain(view);
    N15DumpViewTree(view, @"Notification ShortLook", 6);
    N15DumpIvars(view);

    UIView *window = view.window;

    if (window) {
        N15DumpViewTree(
            window,
            @"Notification Window",
            7
        );
    }
}

#pragma mark - CoverSheet inspection

static void N15DumpCoverSheet(
    CSCoverSheetViewController *controller,
    NSString *reason
) {
    if (!controller || !controller.view) {
        return;
    }

    NSTimeInterval now =
        [NSDate date].timeIntervalSince1970;

    if (now - N15LastCoverSheetDump < 1.5) {
        return;
    }

    N15LastCoverSheetDump = now;

    BOOL authenticated = NO;

    @try {
        authenticated = controller.isAuthenticated;
    } @catch (__unused NSException *exception) {
    }

    N15WriteLog(@"");
    N15WriteLog(@"################################");
    N15WriteLog(@"### COVERSHEET STATE CHANGE ###");
    N15WriteLog(@"################################");

    N15WriteLog(
        [NSString stringWithFormat:
            @"reason=%@ authenticated=%d controller=%@",
            reason ?: @"unknown",
            authenticated,
            NSStringFromClass(controller.class)
        ]
    );

    N15DumpIvars(controller);

    N15DumpViewTree(
        controller.view,
        @"CoverSheet",
        8
    );
}

#pragma mark - Hooks

%hook NCNotificationShortLookView

- (void)didMoveToWindow {
    %orig;

    if (self.window) {
        dispatch_after(
            dispatch_time(
                DISPATCH_TIME_NOW,
                (int64_t)(0.4 * NSEC_PER_SEC)
            ),
            dispatch_get_main_queue(),
            ^{
                N15DumpNotificationView(self);
            }
        );
    }
}

- (void)layoutSubviews {
    %orig;

    if (self.window) {
        N15DumpNotificationView(self);
    }
}

%end

%hook NCNotificationListCell

- (void)didMoveToWindow {
    %orig;

    if (!self.window) {
        return;
    }

    N15WriteLog(
        [NSString stringWithFormat:
            @"NotificationListCell window: %@",
            N15ViewDescription(self)
        ]
    );
}

%end

%hook CSCoverSheetViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;

    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW,
            (int64_t)(0.5 * NSEC_PER_SEC)
        ),
        dispatch_get_main_queue(),
        ^{
            N15DumpCoverSheet(
                self,
                @"viewDidAppear"
            );
        }
    );
}

- (void)viewDidLayoutSubviews {
    %orig;

    N15DumpCoverSheet(
        self,
        @"viewDidLayoutSubviews"
    );
}

- (void)setAuthenticated:(BOOL)authenticated {
    %orig(authenticated);

    N15WriteLog(
        [NSString stringWithFormat:
            @"CSCoverSheetViewController "
             @"setAuthenticated:%d",
            authenticated
        ]
    );

    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW,
            (int64_t)(0.3 * NSEC_PER_SEC)
        ),
        dispatch_get_main_queue(),
        ^{
            N15DumpCoverSheet(
                self,
                @"setAuthenticated"
            );
        }
    );
}

%end

%hook NCNotificationCombinedListViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;

    N15WriteLog(
        [NSString stringWithFormat:
            @"NCNotificationCombinedListViewController "
             @"viewDidAppear frame=%@",
            N15RectString(self.view.frame)
        ]
    );

    N15DumpIvars(self);

    N15DumpViewTree(
        self.view,
        @"Combined Notification List",
        7
    );
}

- (void)viewDidLayoutSubviews {
    %orig;

    N15WriteLog(
        [NSString stringWithFormat:
            @"CombinedList layout frame=%@",
            N15RectString(self.view.frame)
        ]
    );
}

%end

%hook NCNotificationStructuredListViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;

    N15WriteLog(
        [NSString stringWithFormat:
            @"NCNotificationStructuredListViewController "
             @"viewDidAppear frame=%@",
            N15RectString(self.view.frame)
        ]
    );

    N15DumpIvars(self);

    N15DumpViewTree(
        self.view,
        @"Structured Notification List",
        7
    );
}

- (void)revealNotificationHistory:
    (BOOL)revealed
    animated:(BOOL)animated {

    N15WriteLog(
        [NSString stringWithFormat:
            @"StructuredList "
             @"revealNotificationHistory:%d "
             @"animated:%d",
            revealed,
            animated
        ]
    );

    %orig(revealed, animated);
}

%end

%hook CSCombinedListViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;

    N15WriteLog(
        [NSString stringWithFormat:
            @"CSCombinedListViewController "
             @"viewDidAppear frame=%@",
            N15RectString(self.view.frame)
        ]
    );

    N15DumpIvars(self);

    N15DumpViewTree(
        self.view,
        @"CSCombinedList",
        7
    );
}

- (void)viewDidLayoutSubviews {
    %orig;

    N15WriteLog(
        [NSString stringWithFormat:
            @"CSCombinedList layout frame=%@",
            N15RectString(self.view.frame)
        ]
    );
}

%end

%hook NCNotificationRootList

- (void)setNotificationHistoryRevealed:
    (BOOL)revealed {

    N15WriteLog(
        [NSString stringWithFormat:
            @"NCNotificationRootList "
             @"setNotificationHistoryRevealed:%d",
            revealed
        ]
    );

    %orig(revealed);
}

- (void)revealNotificationHistory:
    (BOOL)revealed
    animated:(BOOL)animated {

    N15WriteLog(
        [NSString stringWithFormat:
            @"NCNotificationRootList "
             @"revealNotificationHistory:%d "
             @"animated:%d",
            revealed,
            animated
        ]
    );

    %orig(revealed, animated);
}

%end

#pragma mark - Constructor

%ctor {
    @autoreleasepool {
        N15EnsureLogDirectory();

        NSFileManager *manager =
            [NSFileManager defaultManager];

        if ([manager fileExistsAtPath:N15LogPath]) {
            NSError *error = nil;

            [manager removeItemAtPath:N15LogPath
                               error:&error];
        }

        N15WriteLog(
            @"Nine15 Diagnostic started"
        );

        N15WriteLog(
            [NSString stringWithFormat:
                @"iOS %@",
                UIDevice.currentDevice.systemVersion
            ]
        );

        N15WriteLog(
            [NSString stringWithFormat:
                @"Device %@",
                UIDevice.currentDevice.model
            ]
        );
    }
}
