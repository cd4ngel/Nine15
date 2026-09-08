# Nine15

Nine15 is an iOS 9-inspired Lock Screen / Notification Center tweak for
**iOS 15.x rootless jailbreaks**, focused on Dopamine + ElleKit.

## Included

- iOS 9-style large clock and date.
- Shimmering `slide to unlock` footer.
- Right-swipe unlock request that keeps the normal iOS authentication flow.
- Hides the modern Lock Screen date/footer/teachable UI and quick actions.
- Flat notification/banners with square corners, blur and separators.
- Disables modern notification grouping where the iOS 15 classes expose the
  same selectors.
- iOS 9-inspired full-screen Now Playing presentation using MediaRemote.
- Play/pause, previous and next controls.
- Rootless package layout for Sileo / Dopamine.

## Important

This project targets private SpringBoard / CoverSheet / NotificationCenter
classes. Private APIs can differ between iOS point releases. The code is
written defensively, but it still needs **real-device validation on iOS
15.8.8** before it should be considered release-quality.

NineLS itself was written for iOS 13/14; Nine15 is a clean iOS 15-oriented
implementation inspired by its architecture rather than a binary port.

## Build

Requires Theos, an iPhoneOS SDK, and ldid.

```sh
make clean package FINALPACKAGE=1
```

The rootless `.deb` will be placed in `packages/`.

## GitHub Actions

Push this folder to GitHub and run the included **Build Nine15** workflow.
The resulting `.deb` is uploaded as a workflow artifact.

## Install

On Dopamine:

1. Open the generated `*_iphoneos-arm64.deb` in Sileo.
2. Install it.
3. Restart SpringBoard when Sileo requests it.

If SpringBoard enters Safe Mode, uninstall Nine15 and collect the crash log
before trying another build.


## 0.2.0 visual rewrite

The notification rendering path was rewritten after comparing the iOS 15
result against the original Nine/NineLS look:

- Removes per-notification material/blur cards on Lock Screen and Notification Center.
- Uses one dark CoverSheet blur behind the entire notification list.
- Adds thin full-width separators.
- Forces white/vibrant notification text.
- Removes coalescing ("Show Less") controls and forces ungrouped presentation.
- Removes the custom "Notifications" title from the Lock Screen.
- Keeps the stock Lock Screen date view hidden in Notification Center.
- Hides slide-to-unlock while notifications are present, like NineLS' auto-hide behavior.
- Squares notification banners while preserving their native interactions.

The design/architecture is independently reimplemented for iOS 15 and was
informed by the MIT-licensed NineLS project by Minh-Ton:
https://github.com/minh-ton/NineLS
