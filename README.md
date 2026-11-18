# Simply Light — a Horizon port

**Simply Light** is a Minecraft mod. Simply Light. This repository is a **port of it to [Horizon](https://github.com/horizon-rust/horizon)**, the Rust engine for Minecraft Java 26.3. It carries the complete source of the port plus the content files it ships, and installs as a single `.hmod` package.

Upstream: [Flanks255/simplylight](https://github.com/Flanks255/simplylight) — licence **MIT**.

| | |
|---|---|
| Upstream mod | Simply Light ([source](https://github.com/Flanks255/simplylight)) |
| Ported to | Horizon 0b14f8a, Minecraft Java 26.3, mod API `0.2` |
| Package | `simplylight.hmod` (install it with the Horizon launcher) |
| Licence | **MIT** — the upstream mod's licence; see [Licence and credit](#licence-and-credit) |

## What this port implements

- **160 blocks** = 10 families × 16 colours, all registered with a block item;
- `LampBlock` (`illuminant_block` / `illuminant_block_on`): the block id is the
- `ThinLamp` (panel thickness 4/16, slab 8/16), `Fixture` (wall lamp),
- `LampPost`: `position` (bottom/middle/top) × `waterlogged`, placed as a
- `EdgeLight`/`EdgeLightTop`: four side booleans × `waterlogged`, light 14,
- Loot: `dropSelf` for every block; recipes: 234 total (block, bulb, edge,
- Tooltips: `BaseBlockItem.appendHoverText` prints `block.simplylight.<id>.info*`
- **Panel/slab/wall lamp/bulb need a support and break without it.** They copy

## Not yet ported

- **Redstone toggle of the illuminant blocks** (`neighborChanged`,
- **The 3-block lamp-post column** (place/remove cascade) and its per-position
- **The edge-light sneak-use editor GUI** (screen + network packet) and the
- **Tooltips** (`appendHoverText`, the shift hint and `.info*` lang keys) —
- **Item behaviour**: the lamp-post item's `+4.0` attack damage and the
- **Fluid behaviour was not exercised**: the waterlogged *states* bind and the
- **The optional CTM resource pack** (`optional_fullblock_ctm`, a built-in
- **No JEI plugin** (upstream ships one); Horizon's recipe viewer is built in.

## Installing

1. Install the [Horizon launcher](https://github.com/horizon-rust/horizon/releases) (0.2.70 or newer).
2. Add `simplylight.hmod` to the instance's mods.
3. The package is pinned to a specific Horizon build; the launcher checks that pin.

## Licence and credit

Simply Light was created by its upstream authors; the code, models and assets in the original mod
remain theirs and are used here under **MIT**. The Rust in this repository is a clean-room
rewrite for Horizon, not a translation of the original source.

- `LICENSE` — the upstream licence text.
- `LICENSE-NOTICE.md` — what this port carries and where it came from.
- The upstream project: https://github.com/Flanks255/simplylight

## Technical details

```
horizon-mod.toml   package manifest (id, version, api, [native] pin)
Cargo.toml         the crate; depends on `horizon-mod-api` from the fetched SDK
src/               lib.rs (the one `impl Hooks`), runtime.rs (pure logic + tests), glue
assets/ data/      the content the package ships
tools/             content generators and the e2e scenario
```

- Build: `cargo horizon-mod build` (packages; it does not compile against the game).
- Test: `cargo test`, `cargo clippy --all-targets -- -D warnings`.
- In-game: `ports/tools/launcher-game.sh run simplylight` in the campaign tree, or install the
  `.hmod` and play; the harness scenario is `tools/e2e.sh`.

This repository is generated from the campaign's port at `ports/simplylight/`; the port's own
`notes.md` is the full record (decisions, traps, evidence).
