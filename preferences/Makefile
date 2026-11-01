include ../BuildConfig.mk
INSTALL_TARGET_PROCESSES = Preferences
include $(THEOS)/makefiles/common.mk
BUNDLE_NAME = VelvetLiquidGlass
VelvetLiquidGlass_FILES = NativeController.m LiquidGlassPreview.m NumericSliderCell.m ../compat/NumericSetting.m ../compat/NativePreviewMaterial.m ../compat/NativeShape.m ../compat/BannerTypography.m ../compat/CardStyle.m ../compat/CardSurface.m ../compat/ForegroundRaster.m ../compat/NativeOutline.m ../compat/TestBanner.m ../src/Velvet2PrefsManager.m ../src/UIColor+Velvet.m ../src/ColorDetection.m ../src/Velvet2Colorizer.m ../compat/Runtime.m ../compat/SettingsTransfer.m ../compat/SettingsStore.m ../compat/PaneModel.m ../compat/DecorationSurface.m
VelvetLiquidGlass_FRAMEWORKS = UIKit Foundation CoreFoundation QuartzCore CoreGraphics AudioToolbox UniformTypeIdentifiers
VelvetLiquidGlass_PRIVATE_FRAMEWORKS = Preferences
VelvetLiquidGlass_LIBRARIES = $(V26_LIBRARIES)
VelvetLiquidGlass_LDFLAGS = -F$(THEOS_PROJECT_DIR)/preferences/vendor
VelvetLiquidGlass_INSTALL_PATH = /Library/PreferenceBundles
VelvetLiquidGlass_CFLAGS = -fobjc-arc -fstack-protector-strong -Wall -Wextra -Wno-unused-parameter -Wno-deprecated-declarations $(V26_DEFINES) -DPACKAGE_VERSION='@"$(THEOS_PACKAGE_BASE_VERSION)"'
include $(THEOS_MAKE_PATH)/bundle.mk
