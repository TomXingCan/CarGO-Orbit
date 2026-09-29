# CarGO Orbit

CarGO Orbit is a companion extension for EllesmereUI.

**0.1.0** adds an Orbit-owned InfoBar with nine logical slots, an independently centered clock, a small provider registry, and local configuration commands. Time is the only implemented provider. InfoBar is disabled by default; run `/orbit infobar` to enable it.

- Requires EllesmereUI and World of Warcraft Retail, interface `120100`.
- Not affiliated with EllesmereUI; does not bundle or modify its files.
- Uses documented public integration APIs through one adapter.
- CarGO UI and CarGO Orbit are separate addons.
- Enhanced Resource Bars remains a lifecycle stub.

## Installation

Install EllesmereUI separately. Copy this repository's `CarGO_Orbit` directory into `World of Warcraft/_retail_/Interface/AddOns/`, so the manifest is at `Interface/AddOns/CarGO_Orbit/CarGO_Orbit.toc`. Enable both addons in Retail. Classic and other client variants are unsupported.

The repository name is `CarGO-Orbit`; the installed addon directory is `CarGO_Orbit`.

## InfoBar

The default bar sits at the bottom, uses available screen width with a 12-unit outside margin on each side, and has height `30`, spacing `20`, and a faint dark background. Each of the three regions has three slots. Center slot 2 remains at the bar's geometric center regardless of other content.

| Slot | Left | Center | Right |
| --- | --- | --- | --- |
| 1 | MicroMenu | Travel | XPRep |
| 2 | Empty | **Time** | Currency |
| 3 | Durability | Spec | System |

Only Time renders content. Other provider keys remain saved and their slots stay empty without warning text. The clock defaults to local time, 24-hour `HH:MM`, font size `32`, and vertical offset `1`. It uses one one-second ticker while enabled. Narrow hosts reduce the rendered font without changing the saved size or moving the center.

## Commands

Both `/orbit` and `/cgo` accept these commands. Values are validated before saving.

| Command | Behavior |
| --- | --- |
| `status` | Print version, module state, provider count, preset, and public capabilities. |
| `debug` | Toggle saved debug logging. |
| `panel` | Toggle the existing bootstrap skinning test panel. |
| `infobar` | Toggle InfoBar and save its enabled state. |
| `infobar debug` | Toggle session-only slot outlines and labels, independently of logging. |
| `infobar reset` | Restore known settings and the default mapping; preserve enabled state and unknown fields. |
| `infobar help` | Print the InfoBar command summary. |
| `infobar position top/bottom` | Choose the screen edge. |
| `infobar width 0` | Use available screen width. |
| `infobar width 240..10000` | Set requested width; effective width is capped to available screen width. |
| `infobar height 16..100` | Set bar height. |
| `infobar spacing 0..100` | Set slot spacing; narrow layouts cap effective spacing. |
| `infobar visibility always/no_combat/mouseover` | Choose the display policy. |
| `infobar time local/server` | Choose the clock source. |
| `infobar time 12/24` | Choose hour format; no AM/PM secondary text. |
| `infobar font 8..64` | Set requested clock font size. |
| `infobar offset -40..40` | Set clock vertical offset. |
| `infobar background on/off` | Enable or disable the background. |
| `infobar background 0..1` | Set background alpha. |

Use one value from a slash-separated choice or one number from a range; for example, `/orbit infobar position top` and `/orbit infobar height 36`.

`ALWAYS` shows the enabled bar. `NO_COMBAT` hides it during combat. `MOUSEOVER` retains a transparent motion-sensitive region and reveals it on entry without cursor polling. Empty slots and Time allow clicks through; a future provider receives clicks only when it implements a click handler. Visibility does not stop the Time ticker; disabling InfoBar cancels its runtime resources.

## Integration and saved settings

`CarGO_Orbit/Core/EUIAdapter.lua` is the only EllesmereUI integration boundary. It registers through the public [Skinning API](https://github.com/EllesmereGaming/EllesmereUI/blob/main/SKINNING_API.md). InfoBar owns its frames and background and reads public font, accent, and panel colors through the adapter. Supported appearance notifications refresh the existing bar and clock. Unavailable public styling has standard client font and local color fallbacks. If disabling third-party skinning supplies no notification, custom elements can retain their last appearance until a settings apply or reload.

DataBars extension, Resource Bars extension, and native options registration capabilities remain `false`. The separate bootstrap panel exercises public controls; it is not an options UI. The public API has no callback-unregistration operation, so the adapter keeps one session bridge and removes Orbit listeners when disabled.

Only `CarGOOrbitDB` is owned by this addon. Schema version `2` extends `profile.infoBar` in place with layout, appearance, visibility, and Time settings. Migration repairs known InfoBar fields, retains unknown fields and valid preferences, and leaves existing Enhanced Resource Bars data unchanged. Complete defaults are in the [InfoBar specification](docs/INFOBAR_SPEC.md). Profiles and import/export remain outside scope.

## Development and validation

Development is managed on GitHub through feature branches and Draft pull requests. Keep changes off `main` until review is complete.

The [Validate workflow](https://github.com/TomXingCan/CarGO-Orbit/actions/workflows/validate.yml) runs on pushes and pull requests. GitHub-hosted runners use Python 3.12 and Lupa 2.8's Lua 5.1 runtime to execute `python tests/run.py`. Dependencies stay in the runner environment and are not bundled with the addon.

Checks cover schema migration, preset mapping, pure geometry, provider lifecycle, clock formatting and sources, visibility, commands, public API fallback, TOC paths, and Lua 5.1 syntax. Mocks cannot establish game-client rendering or compatibility.

### Manual Retail checklist

**Unverified:** Retail execution has not been performed for `0.1.0`.

1. Install with EllesmereUI and run `/reload`; confirm no Lua errors. Existing users retain valid settings; new users start with InfoBar disabled.
2. Run `/orbit status` and `/cgo status`; confirm provider count `1`, preset `toxi`, and the three unsupported extension capabilities.
3. Enable `/orbit infobar`; confirm a centered clock and no placeholder text in the other eight slots. Disable it and confirm the entire bar disappears.
4. Toggle `/orbit infobar debug`; inspect all nine distinct slots, then turn it off and confirm outlines and labels disappear.
5. Test top/bottom, full/fixed widths, height, spacing, window resizing, and UI scale changes. Center slot 2 must remain centered. Narrow clocks should fit their host.
6. Switch local/server and 12/24-hour formats; compare with the appropriate client clock. Test font size, offset, and minute rollover.
7. Test all three visibility modes. Enter/leave combat for `NO_COMBAT`; move onto/away from the transparent region for `MOUSEOVER`. Confirm ordinary clicks pass through Time and empty slots.
8. Change EllesmereUI font/accent/theme and verify supported updates. Disable third-party skinning, reload, and confirm the bar still works with fallback styling.
9. Change settings, reload, and confirm persistence. Run `infobar reset`; confirm defaults return while enabled state is preserved. Verify Enhanced Resource Bars settings remain unchanged.
10. Repeatedly toggle and resize using a development harness; verify one active ticker, no duplicated handlers, and timer/listener cleanup on disable. Recheck the existing `/orbit panel` controls.

See [architecture](docs/ARCHITECTURE.md), the [InfoBar specification](docs/INFOBAR_SPEC.md), and the [roadmap](docs/ROADMAP.md). The next milestone is `0.1.x` InfoBar core providers; no later milestone is implemented here.

Project-owned source is **All Rights Reserved**, copyright (c) 2026 Tom Sheng (TomXingCan). See [LICENSE](LICENSE) and [NOTICE.md](NOTICE.md).
