DEBUG = 0
FINALPACKAGE = 1

ARCHS = arm64 arm64e

# Share the SDK and deployment targets with the PreferenceBundle.
include qwelllLoopScrollBuild.mk
include $(THEOS)/makefiles/common.mk

TWEAK_NAME = qwelllLoopScroll
qwelllLoopScroll_FILES = $(wildcard Hooks/*.xm Sources/*.m)
qwelllLoopScroll_CFLAGS = -fobjc-arc -I./Headers -I./Sources
qwelllLoopScroll_FRAMEWORKS = UIKit Foundation CoreFoundation
qwelllLoopScroll_LIBRARIES = substrate

include $(THEOS_MAKE_PATH)/tweak.mk


