# PersonalCenter tweak Makefile
#
# 说明：
#   - TARGET 指定编译 toolchain、最新 SDK，最低部署版本 13.0
#   - ARCHS 同时打 arm64 / arm64e，老/新设备都能跑
#   - TWEAK_NAME 决定输出： .theos/obj/PersonalCenter.dylib
#

TARGET           = iphone:clang:latest:13.0
ARCHS            = arm64 arm64e
INSTALL_TARGET_PROCESSES = Filza

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = PersonalCenter

PersonalCenter_FILES        = PersonalCenterTweak.m PersonalCenterViewController.m
PersonalCenter_FRAMEWORKS   = UIKit Foundation CoreGraphics QuartzCore
PersonalCenter_CFLAGS       = -fobjc-arc -Wno-deprecated-declarations
PersonalCenter_PRIVATE_FRAMEWORKS =

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 Filza || true"
