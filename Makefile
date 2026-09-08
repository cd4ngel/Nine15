ARCHS = arm64
TARGET = iphone:clang:latest:15.0
THEOS_PACKAGE_SCHEME = rootless

INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Nine15

Nine15_FILES = Tweak.xm
Nine15_CFLAGS = -fobjc-arc -Wall -Wextra
Nine15_FRAMEWORKS = UIKit Foundation QuartzCore
Nine15_LDFLAGS = -ldl

include $(THEOS_MAKE_PATH)/tweak.mk
