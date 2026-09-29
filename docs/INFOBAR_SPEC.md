# InfoBar direction

## Current scope

`0.0.1-dev` contains only a lifecycle stub with `IsEnabled()`, `Enable()`, and `Disable()`. It saves the enabled setting and emits debug output when appropriate. It creates no information bar, layout, information modules, or gameplay behavior.

## Product direction

Build an independently implemented, thin information bar positioned at the bottom or top of the screen. Use EllesmereUI's visual language through the public adapter. Organize the bar into three visual zones.

The initial Toxi-style preset concept is:

| Left | Center | Right |
| --- | --- | --- |
| MicroMenu · Empty · Durability | Travel · Time · Spec | XP/Rep · Currency · System |

This is a behavior and product reference to ToxiUI WunderBar, not an implementation dependency. Do not copy ToxiUI code, assets, fonts, or branding. The entries above are future design candidates, not working modules in this version.

## Boundaries

- Send all EllesmereUI styling requests through `EUIAdapter`.
- Own the bar's frames, layout, module state, and event subscriptions.
- Use documented public game data and integration APIs.
- Avoid assumptions about EllesmereUI's own DataBars or options implementation.
- Release owned events, timers, and listeners when disabled.

Detailed interactions, module contracts, configuration, and layout behavior belong to the `0.1.0` foundation work. This bootstrap does not implement them.
