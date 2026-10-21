# Physics debugging system: shared contract

Goal: get the skating physics spot on. We need to see, record, replay, measure and live-tune every
part of the ride. Several workers build this at the same time, so each one owns its own files and codes
against the contract below. Read `docs/agent_brief.md` and `CLAUDE.md` first.

## Rules for every worker
- Only edit the files your task names. **Never edit `game/main.gd`.** Tell the lead the exact lines to add.
- Don't commit or push. The lead integrates and commits.
- Run only your own checks: `tools/run_tests.sh <test_name>`, `tools/lint.sh`, plus `tools/run_sims.sh` if you
  touched skater physics. Never wrap tools in `flock`. The box has 4 CPUs and other workers run Godot too, so
  keep Godot runs short and never leave one running.
- Godot 4.7, GDScript with typed declarations (lint enforces this). gl_compatibility renderer.
- Renders: `timeout 120 xvfb-run -a godot --rendering-driver opengl3 --path . -s <script.gd> --resolution 1280x720`.
  A `-s` SceneTree script must `load()` game classes at runtime, inside a deferred call. Otherwise autoloads
  like `Flags` aren't ready yet and the compile fails.
- Avoid pure #00FF00 in any debug colour. The player is hunting a pure-green GPU glitch.
- Never call any `mcp__hearthbot__` tool or try to message the user. Your final message goes to the lead and
  must list: the files you changed, the checks you ran with their results, and any lines for `main.gd`.

## Keys already taken
Space J K I Q E L U Esc Backspace, WASD/arrows, F4–F9, F10 (frame stamp), F11.
New keys:
- F1: physics overlay.
- F2: slow motion (cycles 1, 0.5, 0.25, 0.1).
- F3: freeze. While frozen, `.` steps one physics tick.
- F12: flight recorder dump.
- `` ` `` (backquote): tuning panel.
- C on the keyboard, or a left-stick click on a gamepad: step off or on the board (walking).

## PhysicsTuning (already written: `game/skater/physics_tuning.gd`)
- `PhysicsTuning.shared()` holds the live tuning. `FIELDS` is the list of
  `[name, default, min, max, step, group, doc]`.
- Methods: `set_value(field, v)`, `to_dict()`, `apply_dict(d)`, `diff_from_defaults()`, `reset()`,
  `save_json(path)`, `load_json(path)`.
- `signal changed(field, value)`.

## Skater additions (owned by the skater-core worker)
- `var tune: PhysicsTuning = PhysicsTuning.shared()`. Every physics number is read from `tune.<field>` each tick.
- `signal physics_ticked(frame: Dictionary)` is emitted at the end of every `_physics_process` (and on the
  respawn and early-return paths too). `frame` is the same dictionary as `debug`.
- `var debug: Dictionary`, refreshed each tick with these keys:
  - `tick` (int, ticks since `_ready`), `t` (float sim seconds), `state` (String, e.g. "ROLLING").
  - `pos`, `vel` (Vector3), `speed` (float), `on_floor` (bool), `floor_normal` (Vector3), `facing`, `board_up`.
  - `stick` (Vector2), `held` (Array[String]), `pressed` (Array[String], the just-pressed buttons).
  - `crouch` (float), `anim` (String), `vert_air` (bool), `launch_normal` (Vector3), `wall_normal` (Vector3).
  - `pumping` (bool), `pushing` (bool), `push_pulse` (float), `braking` (bool).
  - `left_edge` (bool), `on_wall` (bool), `rail` (String: the rail node name or "").
  - `events` (Array[String] this tick). Possible events: "ollie", "air", "land:<result>", "bail", "grind",
    "grind_end", "manual", "lip", "wallride", "leave_edge", "overhang_drop", "speed_restore", "respawn",
    "dismount", "mount".
- `func snapshot() -> Dictionary` captures every variable that affects future physics: the transform, velocity
  and all private ride vars, the state machine (state, time_in_state, combo_open, `_revert_armed`), crouch, the
  trick-input buffers, etc. `func restore(d: Dictionary) -> void` puts it back exactly. Holding inputs fixed,
  `restore(snapshot())` then N ticks must give the same positions as the original run (within 1e-3 m on the
  same machine).

## Flight recorder file format (`user://physics_logs/*.json`)
```
{ "version": 1, "park": "main"|"testpark", "tuning": {...to_dict()}, "tick_rate": 60,
  "frames": [ {tick,t,state,pos:[x,y,z],vel:[..],speed,on_floor,floor_normal:[..],facing:[..],stick:[x,y],
               held:[..],pressed:[..],crouch,anim,pumping,pushing,events:[..]} ... ],
  "snapshots": { "<tick>": <snapshot() with Vector3/Transform3D/Basis encoded as arrays> } }
```
Use `var_to_str` / `str_to_var` for snapshot values inside a JSON string field if that's simpler. It must
survive the round trip exactly.
