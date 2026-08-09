ARCHS = arm64
TARGET = iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES =

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = AdvancedAutoClicker
AdvancedAutoClicker_FILES = Tweak.x ZSFakeTouch/ZSFakeTouchDome/ZSFakeTouch/ZSFakeTouch.m
AdvancedAutoClicker_CFLAGS = -fobjc-arc
AdvancedAutoClicker_FRAMEWORKS = UIKit Foundation QuartzCore

include $(THEOS_MAKE_PATH)/tweak.mk
