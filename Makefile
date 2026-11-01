include BuildConfig.mk
INSTALL_TARGET_PROCESSES = SpringBoard
include $(THEOS)/makefiles/common.mk
TWEAK_NAME = VelvetLiquidGlass
VelvetLiquidGlass_FILES = src/Tweak.x src/UIColor+Velvet.m src/Velvet2PrefsManager.m src/ColorDetection.m src/Velvet2Colorizer.m compat/Runtime.m compat/SettingsTransfer.m compat/SettingsStore.m compat/NotificationStyle.m compat/UpdateCycle.m compat/NativeShape.m compat/BannerTypography.m compat/CardStyle.m compat/CardSurface.m compat/DecorationSurface.m compat/ForegroundRaster.m compat/NativeOutline.m compat/IconCompletion.m compat/TestBanner.m compat/TestBannerSpringBoard.m
VelvetLiquidGlass_CFLAGS = -fobjc-arc -fstack-protector-strong -Wall -Wextra -Wno-unused-parameter -Wno-deprecated-declarations $(V26_DEFINES)
VelvetLiquidGlass_FRAMEWORKS = UIKit Foundation CoreFoundation QuartzCore CoreGraphics
VelvetLiquidGlass_LIBRARIES = $(V26_LIBRARIES)
include $(THEOS_MAKE_PATH)/tweak.mk
SUBPROJECTS += preferences
include $(THEOS_MAKE_PATH)/aggregate.mk
