export ARCHS = arm64 arm64e
export TARGET = iphone:clang:latest:14.0

INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = CrashCatcher

CrashCatcher_FILES = Tweak.xm
CrashCatcher_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
CrashCatcher_FRAMEWORKS = UIKit Foundation

include $(THEOS_MAKE_PATH)/tweak.mk
