# Changelog

## 0.1.0

- Replace the InfoBar stub with nine reusable slots, Top/Bottom placement, configurable dimensions, and an independently anchored geometric center.
- Add the default Toxi-style mapping and a small registry with one instance per key, silent missing providers, and safe detach/cleanup.
- Implement Time with local/server source, 12/24-hour format, a separate accent colon, font size, vertical offset, and one cancellable one-second ticker. Narrow hosts fit the rendered font without changing saved size.
- Add ALWAYS, NO_COMBAT, and event-driven MOUSEOVER visibility. Time and empty slots allow clicks through.
- Extend existing commands with settings, reset, and transient slot preview; status reports provider count and preset.
- Extend InfoBar in place to schema 2 while preserving unknown fields and all existing Enhanced Resource Bars data.
- Follow supported public font/accent/panel changes through the adapter without rebuilding providers.
- Expand static and mocked Lua 5.1 validation for repair, geometry, registry, clocks, visibility, commands, and cleanup.

Retail execution and visual acceptance remain unverified. Other InfoBar providers and resource-bar implementation remain outside this release.

## 0.0.1-dev

- Establish the Retail addon manifest and lightweight namespace.
- Add safe initialization of `CarGOOrbitDB` with schema version 1.
- Centralize documented EllesmereUI skinning integration in `EUIAdapter`.
- Report public capabilities and keep unsupported integration surfaces disabled.
- Add local `/orbit` and `/cgo` diagnostics and a bootstrap skinning test panel.
- Add disabled-by-default InfoBar and Enhanced Resource Bars lifecycle stubs.
- Document resource ownership, product boundaries, and future milestones.
- Add static validation and mocked Lua 5.1 lifecycle checks.

This is a development bootstrap. Retail execution, theme behavior, and gameplay compatibility still require in-game validation.
