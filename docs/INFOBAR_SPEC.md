# InfoBar foundation

## Current scope

`0.1.0` implements an Orbit-owned information bar, nine-slot geometry, a small provider registry, and one real Time provider. InfoBar is disabled by default and enabled with `/orbit infobar`. Enhanced Resource Bars remains unchanged.

The visual direction is a thin bar with a faint dark background, ordinary text around size `16`, and a larger clock around size `32`. Slots have no visible button borders. Hover only brightens slightly. Outlines and labels require explicit `infobar debug` and are separate from debug logging.

## Layout and preset

| Region | Slot 1 | Slot 2 | Slot 3 |
| --- | --- | --- | --- |
| Left | MicroMenu | Empty (`""`) | Durability |
| Center | Travel | Time | Spec |
| Right | XPRep | Currency | System |

The `toxi` mapping is the frozen default. ToxiUI WunderBar is a product reference, not an implementation dependency; no code, artwork, font, or branding is bundled. Only Time is registered. Other logical keys persist without placeholder text or errors.

Defaults are Bottom, height `30`, spacing `20`, and auto width (`0`). Auto width is screen width minus `24`, giving 12-unit outside margins. Inner padding of up to `12` separates slots from the bar ends. Requested fixed width remains saved and is capped to available screen width when rendered.

Nine equal-width slots have geometry independent of provider text. Each three-slot region anchors directly to the bar. The Center region and Center slot 2 use centered anchors, so long side content cannot move Time. Narrow layouts reduce effective spacing to retain positive, distinct hosts. Providers own content within their host; Time reduces rendered font size if needed without changing its saved request.

`Layout:Calculate(width, height, spacing)` returns pure region and slot geometry. Runtime frames are built once and reused. Display and UI-scale events reapply layout without rebuilding the provider tree.

## Provider contract

```lua
InfoBar:RegisterProvider("Example", factory)

function factory:Create(host, settings)
    return instance -- content belongs inside host
end

function instance:Enable() end
function instance:Disable() end
function instance:Refresh() end
-- Optional: OnEnter(), OnLeave(), OnClick(button).
```

Registry owns assignment and attachment. It passes settings at creation and updates `instance.settings` before activation or refresh. Providers do not resize or reposition global slots. Enable/Disable must be idempotent; Disable releases owned events and timers.

Create only builds owned UI; events and timers start in Enable, after the registry can track the returned instance. Incomplete instance contracts and the same instance returned under multiple keys are rejected.

Duplicate registrations are rejected. Each key has at most one cached instance and one active assignment. If slots repeat a key, the first in Left/Center/Right order wins. Missing providers are safe empty slots. Apply refreshes active instances without repeating Enable; disable/re-enable reuses their frames.

Lifecycle and interaction methods use `pcall` to isolate failures. Registry also cleans instance resources tracked through `ns.Events` and detaches the host. Failed creation is cached to avoid repeated allocation. Empty slots and providers without OnClick allow clicks through while retaining pointer motion for visibility.

## Time

- Defaults: local time, 24-hour `HH:MM`, font size `32`, vertical offset `1`.
- Local mode samples hour/minute together from the client machine; server mode uses the game clock.
- 12-hour output uses `01` through `12`; midnight and noon both display `12`. No AM/PM secondary label.
- Hour, colon, and minute are separate FontStrings in symmetric fixed cells. The colon stays centered and uses public accent color when available.
- Font follows the adapter getter with a standard client fallback. Narrow hosts reduce rendered size while preserving the saved request.
- One one-second ticker runs while enabled. Repeated Enable/Apply does not duplicate it. Disable cancels it and invalidates queued work.
- Strings update only when necessary. There is no per-frame refresh or digit-dependent dynamic width.

Date, mail, AM/PM secondary information, invite pulses, resting animation, calendar/reload clicks, and dynamic text width remain future work.

## Saved settings

Schema version `2` extends the bootstrap table in place:

```lua
profile.infoBar = {
    enabled = false,
    position = "BOTTOM",
    width = 0,
    height = 30,
    spacing = 20,
    visibility = "ALWAYS",
    background = { enabled = true, alpha = 0.25 },
    layout = {
        preset = "toxi",
        slots = {
            left = { "MicroMenu", "", "Durability" },
            center = { "Travel", "Time", "Spec" },
            right = { "XPRep", "Currency", "System" },
        },
    },
    providers = {
        Time = {
            localTime = true,
            twentyFour = true,
            fontSize = 32,
            offsetY = 1,
        },
    },
}
```

Repair fills defaults, fixes malformed known containers/types, validates choices/ranges, and preserves unknown keys and valid preferences. Repeating migration is safe. Existing `enhancedResourceBars` data remains unchanged, including data outside its expected shape.

Reset restores known settings and preset slots while preserving InfoBar's enabled state and unknown fields. Slot debug is session-only and independent of saved `profile.debug`. Profile selection and import/export are absent.

## Visibility and configuration

`ALWAYS` shows the enabled bar. `NO_COMBAT` hides it during combat using combat events. `MOUSEOVER` keeps the frame shown at zero alpha; pointer entry/leave and a native mouse-over query reveal it without polling. These policies affect only InfoBar. Visibility does not stop the clock; disabling the module stops resources and hides the entire bar. RESTING is not implemented.

The existing `/orbit` parser, also available as `/cgo`, handles toggle, debug, reset, placement, dimensions, visibility, clock source/format/font/offset, and background. See the [command table](../README.md#commands). Status includes enabled state, provider count (`1`), and preset (`toxi`). No second parser or native options registration is introduced.

## Acceptance and boundaries

Offline checks cover repair, mapping, nine distinct slots, center invariants, duplicate/missing providers, timers, formatting/source, repeated activation, visibility, commands, fallback, static boundaries, TOC validity, and Lua 5.1 syntax.

Retail execution is **unverified**. Complete the [manual checklist](../README.md#manual-retail-checklist), including reload, rendering, pointer behavior, combat, themes, resize, and repeated disable/re-enable. EllesmereUI remains a required installed/enabled dependency even though public skinning can be unavailable.

Other providers, LDB, professions, Enhanced Resource Bars, resource prediction, native options, drag-and-drop layout, secure flyouts, and import/export are outside `0.1.0`. All EllesmereUI access remains behind `Core/EUIAdapter.lua` and documented public APIs.
