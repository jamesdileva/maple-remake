# Art Production Pipeline

Agent-assisted pipeline that turns a mob **spec** into game-ready sprites with a
single command. It implements the flow from `docs/content-bible.md` §12:

```text
spec  ->  concept  ->  human approval  ->  Blender render  ->  atlas  ->  Godot
```

Nothing is imported into the game until a human approves the concept, so the
"human approval gate before assets enter the game" rule is enforced by the tool.

## Requirements

- Blender 5.x on `PATH`, in a default install location, or `BLENDER_PATH` set.
- Python 3 with Pillow (`pip install pillow`).
- Godot 4.x (`godot` on `PATH`; the pipeline reuses the running binary).

## One command

```powershell
godot --headless --script tools/art/run_pipeline.gd -- --spec meadow_slime
```

Running it without an approval file prints `APPROVAL_REQUIRED`, writes the
concept board to `art_src/concept/<id>_concept.png`, and exits with code 2. After
reviewing the board, approve by creating `tools/art/specs/<id>.approved` and run
the same command again. It then renders, packs, imports and saves the sprite
resources, ending with `PIPELINE_OK <id>`.

## Stages

| Stage | Tool | Output |
| --- | --- | --- |
| Spec | `tools/art/specs/<id>.json` | palette, shape, animation curves, effect |
| Concept | `tools/art/concept.py` | `art_src/concept/<id>_concept.png` |
| Approval | `tools/art/specs/<id>.approved` (human) | gate for the next stages |
| Render | `tools/art/blender/build_mob.py` | `art_src/<id>/{mob,effect}/**/*.png` + `manifest.json` |
| Pack | `tools/art/pack_atlas.py` | `assets/art/mobs/<id>.{png,json}`, `assets/art/effects/*` |
| Integrate | `tools/art/build_spriteframes.gd` | `data/visuals/<id>_frames.tres` |

Blender builds a mesh, rigs it with a single deform bone and keyframes
squash/stretch, lean and hop curves from the spec, then renders transparent PNGs
with Workbench (flat studio shading, object outline). The packer concatenates
frames per animation into one horizontal atlas row and emits frame rectangles.

## Adding a mob

1. Copy `tools/art/specs/meadow_slime.json` to `tools/art/specs/<id>.json` and
   edit the palette, shape, curves and animation frame counts.
2. Run the pipeline (see above) and approve the concept board.
3. Wire the result into the mob definition:
   ```
   sprite_frames = <res://data/visuals/<id>_frames.tres>
   hit_effect = <res://data/visuals/<effect_id>_frames.tres>
   sprite_offset = Vector2(0, -8)   # align the art's feet with the collision body
   ```
   `Mob` plays `idle`/`hop` while moving, `attack` on a contact hit (spawning the
   effect) and `hit` on damage. Definitions without `sprite_frames` keep the
   `Visual/Body` placeholder, so art can land mob by mob.

## Outputs

`SpriteFrames` resources are consumed by `Mob` through
`MobDefinition.sprite_frames`; effects are `SpriteFrames` played by the generic
`scenes/effects/sprite_effect.tscn`. Both are the only hand-off points, so new
mobs need no script changes.

Renders and manifests stay in `art_src/` (git-ignored, `.gdignore`'d). The
committed artifacts are the atlas PNG/JSON and the `.tres` resources.

## Environment kits

Environment regions go through the same flow, sharing one prop builder:

```powershell
godot --headless --script tools/art/run_env_pipeline.gd -- --kit sunlit_meadow
```

| Stage | Tool | Output |
| --- | --- | --- |
| Spec | `tools/art/env_specs/<id>.json` | palette + prop list (name, archetype, scale) |
| Concept | `tools/art/concept.py` | `art_src/concept/<id>_concept.png` |
| Approval | `tools/art/env_specs/<id>.approved` (human) | gate for the next stages |
| Render | `tools/art/blender/build_env.py` | `art_src/env/<id>/props/*.png` + `manifest.json` |
| Pack | `tools/art/pack_env.py` | `assets/art/env/<id>.{png,json}` |
| Integrate | `tools/art/build_env_kit.gd` | `data/env/<id>_kit.tres` |

Every prop is one archetype from a single shared table (tree, bush, rock, grass,
flower, mushroom, fern, crystal, ore, pillar, broken_pillar, crate, barrel,
lantern, building, sign, beam, cart, torch, battlement, spike, banner, rubble,
altar, tentacle, dead_tree). A region kit is therefore just a **palette plus a
prop selection** — variation comes from colour and placement, never from a forked
builder. Each Blender render is auto-framed, and the manifest records the prop's
feet (bottom-centre) pivot in pixels so sprites anchor to the ground.

Kits are the seven region kits (`brightwood_outskirts`, `sunlit_meadow`,
`whispering_forest`, `hollow_forest`, `forgotten_mine`, `ruined_settlement`,
`haunted_fortress`); `blightheart_sanctum` and `thornhollow_ring` reuse them.

## Decor placement

`data/decor/<map_id>.tres` is a `DecorPlan`: a kit reference plus parallel arrays
of prop names, positions, scales and flips. Maps instance
`scenes/world/prop_layer.tscn` with that plan; `PropLayer` builds the sprites at
load and reports an `env_decor` debug event. Unknown prop names are skipped and
recorded rather than crashing, so a plan can reference a kit prop that does not
exist yet.

To dress a new map: add a `data/decor/<map_id>.tres`, then add a `PropLayer` node
with `plan` pointing at it. No code changes.
