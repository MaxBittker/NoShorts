# Build a patched IPA:   make package IPA=/path/to/decrypted/YouTube.ipa
# Build a .deb only:     make package
# Debug logging:         add NOSHORTS_DEBUG=1
TARGET := iphone:clang:latest:15.0
ARCHS = arm64
FINALPACKAGE = 1

TWEAK_NAME = NoShorts

ifdef IPA
# theos-jailed injects the tweak (and CydiaSubstrate) into the given IPA.
MODULES = jailed
DISPLAY_NAME = YouTube
BUNDLE_ID = com.google.ios.youtube
CODESIGN_IPA = 0
REMOVE_EXTENSIONS = 1
else
THEOS_PACKAGE_SCHEME = rootless
endif

include $(THEOS)/makefiles/common.mk

NoShorts_FILES = Tweak.x SideloadFix.x
NoShorts_FRAMEWORKS = Security
NoShorts_CFLAGS = -fobjc-arc -I$(THEOS_PROJECT_DIR) -Wno-unused-variable
ifeq ($(NOSHORTS_DEBUG),1)
NoShorts_CFLAGS += -DNOSHORTS_DEBUG
endif

include $(THEOS_MAKE_PATH)/tweak.mk
