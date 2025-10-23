ARCHS = armv7 arm64 arm64e
TARGET = iphone:clang:latest:7.0

include $(THEOS)/makefiles/common.mk

TOOL_NAME = wifihooklibd

wifihooklibd_FILES = wifihookd.m
wifihooklibd_CFLAGS = -fobjc-arc
wifihooklibd_FRAMEWORKS = Foundation
wifihooklibd_PRIVATE_FRAMEWORKS = MobileWiFi
wifihooklibd_INSTALL_PATH = /usr/libexec
wifihooklibd_CODESIGN_FLAGS = -Sentitlements.xml

include $(THEOS_MAKE_PATH)/tool.mk

after-install::
	install.exec "launchctl unload /Library/LaunchDaemons/com.apple.wifihooklibd.plist 2>/dev/null || true"
	install.exec "launchctl load /Library/LaunchDaemons/com.apple.wifihooklibd.plist"
