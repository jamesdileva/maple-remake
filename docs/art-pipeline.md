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
