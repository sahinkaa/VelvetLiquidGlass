#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
v26_test_dir=$(mktemp -d "${TMPDIR:-/tmp}/velvet26-regression.XXXXXX")
trap 'rm -rf "$v26_test_dir"' EXIT HUP INT TERM
xcrun --sdk macosx clang -g -fobjc-arc -fblocks -fstack-protector-strong \
  -fsanitize=address,undefined -Wall -Wextra -Wno-unused-parameter \
  -DV26_HOST=1 -framework Foundation compat/SettingsTransfer.m compat/SettingsStore.m compat/Runtime.m tests/regression.m \
  -o "$v26_test_dir/regression"
"$v26_test_dir/regression" "$v26_test_dir"
xcrun --sdk macosx clang -g -fobjc-arc -fblocks -fstack-protector-strong \
  -fsanitize=address,undefined -Wall -Wextra -Wno-unused-parameter -Wno-nonnull \
  -Itests -framework Foundation -framework CoreGraphics src/ColorDetection.m tests/palette.m \
  -o "$v26_test_dir/palette"
"$v26_test_dir/palette"
xcrun --sdk macosx clang -g -fobjc-arc -fblocks -fstack-protector-strong \
  -fsanitize=address,undefined -Wall -Wextra -Wno-unused-parameter \
  -framework Foundation compat/SettingsTransfer.m compat/SettingsStore.m compat/PaneModel.m tests/native_pane.m \
  -o "$v26_test_dir/native-pane"
"$v26_test_dir/native-pane" "$PWD/preferences/Resources"

xcrun --sdk macosx clang -g -fobjc-arc -fblocks -fstack-protector-strong \
  -fsanitize=address,undefined -Wall -Wextra -Wno-unused-parameter -DV26_HOST=1 \
  -framework Foundation -framework CoreGraphics compat/Runtime.m compat/UpdateCycle.m compat/NativeShape.m tests/update_cycle.m \
  -o "$v26_test_dir/update-cycle"
"$v26_test_dir/update-cycle"
xcrun --sdk macosx clang -g -fobjc-arc -fblocks -fstack-protector-strong \
  -fsanitize=address,undefined -Wall -Wextra -Wno-unused-parameter -DV26_HOST=1 -DV26_STYLE_HOST=1 \
  -framework Foundation -framework CoreGraphics -framework QuartzCore \
  compat/Runtime.m compat/UpdateCycle.m compat/NativeShape.m compat/DecorationSurface.m compat/ForegroundRaster.m compat/SettingsTransfer.m compat/SettingsStore.m compat/NativePreviewMaterial.m compat/NativeOutline.m compat/CardStyle.m compat/CardSurface.m compat/IconCompletion.m compat/BannerTemplate.m tests/style.m \
  -o "$v26_test_dir/style"
VLG_TEMPLATE_TEST_PATH="$v26_test_dir/banner-template.plist" "$v26_test_dir/style"

xcrun --sdk macosx clang -g -fobjc-arc -fblocks -fstack-protector-strong \
  -fsanitize=address,undefined -Wall -Wextra -Wno-unused-parameter \
  -framework Foundation -framework CoreGraphics -framework QuartzCore -framework ImageIO \
  compat/ForegroundRaster.m tests/raster.m -o "$v26_test_dir/raster"
"$v26_test_dir/raster"

xcrun --sdk macosx clang -g -fobjc-arc -fblocks -fsanitize=address,undefined -Wall -Wextra -Wno-unused-parameter \
  -framework Foundation compat/NumericSetting.m tests/numeric.m -o "$v26_test_dir/numeric"
"$v26_test_dir/numeric"

xcrun --sdk macosx clang -g -fobjc-arc -fblocks -fsanitize=address,undefined -Wall -Wextra -Wno-unused-parameter \
  -DV26_HOST=1 -DV26_PREFS_HOST=1 -framework Foundation -framework CoreGraphics \
  compat/Runtime.m compat/SettingsTransfer.m compat/SettingsStore.m compat/CardStyle.m src/Velvet2PrefsManager.m tests/manager.m -o "$v26_test_dir/manager"
VLG_PREFS_TEST_PATH="$v26_test_dir/manager.plist" "$v26_test_dir/manager"

xcrun --sdk macosx clang -g -fobjc-arc -fblocks -fsanitize=address,undefined -Wall -Wextra -Wno-unused-parameter \
  -DV26_HOST=1 -framework Foundation -framework CoreFoundation compat/Runtime.m compat/TestBanner.m tests/test_banner.m -o "$v26_test_dir/test-banner"
"$v26_test_dir/test-banner" "$v26_test_dir"

xcrun --sdk macosx clang -g -fobjc-arc -fblocks -fsanitize=address,undefined -Wall -Wextra -Wno-unused-parameter \
  -DV26_HOST=1 -DVLG_TEST_SERVICE_HOST=1 -framework Foundation -framework CoreFoundation compat/Runtime.m compat/TestBanner.m tests/test_banner_service.m -o "$v26_test_dir/test-banner-service"
"$v26_test_dir/test-banner-service" "$v26_test_dir"

xcrun --sdk macosx clang -g -fobjc-arc -fblocks -fsanitize=address,undefined -Wall -Wextra -Wno-unused-parameter \
  -framework Foundation -framework CoreGraphics compat/CardStyle.m tests/card_style.m -o "$v26_test_dir/card-style"
"$v26_test_dir/card-style"

xcrun --sdk macosx clang -g -fobjc-arc -fblocks -fsanitize=address,undefined -Wall -Wextra -Wno-unused-parameter -Wno-incomplete-implementation -Wno-objc-protocol-method-implementation \
  -DVLG_COLORIZER_HOST=1 -framework Foundation -framework CoreGraphics -framework QuartzCore \
  compat/CardStyle.m src/Velvet2Colorizer.m tests/text_defaults.m -o "$v26_test_dir/text-defaults"
"$v26_test_dir/text-defaults"

xcrun --sdk macosx clang -g -fobjc-arc -fblocks -fsanitize=address,undefined -Wall -Wextra -Wno-unused-parameter \
  -DV26_HOST=1 -DVLG_TYPOGRAPHY_HOST=1 -framework Foundation -framework CoreFoundation \
  compat/Runtime.m compat/BannerTypography.m tests/typography.m -o "$v26_test_dir/typography"
VLG_FONT_TEST_PATH="$v26_test_dir/fonts/profile.plist" "$v26_test_dir/typography"

xcrun --sdk macosx clang -g -fobjc-arc -fblocks -fsanitize=address,undefined -Wall -Wextra -Wno-unused-parameter \
  -framework Foundation compat/SettingsTransfer.m compat/SettingsStore.m tests/migration.m -o "$v26_test_dir/migration"
mkdir -p "$v26_test_dir/migration-data"
"$v26_test_dir/migration" "$v26_test_dir/migration-data"

xcrun --sdk macosx clang -g -fobjc-arc -fblocks -fsanitize=address,undefined -Wall -Wextra -Wno-unused-parameter \
  -framework Foundation -framework CoreFoundation compat/SettingsTransfer.m compat/SettingsStore.m tests/transfer.m -o "$v26_test_dir/transfer"
"$v26_test_dir/transfer" "$v26_test_dir"
