THEOS_PACKAGE_SCHEME ?= roothide
ifeq ($(THEOS_PACKAGE_SCHEME),roothide)
ARCHS = arm64e
V26_DEFINES = -DV26_ROOTHIDE=1
V26_LIBRARIES = roothide
else ifeq ($(THEOS_PACKAGE_SCHEME),rootless)
ARCHS = arm64 arm64e
else
$(error Use rootless or roothide)
endif
TARGET = iphone:clang:latest:15.0
FINALPACKAGE = 1
