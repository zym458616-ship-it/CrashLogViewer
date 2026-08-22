export ARCHS = arm64 arm64e
export TARGET = iphone:clang:latest:15.0

INSTALL_TARGET_PROCESSES = SpringBoard

# roothide 隐根越狱专属打包方案（需 roothide/theos fork）
THEOS_PACKAGE_SCHEME = roothide

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = CrashCatcher

CrashCatcher_FILES = Tweak.xm
CrashCatcher_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
CrashCatcher_FRAMEWORKS = UIKit Foundation

include $(THEOS_MAKE_PATH)/tweak.mk
