## Velvet - Liquid Glass - 1.0.0

An unofficial iOS 26 continuation of **Velvet by [NoisyFlake](https://github.com/NoisyFlake)**, maintained by **[sahinkaa](https://github.com/sahinkaa)**.

Thank you to NoisyFlake for creating Velvet and releasing its source under the MIT license. His work is the foundation of this project. Full credit for the original tweak belongs to him. This is an independently maintained release and is not endorsed by NoisyFlake.

### Features

- Custom backgrounds, outer glow, title/message/time colors and corner radius.
- Dedicated **Banner Borders**, affecting banners only.
- Icon Color, Static Color and Gradient modes where supported, with independent Opacity and Shade controls.
- Global styles and per-app overrides, including **Reset This App**.
- Live sliders, exact numeric input and double-tap Shade reset.
- Persistent native Test Banner using the selected app's system-rendered icon, including its applied theme.
- Separate Lock Screen / Notification Center preview and Light/Dark banner controls on every settings page.
- Files-based export and import of the complete configuration, with validated imports and a pre-import backup.
- Automatic migration of valid original Velvet preferences when no new preference file exists.

### Changes from the original

The settings interface, preview and notification styling paths were adapted for iOS 26 Liquid Glass. Notification refresh handling, outer glow, corner-radius mapping, numeric controls and color controls were reworked.

Removed from global and per-app settings: **Line**, **Hide App Icon**, **Round App Icon**, **No Stack Dimming** and **Hide Background Blur**. General borders became **Banner Borders**. The System appearance choice was removed and Date is now named Time.

Lock Screen and Notification Center follow the **dark Banner settings**. iOS renders their Liquid Glass surfaces differently from banners, so their final appearance can differ.

**Style changes apply live without a respring.** Respring after installation or when changing the main Enable Tweak switch.

### Choose your package

| Environment | File |
| --- | --- |
| Rootless | `com.sahinkaa.velvetliquidglass_1.0.0_iphoneos-arm64.deb` |
| Native RootHide | `com.sahinkaa.velvetliquidglass_1.0.0_iphoneos-arm64e.deb` |

RootHide users should install the native package directly without RootHide Patcher. Both packages are version **1.0.0**.

**Requires iOS 26. Tested only on iPhone 11 Pro Max running iOS 26.0.1 with Dopamine 3 RootHide.** The rootless build, other devices and other iOS 26 versions have not been independently device-tested for this release.

Source code, build instructions and SHA-256 checksums are included. See the [README](https://github.com/sahinkaa/VelvetLiquidGlass#readme) for the complete feature guide, installation instructions, removed options and credits. Please report issues in [this repository](https://github.com/sahinkaa/VelvetLiquidGlass/issues).
