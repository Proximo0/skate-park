# Production pipeline (lean loop)

Proven on Sandblood (a physics fighter, 2026-10): AAA-leaning results at a much lower token draw than earlier
projects. Use this after the debug layer and bot exist (see `new_project_checklist.md`).

## Roles
- **Lead (one session):** talks to the owner, writes short task prompts, owns git, verifies and pushes. Never does
  worker-sized coding itself and never reads worker transcripts, only their final reports.
- **Workers (background agents):** one task each, explicit file ownership, the hard rules in `agent_brief.md`.
  Model per task: Sonnet by default (FX, UI, tools, sweeps, data); Opus only for hard core logic (AI behaviour,
  locomotion, physics); Haiku for docs and simple data.

## One loop round
1. **Measure:** a bot sweep (every weapon/character/level vs a baseline, small n, both sides) collecting win rate,
   draws, fight length, self-hits, stuck time, log errors.
2. **Pick 1-2 worst defects:** crashes and errors > stuck or no engagement > broken behaviour > balance outliers.
3. **Reproduce, trace, fix the mechanism** in the smallest set of files; before/after numbers from the same tool.
4. **Verify on a clean clone** (lint, tests, sims), commit by name with the attribution trailers, push.
5. Ask the worker for a ranked "next 3 defects" list; that list seeds the next round.

## Keeping token draw low
- Prompts are short and point at files and docs instead of retyping them; workers read `CLAUDE.md`,
  `lessons_learned.md` and the relevant `docs/*.md` themselves.
- Disjoint file ownership lets 2-3 workers run in parallel with no merge work. Shared files (`tuning.gd`, the
  fighter/player script): small anchored edits, re-read before each edit, and tell the other worker.
- Workers keep tool output terse (tail logs, no file dumps) and return a short structured report.
- The lead checks renders by looking at 1-2 images, not all of them.
- Builds only at milestones the owner can feel, not every round. Updates to the owner only for results, blockers
  or questions; progress goes on the checklist.
- After a container restart, relaunch from the WIP in the tree with the previous findings in the prompt.

## Owner-facing extras
- Test bypasses ship as launchers next to the exe (for example "unlock all", "test shop"), never in release paths.
- Secrets are injected at export from a gitignored config.
- Art made on the owner's machine (Houdini via Remote Control) comes back as a zip the owner drags into the thread.
