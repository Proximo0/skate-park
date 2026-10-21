# Skate Park (Godot 4.7, GDScript)

A kid-friendly, cartoony skateboarding game in the spirit of Tony Hawk's Underground 2. v1 is a playable demo:
one full skatepark and complete skating and trick controls. Art is placeholder, built in code, behind art slots
(`docs/art_spec.md`) so the owner's generated art drops in later.

## Commands
- `tools/run_tests.sh [test_name]`: headless unit tests (`tests/unit/test_*.gd`). Prints failures only.
- `tools/lint.sh`: parse and static checks for every script.
- `tools/capture.sh <views.json> <out_dir>`: one launch, one PNG plus JSON sidecar per view (xvfb on Linux).
- `tools/golden.sh [--bless]`: screenshot goldens.
- `tools/gate.sh`: the milestone gate (lint, tests, capture, goldens). PASS/FAIL per step.
- Run the game: `godot --path .` (add `-- --dev` for the dev menu).

## Layout
- `game/autoload/`: `Flags` (run flags, frame counter, state hash), `Controls` (input actions, THUG2 PS2 layout).
- `game/<system>/`: one folder per system (skater, tricks, score, input, park, ui, art, debug).
- `data/`: JSON tuning and content (tricks, gaps, goals). Gameplay numbers live in data, not code.
- `tests/unit/`: one `test_<module>.gd` per module, `extends TestCase` (`tests/test_case.gd`).
- `tools/`: shell and Python tools. Python uses the standard library only.
- `out/`: generated captures and reports (ignored by git).

## Rules
- Static typing everywhere: typed vars, params and returns. Tabs for indentation.
- Gameplay logic is pure `RefCounted` classes with `class_name`, no Node, no wall clock, no `randf()`:
  take `delta` and a seeded `RandomNumberGenerator`. Nodes are thin wrappers that feed them input.
- Every logic module has a unit test file. A change is done when `tools/run_tests.sh` passes.
- File-local helper names must be unique across the project (unity of the class_name space).
- Tools are quiet: print errors and failures, then one summary line.
- Scripted shots key on game state (an observed condition) with a time fallback, never fixed seconds alone.
- Compare state hashes only on frames where `Flags.commands == 0`.
- Captures, tests and gates never write player data (`Flags.is_scripted_run()`).
- Kid-friendly: no blood, no swearing, bright readable UI, generous timing windows.
