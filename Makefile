ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:16.0
export THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Wechathook
Wechathook_FILES = ColorTime.xm
Wechathook_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-error=objc-method-access
Wechathook_FRAMEWORKS = UIKit CoreGraphics
INSTALL_TARGET_PROCESSES = WeChat

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 WeChat || true"

export ADDITIONAL_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-error=objc-method-access