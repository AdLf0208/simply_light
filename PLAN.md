# Simply Light — slice 1 plan (content/data carry)

Goal: register all **160** Simply Light light blocks as a Horizon content mod at
pin `1d63e0a`, with the upstream states, light levels, drops, recipes, tags,
lang and creative tab; verify in-game.

## Facts locked by the analysis

- Jar `simplylight-1.5.3+1.21.1-b4.jar`, SHA-1 `d85bfed3…3223` (pack record),
  MIT; kept in `ports/_shared/carry-work/simplylight/`.
- Upstream `Flanks255/simplylight` @ `1a465c7`, `gradle.properties` MC 1.21.1.
- 160 blocks = 10 families × 16 colours:
  `illuminant_block[_on]` (on bool, light 0/15), `illuminant_panel`,
  `illuminant_slab`, `wall_lamp`, `lightbulb`, `rodlamp`, `lamp_post`
  (position enum, light 15 only on top), `edge_light`, `edge_light_top`
  (4 side booleans + waterlogged, light 14).
- Carried by `horizon-port-pack check`: 112 declarations (guessed templates),
  160 26.3 loot tables, 160 item definitions, 151 recipes. Left out: the 32
  `illuminant_block*` (`on` property) and 16 `lamp_post` (`position`), plus 83
  recipes that named them — the generator declares those by hand.
- Loot is already the 26.3 typed shape (`"condition": {"type": …}`); verify.

## Decisions

1. **Templates** (chosen from the 26.3 `model-states.json` + interfaces, not
   guessed):
   - panel/slab/wall_lamp/lightbulb → `minecraft:amethyst_cluster`
     (facing 6 × waterlogged 2, SimpleWaterloggedBlock).
   - rodlamp → `minecraft:iron_chain` (axis 3 × waterlogged 2,
     SimpleWaterloggedBlock).
   - edge_light[_top] → `minecraft:oak_fence` (4 booleans × waterlogged,
     SimpleWaterloggedBlock).
   - lamp_post → `minecraft:mangrove_roots` (waterlogged only) + declared
     `position` enum.
   - illuminant_block[_on] → `minecraft:calcite` (stateless cube) + declared
     `on` boolean.
2. **Shapes** declared from upstream's `getShape` boxes; `collision_shapes:
   {"default": []}` for the three `noCollission()` families.
3. **Light** per block id: 15 (panel, slab, wall lamp, rod, lamp post,
   illuminant on), 14 (bulb, both edge lights), 0 (illuminant off).
4. **Recorded gap:** `properties.light` is scalar, so every `lamp_post`
   position emits 15 (upstream: only `top`); the e2e pins it.
5. Recipes: 151 carried + the 83 re-shaped from the jar (`{"tag"/"item"}` →
   `"#tag"/"id"`); supply `c:stones`, `c:dusts/redstone`,
   `c:dusts/glowstone` by hand.
6. Deferred to a native slice (recorded in notes): redstone toggle of the
   illuminant blocks, the 3-block lamp-post placement, the edge-light
   neighbour morph and its sneak-use editor GUI, tooltips/tab icon parity,
   the optional CTM resource pack, head-slot equipping and the lamp-post
   item's attack attributes.

## Steps

1. `tools/gen_content.py` writes `content/{assets,data}` + `horizon-mod.toml`
   deterministically from the jar and the carry output.
2. `cargo horizon-mod build` → `content/simplylight.hmod`; `check` says
   `no code`.
3. Test-only `mixins/simplylight/runtime.rs` (census: ids, families, light,
   state sizes, drops) + `.hnmod` beside `content/`.
4. `tools/e2e.sh` (default / COUNTERFACTUAL / NEGATIVE / SELFTEST) on the
   shared unmodded game; `tools/hmod-load.sh` proves the package loads and the
   no-package control refuses the ids.
5. `notes.md` with class/tier, licence, gaps, verification table, `Skills:`.
