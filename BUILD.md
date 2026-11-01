# Build Velvet - Liquid Glass

Version: **1.0.0**. The two build schemes produce separate rootless and native RootHide packages.

## Requirements

- macOS with full Xcode selected as the active developer directory and its iPhoneOS SDK installed.
- Make, Perl with `Archive::Tar`, Python 3 with gzip/lzma support and `ldid` available in your build environment.
- The RootHide Theos fork with its submodules, headers and libraries.

Check your Xcode selection with `xcode-select -p` and SDK availability with `xcrun --sdk iphoneos --show-sdk-path`. Use Xcode's Settings > Locations to select the installed Xcode command-line tools if necessary.

## Set up Theos

From the repository root:

```sh
git clone https://github.com/roothide/theos.git .toolchain/theos
git -C .toolchain/theos checkout cfba89a53a05b4a1b822121158acc3669c20602f
git -C .toolchain/theos submodule update --init --recursive
export THEOS="$PWD/.toolchain/theos"
```

This revision is the toolchain used for the supplied packages. Do not substitute a generic rootless build for the native RootHide build.

## Build and validate

```sh
sh build.sh all
```

Or select one environment:

```sh
sh build.sh rootless
sh build.sh roothide
```

The build script runs the host regression checks, builds each requested package, normalizes archive ownership and validates the resulting package. Packages appear in `packages/`; validation reports appear in `validation/`.

| Scheme | Package architecture | Mach-O architectures | Installation layout |
| --- | --- | --- | --- |
| Rootless | `iphoneos-arm64` | arm64 + arm64e | `/var/jb` |
| RootHide | `iphoneos-arm64e` | arm64e | Native RootHide layout with runtime path resolution |

The source uses an iOS 15 compilation deployment target for toolchain purposes. **The package requires iOS 26.** That compiler setting does not imply older iOS compatibility.

## Source layout

- `src/`: original-derived hooks, preference manager, colorizer and color detection.
- `compat/`: iOS 26 runtime adaptation, styling, geometry, settings storage, import/export and test-banner service.
- `preferences/`: native settings controller, live controls, LS/NC preview and resources.
- `headers/`: private API declarations and source interfaces.
- `tests/`: host regression checks run under AddressSanitizer and UndefinedBehaviorSanitizer.
- `validate_package.py`: package structure, metadata, architecture, ownership and signature validation.
- `UPSTREAM.json`: exact original Velvet source revision.

The local `Preferences.framework` stub supplies link declarations only. No Apple framework binaries, device symbols, personal preferences or private diagnostic reports are included.

## Implementation details

Runtime hooks check selectors and argument encodings before installation. Icon images come from the system's rendered notification icon path. Cached palettes and event-driven refreshes avoid repeatedly sampling the same image or running a polling loop.

The LS/NC preview initializes with compact notification typography and accepts validated numeric font profiles from native notifications. The banner and LS/NC surfaces are distinct. Custom text styles survive native appearance updates while unchanged text retains system handling.

Settings use the `com.sahinkaa.velvetliquidglass` domain. Initial migration copies valid original `com.noisyflake.velvet2` preferences only when the new file is absent. Per-app overrides retain compatible storage keys. The menu says Time; `date*` keys and Apple's `dateLabel` selectors remain for compatibility.

Import/export uses public Files document pickers. Imports accept XML or binary property-list dictionaries up to 1 MiB, validate types and values, save the exact previous state to a `.before-import.plist` backup and atomically replace the complete saved configuration. Missing keys return to defaults or inheritance. Runtime caches and diagnostics are not exported.

## Checks and practical limits

```sh
sh tests/run.sh
python3 validate_package.py packages/com.sahinkaa.velvetliquidglass_1.0.0_iphoneos-arm64.deb rootless
python3 validate_package.py packages/com.sahinkaa.velvetliquidglass_1.0.0_iphoneos-arm64e.deb roothide
```

The release build passed 32 host check groups and offline package validation. Host checks verify logic and package integrity; they do not establish compatibility with every device or OS build. The device-tested configuration is listed in [README.md](README.md).
