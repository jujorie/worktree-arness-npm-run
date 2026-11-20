# npm-run

Runs `npm run <script> [-- <args>]` in an arness worktree (`worktrees/<repo>/<name>`), in the background, with
its output in a log and its pid saved, so it can be waited for or stopped later with its child processes.
Procedure in `SKILL.md`.

```
run   ─ checks (worktree, package.json, script, node_modules, .nvmrc node) → STARTED | FINISHED
wait  ─ until <script>.code appears → FINISHED <code> | TIMEOUT
ps / stop / clean / scripts
worktree-remove <repo>/<name> ─ arness hook: stop what runs there before the worktree is removed
```

## Files

| Path | What |
|---|---|
| `SKILL.md` | The procedure the agent follows |
| `scripts/npm-run.sh` | `run`, `wait`, `scripts`, `ps`, `stop`, `clean`, and `worktree-remove` (the arness hook); state in `<arness>/tmp/npm-run/<repo>/<name>/` |
| `tests/` | bats tests of the script: `bats skills/npm-run/tests/` |

Requires `git`; `npm` for `run`, `wait` and `scripts`.
