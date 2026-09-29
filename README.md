# CarGO Orbit

CarGO Orbit is a companion extension for EllesmereUI.

**0.0.1-dev** establishes the addon lifecycle, saved settings, public API adapter, diagnostics, and a small skinning test panel. InfoBar and Enhanced Resource Bars are lifecycle stubs; this version does not implement their planned gameplay features.

- Requires EllesmereUI and World of Warcraft Retail, interface `120100`.
- Not affiliated with EllesmereUI.
- Does not bundle EllesmereUI or modify its files.
- Only documented public integration APIs are used at this stage.
- CarGO UI and CarGO Orbit are separate addons.

## Installation

Install EllesmereUI separately. Copy this repository's `CarGO_Orbit` directory into `World of Warcraft/_retail_/Interface/AddOns/`, so the addon manifest is at `Interface/AddOns/CarGO_Orbit/CarGO_Orbit.toc`. Enable both addons in the Retail client. Classic and other client variants are unsupported.

The repository name is `CarGO-Orbit`; the installed addon directory is `CarGO_Orbit`.

## Commands

Both `/orbit` and `/cgo` accept the following commands:

| Command | Behavior |
| --- | --- |
| `status` | Print version, module state, and public integration capabilities locally. |
| `debug` | Toggle debug logging and save the setting. |
| `panel` | Show or hide the bootstrap skinning test panel. |

The test panel exercises Orbit-owned controls through the adapter. It is not an options UI. Theme-dependent custom drawing reads current public colors when refreshing. If public skinning is unavailable at creation, standard client controls remain usable.

## Integration boundary

`CarGO_Orbit/Core/EUIAdapter.lua` is the only EllesmereUI integration boundary. It registers through `EllesmereUI.RegisterSkin` and uses the public Skinning API. The public contract is documented in [EllesmereUI's Skinning API reference](https://github.com/EllesmereGaming/EllesmereUI/blob/main/SKINNING_API.md).

DataBars extension, Resource Bars extension, and native options registration capabilities remain `false`. Their presence is never inferred from implementation details. Enabling the resource-bar stub only records `enabled-but-no-host`; it does not attach to another addon's frames.

The public contract has no callback-unregistration method. The adapter retains a stable callback bridge and a borrowed public skin API reference for the session, clears Orbit-owned listeners on disable, and suppresses callback dispatch while disabled. See [architecture](docs/ARCHITECTURE.md) for lifecycle details.

## Saved settings

Only `CarGOOrbitDB` is owned by this addon:

```lua
CarGOOrbitDB = {
    profile = {
        debug = false,
        infoBar = { enabled = false },
        enhancedResourceBars = { enabled = false },
    },
    meta = { schemaVersion = 1 },
}
```

Initialization fills missing defaults and preserves unknown fields. Profiles, import, and export are outside this stage. Orbit does not read or write EllesmereUI's saved settings.

## Validation

From the repository root:

```text
python tests/static_scan.py
python tests/run.py
```

The Python runner requires Python 3.9+ and the `lupa.lua51` module; it also recognizes a local installation under the ignored `.tools/python` directory. A development-only local installation can be made with `python -m pip install --target .tools/python lupa`. If a standalone Lua 5.1 executable is available, the harness can instead be run with `lua5.1 tests/run.lua`, alongside the separate static scan. Test tooling is not installed or bundled with the addon. Static checks and mocked execution do not establish Retail compatibility.

### Manual Retail checklist

In-game validation has not been performed for this bootstrap.

1. Load with a current EllesmereUI installation and confirm there are no Lua errors.
2. Run `/orbit status` and `/cgo status`; verify the skinning state and the three unsupported extension capabilities.
3. Run `/orbit debug`, reload the UI, and confirm the setting persists in `CarGOOrbitDB`.
4. Open `/orbit panel`; inspect the panel, button, checkbox, edit box, status bar, and font sample.
5. Change EllesmereUI accent/theme settings and verify supported styling refreshes without recreating the window.
6. Reload with EllesmereUI third-party skinning disabled; confirm diagnostics report the unavailable skin API and the test panel remains usable.
7. Exercise disable/re-enable with a development harness; verify owned events and timers are released, the panel hides, and callbacks do not dispatch while disabled.

## Planned modules

- [InfoBar](docs/INFOBAR_SPEC.md): a compact information bar using EllesmereUI's visual language.
- [Enhanced Resource Bars](docs/ENHANCED_RESOURCE_BARS_SPEC.md): independent enhancements gated on a documented host contract.
- Future combat helpers and class tools.

See the [roadmap](docs/ROADMAP.md) for milestones. These features are not implemented in `0.0.1-dev`.

Project-owned source is **All Rights Reserved**, copyright (c) 2026 Tom Sheng (TomXingCan). See [LICENSE](LICENSE) and [NOTICE.md](NOTICE.md).
