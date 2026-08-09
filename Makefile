ARCHS = arm64
TARGET := iphone:clang:latest:14.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = AdvancedAutoClicker

ZSFakeTouch_DIR = ZSFakeTouch/ZSFakeTouchDome/ZSFakeTouch
ZSFakeTouch_ADDITION = $(ZSFakeTouch_DIR)/addition
ZSFakeTouch_VISUALIZER = $(ZSFakeTouch_DIR)/Visualizer

AdvancedAutoClicker_FILES = \
	Tweak.x \
	$(ZSFakeTouch_DIR)/ZSFakeTouch.m \
	$(ZSFakeTouch_ADDITION)/UIApplication-KIFAdditions.m \
	$(ZSFakeTouch_ADDITION)/UITouch-KIFAdditions.m \
	$(ZSFakeTouch_ADDITION)/UIEvent+KIFAdditions.m \
	$(ZSFakeTouch_ADDITION)/IOHIDEvent+KIF.m

AdvancedAutoClicker_FILES += $(foreach file,$(wildcard $(ZSFakeTouch_VISUALIZER)/*.m),$(file))

AdvancedAutoClicker_CFLAGS = \
	-fobjc-arc \
	-ObjC \
	-I$(ZSFakeTouch_DIR) \
	-I$(ZSFakeTouch_ADDITION) \
	-I$(ZSFakeTouch_VISUALIZER)

AdvancedAutoClicker_FRAMEWORKS = UIKit Foundation CoreGraphics QuartzCore
AdvancedAutoClicker_PRIVATE_FRAMEWORKS = IOKit

INSTALL_TARGET_PROCESSES =

include $(THEOS_MAKE_PATH)/tweak.mk
