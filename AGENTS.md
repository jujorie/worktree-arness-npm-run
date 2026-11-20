# worktree-arness-npm-run

arness plugin: the skills in `skills/` are installed into an arness checkout with its `plugin-manage` skill. See `README.md`.

## Repo rules

- Every skill lives in `skills/npm-<name>/` with `SKILL.md` (`name: npm-<name>`), `README.md`, its scripts in `scripts/` and bats tests in `tests/` (one `<script>.bats` per entry script). Keep `skills=` in `arness-plugin.conf` in sync with `skills/`; `tests/repo.bats` checks it.
- A skill with a script lists it in `allowed-tools` as `Bash(skills/<skill>/scripts/<script>.sh *)`. Paths are relative to the arness root, where the plugin's skills are linked.
- A script finds the arness root from `ARNESS_ROOT`, else from its own path: up to `skills/` logically (the installed skill is a link `skills/<skill> -> ../plugins/<plugin>/skills/<skill>`), then physically. Never `cd -P` from the script's folder: it lands in the plugin's clone.
- `hook.worktree-remove` in `arness-plugin.conf` is run by arness before it removes a worktree, with `<repo>/<name>` as last argument. It prints only lines worth reporting, nothing when it did nothing, and exits non-zero when the worktree must be kept.
- Shell scripts must run on macOS (bash 3.2) and Linux/WSL: no GNU-only flags (`sed -i`, `readlink -f`, `mapfile`). Run `./scripts/test.sh` after changing them; it needs `bats`, `shellcheck`, `jq`, `npm` and `uvx` and fails without them.
- Write a skill's `description` as a folded block (`description: >-`, lines indented by two spaces). The suite checks every `SKILL.md` with the Agent Skills validator.
- Never push to `main`; work on a branch and open a pull request. Bump `version` in `arness-plugin.conf` with each change that users should get.
