THEOS_DEVICE_IP = 
ARCHS = arm64 arm64e
TARGET = iphone::9.0:14.5

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = MapReplacer

MapReplacer_FILES = Classes/AppDelegate.m Classes/MapManager.m Classes/UIOverlay.m
MapReplacer_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
MapReplacer_FRAMEWORKS = UIKit Foundation
MapReplacer_CODESIGN_FLAGS = -Sentitlements.xml
MapReplacer_INSTALL_PATH = /Applications

include $(THEOS_MAKE_PATH)/application.mk
