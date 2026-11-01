<p align="center">
  <img src="preferences/Resources/velvet-header-icon.png" width="104" alt="Velvet logo">
</p>

# Velvet - Liquid Glass

**Make iOS 26 notifications your own.** Customize backgrounds, glow, text colors, corner radius and banner borders with live controls and per-app settings.

[Download 1.0.0](https://github.com/sahinkaa/VelvetLiquidGlass/releases/tag/v1.0.0) · [Installation](#installation) · [Changes from Velvet](#changes-from-velvet) · [Build from source](BUILD.md)

## With respect to NoisyFlake

Velvet was created by **[NoisyFlake](https://github.com/NoisyFlake)**. This project is built on his [original Velvet source](https://github.com/NoisyFlake/Velvet2), which he generously released under the MIT license.

Thank you, NoisyFlake, for creating Velvet and sharing your work with the jailbreak community. Your design and code made this continuation possible. Full credit for the original tweak belongs to you.

**Velvet - Liquid Glass is an unofficial continuation maintained by [sahinkaa](https://github.com/sahinkaa).** It is independently maintained and is not an official NoisyFlake release or endorsed by him. Please report issues with this version in [this repository](https://github.com/sahinkaa/VelvetLiquidGlass/issues).

## Compatibility

- **Requires iOS 26 and a jailbreak.**
- **Tested on:** iPhone 11 Pro Max, iOS 26.0.1, Dopamine 3 RootHide.
- Separate **rootless** and **native RootHide** packages are provided.
- The rootless package and other devices or iOS 26 versions have not been independently device-tested for this release. Older iOS versions are not supported by this edition.

## What you can customize

| Setting | What it does |
| --- | --- |
| **Banner Borders** | Adds a configurable border to banners. Does not add borders to Lock Screen or Notification Center cards. |
| **Background** | Colors the notification surface using Icon Color, Static Color or a Gradient. |
| **Glow** | Adds an outer glow with adjustable color, size, opacity and shade. |
| **Title** | Customizes the notification title color. |
| **Message** | Customizes the notification message color. |
| **Time** | Customizes the timestamp color. |
| **Corner Radius** | Adjusts the notification shape from square to fully rounded. |

Set a global style for all apps or override individual settings for a particular app. Supported color modes include independent **Opacity** and **Shade** controls. Move Shade left for a darker color or right for a lighter color, with **0** as the unchanged color.

### Adjust it live

The settings layout keeps a real **Test Banner** above a separate **Lock Screen / Notification Center preview**. Tap the preview to choose an app and use its system-rendered icon, including its applied theme, as the color source.

- Tap **Test Banner** to show a persistent, silent banner while you adjust your style.
- Switch **Banner: Light / Dark** on any settings page to see the banner in both appearances.
- Lock Screen and Notification Center follow the **dark Banner settings**. Their material can look different from a banner because iOS composites the two surfaces differently.
- Drag sliders to see values update live or tap a blue value to enter an exact number.
- Double-tap the Shade slider thumb or its value to return to **0**.

The test banner does not change an app's badges, notification permissions or real notification history. Swipe it away to dismiss it. It also closes when you leave Velvet settings, background Settings or lock the phone.

**Style settings take effect without a respring**, including updates to the active test banner. Installing or updating the tweak and changing the main **Enable Tweak** switch require a respring.

## Changes from Velvet

This continuation keeps Velvet's core idea: an icon-adaptive notification experience with global and per-app customization. The original iOS 16 presentation and settings code have been adapted for iOS 26's Liquid Glass surfaces.

### Added or reworked

- Rebuilt the settings interface for iOS 26, replacing the older custom settings controls and preview path.
- Adapted notification styling and refresh handling for banners, Lock Screen cards, Notification Center cards and notification stacks.
- Uses system-rendered app icons as color sources with palette caching and updates when icon images become available.
- Added a persistent native Test Banner and a separate LS/NC preview so both results can be checked together.
- Added a persistent Light/Dark banner selector on every settings page.
- Reworked outer glow placement and notification corner-radius handling for Liquid Glass.
- Made borders a dedicated **Banner Borders** feature.
- Added Shade controls alongside Opacity for supported Icon Color, Static Color and Gradient modes.
- Added exact numeric entry, live slider values, reliable range endpoints and double-tap Shade reset.
- Added **Reset This App** to clear only the selected app's overrides.
- Added **Export Settings** and **Import Settings** through Files, including global settings and per-app overrides.
- Added a separate preference domain with automatic migration of valid original Velvet settings when no new settings file exists.
- Provided separate rootless and native RootHide builds.

### Removed

These options have been removed from both global and per-app settings:

- **Line**
- **Hide App Icon**
- **Round App Icon**
- **No Stack Dimming**
- **Hide Background Blur**

General notification borders were replaced by **Banner Borders**. The former **System** appearance option was removed, leaving explicit Light and Dark banner controls. The **Date** menu is now named **Time**.

The native Liquid Glass appearance of Lock Screen and Notification Center cards is retained. This edition does not try to make those surfaces identical to banners.

## Installation

1. Download the appropriate `.deb` from [Releases](https://github.com/sahinkaa/VelvetLiquidGlass/releases/tag/v1.0.0).
2. Open it with your package manager and install it. The package declares conflicts with the original Velvet packages to prevent both versions loading together.
3. Respring once after installation.
4. Open **Settings > Velvet - Liquid Glass** and configure Global Settings or Per-App Settings.

| Jailbreak environment | Download |
| --- | --- |
| Standard rootless | `com.sahinkaa.velvetliquidglass_1.0.0_iphoneos-arm64.deb` |
| Dopamine 3 RootHide | `com.sahinkaa.velvetliquidglass_1.0.0_iphoneos-arm64e.deb` |

**RootHide users:** install the native `arm64e` package directly. Do not convert the rootless package with RootHide Patcher.

## Save, share or reset a configuration

**Export Settings** and **Import Settings** are directly below **Reset Settings** on the main page.

Export saves a property list through Files with this default name:

```text
Velvet - Liquid Glass settings.plist
```

Import asks for confirmation and **replaces the entire saved configuration**, including per-app overrides. Settings missing from the imported file return to defaults or global inheritance. A pre-import backup is saved before replacement. Invalid imports leave the existing settings unchanged.

Use **Reset This App** inside an app's settings to remove only its overrides. Use the main **Reset Settings** action to reset the complete configuration. Export first if you want a portable copy to restore later.

Existing valid `com.noisyflake.velvet2.plist` settings are copied automatically on first use if the new preference file does not exist. The original file is left unchanged. Removed options no longer affect styling.

## Source, credits and license

- **Original Velvet:** [NoisyFlake/Velvet2](https://github.com/NoisyFlake/Velvet2)
- **Liquid Glass continuation:** [sahinkaa](https://github.com/sahinkaa)
- **ColorCube color detection:** Ole Krause-Sparmann. Its original notice remains in [ColorDetection.m](src/ColorDetection.m).
- **License:** [MIT](LICENSE). NoisyFlake's original copyright and license are preserved.
- **Upstream source revision:** recorded in [UPSTREAM.json](UPSTREAM.json).
- **Build instructions:** [BUILD.md](BUILD.md).

Both package variants are version **1.0.0**. Release assets include the source archive and SHA-256 checksums.

## Feedback

[Open an issue here](https://github.com/sahinkaa/VelvetLiquidGlass/issues) with your device, iOS version, jailbreak environment, package version and steps to reproduce the problem. A screenshot can help with appearance issues. If logs are needed, share only relevant details and remove private notification content.
