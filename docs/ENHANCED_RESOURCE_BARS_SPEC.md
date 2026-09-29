# Enhanced Resource Bars direction

## Current scope

`0.0.1-dev` contains only `IsEnabled()`, `Enable()`, and `Disable()` lifecycle methods. The module is disabled by default. Enabling it records **enabled-but-no-host** because `resourceBarsExtensionAPI` remains `false`.

It does not search for host frames, attach to resource bars, draw overlays, calculate predictions, or hook rebuild/update behavior. No private fallback is permitted.

## Hard requirements

CarGO Orbit MUST NOT:

- Change EllesmereUI's real resource value.
- Replace EllesmereUI resource calculation.
- Write EllesmereUI saved variables.
- Monkey-patch EllesmereUI update functions.
- Infer secret values from visual state, including widths, text, textures, or animation.
- Depend on undocumented private EllesmereUI internals.

Orbit also must not read EllesmereUI saved settings to obtain resource state or configuration. A function's presence in source code does not establish a public extension contract.

## Future data flow

```text
Observe public game state
    -> calculate CarGO-owned enhancement
    -> draw CarGO-owned overlay
    -> visually attach to an EUI resource bar only when
       a supported, stable host contract exists
```

All direct EllesmereUI interaction must pass through `Core/EUIAdapter.lua`. The module owns its calculations, frames, overlays, subscriptions, and cleanup. Public game data must be usable under the client's restrictions; visual output must never be used to reconstruct restricted values.

If a required API is absent, unsupported, or restricted, report the capability as unavailable and leave the dependent feature inactive. The rest of the addon must continue working.

## Later validation gates

The host/overlay proof of concept requires a documented public host contract, explicit ownership of overlay lifecycle, and an in-game compatibility check. Resource predictions require separate validation for each supported class/resource mechanic before being presented as reliable.

Some intended behavior resembles Twintop's Resource Bar. All code and assets must be independently created; that project's source and assets are not included.
