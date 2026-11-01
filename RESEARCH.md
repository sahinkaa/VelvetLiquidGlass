# Implementation notes

Velvet - Liquid Glass adapts the original MIT-licensed Velvet source listed in UPSTREAM.json for iOS 26. Public code and link declarations are included; Apple frameworks, device symbols, personal preferences and diagnostic reports are not bundled.

Native runtime hooks validate method presence and argument encodings before installation. Notification styling tracks reusable views and updates when native icon images or styling providers become available. Custom text settings retain ownership through native styling updates. Icon palettes are cached; styling does not use a repeating polling loop.

The Settings preview uses a native notification material where available with a fallback. It initializes with compact typography, then accepts validated numeric native font profiles for actual font-size differences. Lock Screen and Notification Center use dark styling. Persistent test banners are separate native presentations and are dismissed when leaving the pane or presenting Files.

Settings writes use a shared destination lock and atomic replacement. Initial migration copies valid original Velvet preferences only if the new domain is absent. Import reads a bounded property list, validates the snapshot, preserves a pre-import backup and replaces the complete global/per-app configuration. Runtime caches and logs are excluded from exports.

Host regression checks cover settings storage, migration, import/export, palette logic, numeric ranges, geometry and styling state. Package validation checks architectures, metadata, resources, ownership and signatures. Device rendering remains environment-dependent; see README.md for the explicitly tested configuration.
