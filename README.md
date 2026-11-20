# worktree-arness-npm-run

An [arness](https://github.com/jujorie/worktree-arness) plugin to run the npm scripts of a worktree: start them
in the background, wait for their exit code, list, stop and clean them up.

| Skill | What it does |
|---|---|
| `npm-run` | Run a `package.json` script of an arness worktree in the background (asks which worktree if there are several, and before installing dependencies), with the node version of its `.nvmrc` from nvm; wait for one to end with its exit code; list, stop and clean up after them |

Before arness removes a worktree (`worktree-clean`), it runs the plugin's `hook.worktree-remove`, which stops the
dev servers and watchers `npm-run` started there: once the folder is gone they would keep running and holding
their ports. If one cannot be stopped (`STOP_FAILED`), the worktree is kept and arness shows that line.

## Install

From the arness repo, with its `plugin-manage` skill: "instala el plugin git@github.com:jujorie/worktree-arness-npm-run.git".
It shows the skills, hook and permission rules and asks before installing. Update it the same way ("actualiza
el plugin worktree-arness-npm-run"). Needs an arness that knows `hook.worktree-remove`.

Requires `git`, and `npm` to run scripts (node from nvm, nvm-windows or any other install).

## Layout

```
arness-plugin.conf        plugin manifest (format: plugins/README.md of arness)
skills/npm-run/           SKILL.md, README.md, scripts/, tests/
tests/                    repo-wide checks of the skills and scripts
scripts/test.sh           runs the whole suite
```

Every skill starts with the prefix `npm-`, so the plugin does not collide with other plugins. Scripts follow
the arness rules: bash 3.2 (macOS) and Linux, no GNU-only flags.

## Tests

Requires `bats-core`, `shellcheck`, `jq`, `npm` and `uv` (`brew install bats-core shellcheck jq node uv`; uv on
Linux: https://docs.astral.sh/uv/getting-started/installation/). `scripts/test.sh` fails with `missing: <tool>`
without one of them. The suite runs the [Agent Skills](https://agentskills.io/specification) reference
validator (`uvx --from skills-ref agentskills validate <skill>`) on every skill, so each `SKILL.md`
frontmatter is valid YAML with a valid `name` and `description` for any provider. npm runs for real in the
tests, offline, on scripts that only echo, sleep or exit.

```bash
./scripts/test.sh
```
