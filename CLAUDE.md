# 涌现出来了！ — notes for Claude Code

Game jam prototype (theme: 涌现 / Emergence). Godot 4.7, GL Compatibility, GDScript. Team talks in Chinese; user-facing text in the game is Chinese, deadpan 2000s-Chinese-internet tone.

Start here: `docs/HANDOFF.md` (state, architecture, tuning knobs, known issues). Design: `docs/design/`.

## Commands

- Smoke test (run after every code change, before committing):
  `godot --headless --path . -- --autopilot [--run=SECONDS] [--stages-at=T1,T2] [--fever-at=T]`
  Must print `[autopilot] DONE …` with no `SCRIPT ERROR` / `SHADER ERROR` lines.
  One known, harmless line: `ERROR: Condition "!actions.custom_samplers.has(...)"` (WordArt shader passes `TEXTURE` to a helper; renders fine).
- Screenshots (needs a display): `godot --path . -- --autopilot --shots=DIR --shots-at=2,9.5`
- Content table check: `python3 tools/validate_table.py`
- WordArt design sheet: `python3 tools/wordart_preview.py OUT_DIR`

Never chain the smoke test and `git commit` in one command without checking the output first.

## Conventions

- `content/emergence_table.csv` is the single source of truth for objects. Add behaviour as generic, data-driven behaviour (emits / collapse / eats / recipes / size / anchored), not per-object scripts. Reference other rows by their Chinese `name`.
- Everything in the world is an `EmergentBody` with physics (no static scenery except ground/roads). Rooted things use `anchored = y`.
- Spawn only through `world.spawn_body` / `spawn_after`; emitted things inherit the emitter's `size_mult`.
- All events go through `Stats` (the ledger); HUD and stage logic listen to its signals.
- Hit feel goes through `Juice` (respects `Juice.cinematic` and `Stats.no_slowmo()`).
- Match the surrounding style: tabs, typed vars where inference is ambiguous, short `##` doc comments at the top of each script.

## Gotchas

- GDScript treats "inferred as Variant" as an error here. `var x := clamp(...)`, `min/max(...)`, `def.something`, dictionary `.get()` etc. need an explicit type: `var x: float = clamp(...)`.
- Don't name methods after built-ins of the base class (e.g. `pop()` on a RichTextLabel subclass is a parse error).
- In canvas_item shaders, `COLOR` in `fragment()` already includes the texture sample; pass node modulate via a `varying` from `vertex()` if you resample `TEXTURE` at other UVs. Helper functions can't read `TEXTURE` directly — pass it as a `sampler2D` argument.
- `content/emergence_table.csv.import` must stay `importer="keep"`; Godot's default CSV import (translations) drops the file from exports.
- Opening the project in a different Godot minor version rewrites `*.import` / `project.godot`; don't commit that noise unless intended.
- Third-party art/sound in `assets/` comes from the studio's own Love-Spinnin repo; fonts are OFL/GPL-with-exception (licences in `assets/fonts/`).
