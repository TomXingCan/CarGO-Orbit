# Architecture

CarGO Orbit `0.1.0` has one public EllesmereUI integration boundary, an owned InfoBar runtime, and an unchanged Enhanced Resource Bars lifecycle stub.

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
|   |   |-- InfoBar/
|   |   |   |-- Core.lua
|   |   |   |-- Layout.lua
|   |   |   |-- Registry.lua
|   |   |   |-- Presets.lua
|   |   |   `-- Providers/Time.lua
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

Only `CarGO_Orbit/` belongs in the game's AddOns directory. EllesmereUI remains a required dependency. Public styling fallback does not remove that loader requirement; tests with EllesmereUI absent only establish runtime nil safety. No framework is introduced.

## Responsibilities

| Component | Responsibility |
| --- | --- |
| `Core/Addon.lua` | Namespace, version, module registry, and addon lifecycle. |
| `Config/Defaults.lua` | Canonical defaults and frozen default slot mapping. |
| `Core/Database.lua` | In-place initialization, InfoBar repair/reset, and schema migration. |
| `Core/Events.lua` | Owned subscriptions, one-shot timers, tickers, and cleanup. |
| `Core/EUIAdapter.lua` | Public detection, wrappers, style getters, and appearance notification dispatch. |
| `Core/Diagnostics.lua` | Existing slash parser, settings entry, status, and bounded logging. |
| `InfoBar/Core.lua` | Enable/disable, visibility, apply, and theme/resize subscriptions. |
| `InfoBar/Layout.lua` | One bar, three regions, nine stable buttons, pure geometry, and debug overlays. |
| `InfoBar/Registry.lua` | Registration, single-instance assignment, callback isolation, and detach. |
| `InfoBar/Presets.lua` | Expose and apply the canonical Toxi-style mapping. |
| `InfoBar/Providers/Time.lua` | Clock content and its timer within the assigned host. |
| `UI/Skin.lua`, `UI/DebugPanel.lua` | Existing reusable bootstrap skinning controls. |
| `EnhancedResourceBars/Core.lua` | Unchanged stub; no host integration or gameplay UI. |

The namespace retains `RegisterModule(name, module)` and `GetModule(name)`. Providers belong to InfoBar's small registry rather than the addon-level module registry.

## Public integration contract

**EUIAdapter is the only EllesmereUI integration boundary.** Other components do not inspect that addon's globals, saved settings, frames, or implementation details. The adapter receives the public Skinning API from `EllesmereUI.RegisterSkin`, checks its version/enabled state, and guards callable methods. See the official [Skinning API reference](https://github.com/EllesmereGaming/EllesmereUI/blob/main/SKINNING_API.md).

The bootstrap panel retains public shell/control/font/status-bar styling. InfoBar uses ordinary owned frames and a simple background, with public `GetPanelColor`, `GetAccentColor`, and `GetFont` values. It does not style slots as button cards. Ready and looks-change callbacks refresh colors and clock fonts without rebuilding providers. Missing, disabled, or unsupported public styling has local fallbacks. If disabling skinning emits no callback, custom appearance may retain its last state until another apply or reload.

| Capability | Meaning |
| --- | --- |
| `eui` | EllesmereUI is present. |
| `skinAPI` | A supported public Skinning API is available and enabled. |
| `skinAPIVersion` | Received valid version, or `0`. |
| `dataBarsExtensionAPI` | Always `false`; no extension contract is used. |
| `resourceBarsExtensionAPI` | Always `false`; no host contract is used. |
| `optionsRegistrationAPI` | Always `false`; configuration uses existing commands. |

The public registration and appearance APIs have no unregister operation. The adapter retains one stable session bridge and borrowed public handle. Disable removes Orbit listener closures and suppresses dispatch. Re-enable reuses those bridges without duplicate external callbacks.

## InfoBar runtime

Enable repairs settings, registers combat/display/scale events, applies geometry and assignments, updates visibility, and subscribes to appearance changes. Repeated Enable is idempotent. Disabled settings can be edited without creating an active bar.

Layout builds frames once. `Calculate(width, height, spacing)` returns pure geometry for offline tests. Three equal regions anchor independently to the bar, each with three equal cells. The center region and its second slot use centered anchors; provider text cannot affect them. Width `0` resolves to `UIParent` width minus `24`; fixed requests are capped to the same available width for rendering. Narrow layouts reduce effective spacing to retain positive, distinct slots.

Registry maps saved keys to stable hosts. Missing providers remain silent; the first duplicated key wins in deterministic slot order. Each provider has one cached instance and at most one active assignment. Apply reuses its host and calls Refresh without repeating active Enable. Failed factories are also cached to prevent repeated frame allocation on resize.

The contract is `InfoBar:RegisterProvider(key, factory)`, with `factory:Create(host, settings)` returning an instance. Create only builds UI; Enable acquires runtime resources. Instances implement Enable, Disable, and Refresh, with optional OnEnter, OnLeave, and OnClick. Registry rejects incomplete contracts and instances shared across keys, updates `instance.settings`, and isolates callbacks with `pcall`. Providers own content inside the host; Layout owns global geometry. Registry also cleans resources tracked through `ns.Events` for each detached instance.

The bar and slots receive pointer motion with clicks disabled by default. Registry enables slot clicks only for an active OnClick handler. Time has no click action.

## Visibility and lifecycle

| Policy | Enabled behavior |
| --- | --- |
| ALWAYS | Shown at full alpha. |
| NO_COMBAT | Hidden in combat; combat events update state. |
| MOUSEOVER | Shown at alpha zero away from the pointer; entry/leave and a native mouse-over query reveal it. |

MOUSEOVER uses no timer or per-frame cursor polling. Visibility affects only InfoBar and does not stop Time. Disable hides the complete bar, removes theme listeners and runtime events, cancels provider timers, clears assignments and temporary settings references, and hides debug overlays. Frames and instances remain reusable for the session.

Time uses one `ns.Events:Every(instance, 1, callback)` ticker. It samples local time once per update or reads the server clock, and only changes displayed strings when needed. Cleanup cancels the ticker and invalidates queued callbacks. Hover changes one existing texture's alpha without allocating visual objects.

Client API signature research uses Blizzard's mirrored [timer declarations](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/UITimerDocumentation.lua), [TimeManager clock usage](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_TimeManager/Mainline/Blizzard_TimeManager.lua), and [script-region mouse APIs](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleScriptRegionAPIDocumentation.lua). These references do not substitute for client validation.

## Settings

`CarGOOrbitDB` remains the only saved variable. Schema `2` extends `profile.infoBar` with placement, dimensions, background, visibility, mapping, and provider settings. Known InfoBar containers and values are repaired in place; valid preferences and unknown fields remain. Existing Enhanced Resource Bars data is unchanged and receives no migration.

Reset restores known InfoBar defaults and preset slots while preserving enabled state and unknown fields. Slot debug is transient and separate from saved debug logging. This remains one settings container without profile selection or import/export. See [InfoBar defaults](INFOBAR_SPEC.md#saved-settings).

## Validation boundary

Static checks cover TOC paths/order, integration boundaries, and prohibited patterns. The runner compiles addon and test code as Lua 5.1 before mocked execution. Tests cover repair, presets, geometry, assignments, formats/sources, visibility, commands, repeated activation, fallback, and cleanup.

Mocks do not validate Retail pixels, pointer delivery, font metrics, theme rendering, or compatibility. The [manual checklist](../README.md#manual-retail-checklist) remains unverified; no in-game success is claimed.
