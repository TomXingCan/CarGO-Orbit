# Architecture

CarGO Orbit `0.0.1-dev` is a Retail bootstrap with one public integration boundary and two feature stubs.

```text
CarGO Orbit
|-- Core: namespace, database, events, diagnostics
|-- EUIAdapter: the only EUI integration boundary
|-- InfoBar: lifecycle stub
`-- Enhanced Resource Bars: lifecycle stub
```

## Repository and installed addon

```text
CarGO-Orbit/
|-- CarGO_Orbit/
|   |-- CarGO_Orbit.toc
|   |-- Core/
|   |   |-- Addon.lua
|   |   |-- Database.lua
|   |   |-- Events.lua
|   |   |-- EUIAdapter.lua
|   |   `-- Diagnostics.lua
|   |-- Config/Defaults.lua
|   |-- Modules/
|   |   |-- InfoBar/Core.lua
|   |   `-- EnhancedResourceBars/Core.lua
|   |-- UI/
|   |   |-- Skin.lua
|   |   `-- DebugPanel.lua
|   `-- Locales/enUS.lua
|-- docs/
|-- tests/
|-- README.md
|-- CHANGELOG.md
|-- NOTICE.md
|-- LICENSE
`-- .gitignore
```

Only `CarGO_Orbit/` belongs in the game's AddOns directory. Documentation and test tools stay at the repository root. EllesmereUI is installed separately and declared as a required dependency.

## Responsibilities

| Component | Responsibility |
| --- | --- |
| `Core/Addon.lua` | Lightweight namespace, version, module registry, and addon lifecycle. |
| `Config/Defaults.lua` | Defaults for Orbit-owned saved settings. |
| `Core/Database.lua` | Nil-safe initialization and preservation of unknown fields. |
| `Core/Events.lua` | Track and release Orbit-owned event and timer resources. |
| `Core/EUIAdapter.lua` | Public API detection, skin wrappers, live style access, and looks-change dispatch. |
| `Core/Diagnostics.lua` | Local slash-command output and bounded, event-driven debug logging. |
| `UI/Skin.lua` | Orbit UI helpers that call the adapter. |
| `UI/DebugPanel.lua` | Reusable bootstrap controls owned by Orbit. |
| `Modules/*/Core.lua` | Persisted enable/disable state and lifecycle stubs. |
| `Locales/enUS.lua` | English strings for this stage. |

No framework dependency is introduced. The namespace exposes `name`, `version`, `debug`, `modules`, and `capabilities`, with `RegisterModule(name, module)` and `GetModule(name)`.

## Public integration contract

**EUIAdapter is the only EUI integration boundary.** Other components request styling and state through it. They do not access EllesmereUI globals, saved settings, frames, or internal implementations directly.

The adapter detects EllesmereUI and its documented `RegisterSkin` entry point. It receives the borrowed Skinning API object in the registration callback, reads the public `apiVersion`, and gates use on supported API versions and callable methods. The documented contract is [Skinning API](https://github.com/EllesmereGaming/EllesmereUI/blob/main/SKINNING_API.md).

Missing APIs and failed public calls leave Orbit operational. The callback can be delayed until login, run immediately for a late registration, or be suppressed when third-party skinning is disabled. Availability of the addon alone therefore does not establish availability of the Skinning API.

Wrappers cover shell, panel, button, checkbox, dropdown, edit box, scrollbar, tab, font, and status-bar styling. Color/font accessors read current public values. Color values are not cached for the session. Public looks-change notifications refresh Orbit-owned custom elements without rebuilding the entire window.

| Adapter operation | Public API |
| --- | --- |
| Register the addon | `EllesmereUI.RegisterSkin` |
| Detect version and enabled state | `S.apiVersion`, `S.IsEnabled` |
| Style shell and panel | `S.Shell`, `S.Panel` |
| Style controls | `S.Button`, `S.Checkbox`, `S.Dropdown`, `S.EditBox`, `S.ScrollBar`, `S.Tab` |
| Style font and status bar | `S.Font`, `S.ApplyBarFill` |
| Read current style values | `S.GetAccentColor`, `S.GetPanelColor`, `S.GetFont` |
| Subscribe to appearance changes | `S.OnLooksChanged` |

The documented current API version is 2. These particular wrappers use primitives already present in version 1; a missing/invalid version or missing individual method degrades gracefully. An additive future API version can retain these same primitives.

The panel actually invokes `Shell`, `Panel`, `Button`, `Checkbox`, `EditBox`, `Font`, `ApplyBarFill`, and `GetAccentColor`, with registration, version/enabled checks, and looks notifications handled by the adapter. `Dropdown`, `ScrollBar`, `Tab`, `GetPanelColor`, and `GetFont` have adapter wrappers but are not exercised by the bootstrap panel.

The capability registry reports:

| Capability | Meaning in this stage |
| --- | --- |
| `eui` | EllesmereUI is present. |
| `skinAPI` | A supported public Skinning API is available. |
| `skinAPIVersion` | Received public API version, or `0` when no valid version was received. |
| `dataBarsExtensionAPI` | Always `false`; no supported extension contract is used. |
| `resourceBarsExtensionAPI` | Always `false`; no supported host contract is used. |
| `optionsRegistrationAPI` | Always `false`; no native options registration is attempted. |

## Settings and module state

The only saved variable is `CarGOOrbitDB`. It has `meta.schemaVersion = 1` and a `profile` table containing `debug`, `infoBar.enabled`, and `enhancedResourceBars.enabled`. These profile flags default to `false`. Initialization fills missing defaults without deleting unknown keys; malformed required containers are repaired safely. This is a single settings container, not a profile system.

Each feature stub exposes `IsEnabled()`, `Enable()`, and `Disable()`. Enabling InfoBar records intent without creating a bar. Enabling Enhanced Resource Bars records `enabled-but-no-host` because no public extension contract is available. Neither stub creates gameplay UI, predictions, or attachments.

## Resource lifecycle

Every event, timer, frame, and listener belongs to Orbit or an Orbit module. Disable releases owned event subscriptions and timers, hides/clears debug UI, and removes temporary listeners and references. There is no permanent per-frame update loop. Debug output occurs in response to events and is bounded.

EllesmereUI's documented registration and looks-change APIs do not provide unregister operations. To avoid inventing cleanup calls or accumulating external callbacks, the adapter keeps one stable bridge per external registration and its borrowed public API reference for the session. Disable clears all Orbit listener closures and suppresses bridge dispatch. Re-enable reuses the bridges and retained API; it does not register duplicates. These externally retained bridges are a public API limitation, not active Orbit UI listeners after disable.

The test panel is created lazily, hidden on disable, and reused. After initial styling, looks changes refresh only Orbit-owned drawing that needs a fresh public color. EllesmereUI remains responsible for its own skinned control behavior.

## Validation boundary

Static scans validate manifest paths and ordering, dependency boundaries, and prohibited integration patterns. The Python runner compiles the addon and test harness as Lua 5.1 before running the mocked lifecycle checks. The harness exercises settings, cleanup, adapter failures, capability reporting, and callback handling. It cannot reproduce the Retail client or validate rendered theme behavior. The README contains the required manual checks; no in-game validation is claimed.
