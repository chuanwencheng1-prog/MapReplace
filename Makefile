ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:11.0

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = MapReplacer

MapReplacer_FILES = Classes/AppDelegate.m Classes/MapViewController.m Classes/MapManager.m main.m
MapReplacer_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -IClasses
MapReplacer_FRAMEWORKS = UIKit Foundation CoreGraphics QuartzCore
MapReplacer_CODESIGN_FLAGS = -Sentitlements.xml

include $(THEOS_MAKE_PATH)/application.mk
