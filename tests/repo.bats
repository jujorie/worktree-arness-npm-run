#!/usr/bin/env bats
# Repo-wide checks of every skill: structure, plugin configuration and allowed-tools.

load helpers/repo

@test "arness-plugin.conf lists every skill, each with the plugin prefix" {
  conf="$REPO_ROOT/arness-plugin.conf"
  prefix="$(awk -F= '$1 == "prefix" { print $2 }' "$conf")"
  [ -n "$prefix" ] || { echo "no prefix= in arness-plugin.conf"; false; }
  listed="$(awk -F= '$1 == "skills" { print $2 }' "$conf" | tr ' ' '\n' | sort)"
  present="$(skill_dirs | while IFS= read -r d; do basename "$d"; done | sort)"
  [ "$listed" = "$present" ] || { printf 'skills= in arness-plugin.conf:\n%s\nskills/:\n%s\n' "$listed" "$present"; false; }
  for n in $present; do
    case "$n" in "$prefix"*) ;; *) echo "skill $n does not start with prefix $prefix"; false ;; esac
  done
}

# The Agent Skills reference validator (https://agentskills.io/specification), pinned. Provider-neutral
# checks of each SKILL.md frontmatter: valid YAML, name format equal to the folder, description length.
# Its PyPI package is skills-ref, its executable agentskills.
AGENTSKILLS_VALIDATOR="skills-ref==0.1.1"

@test "every skill passes the Agent Skills validator" {
  local d failed=""
  while IFS= read -r d; do
    uvx -q --from "$AGENTSKILLS_VALIDATOR" agentskills validate "${d%/}" || failed="$failed $(basename "$d")"
  done < <(skill_dirs)
  [ -z "$failed" ] || { echo "invalid SKILL.md frontmatter:$failed"; false; }
}

@test "every skill has a SKILL.md with a folded description, and a README.md" {
  while IFS= read -r d; do
    n="$(basename "$d")"
    [ -f "$d/SKILL.md" ] || { echo "no SKILL.md: $n"; false; }
    # The description is a folded block (description: >-, then lines indented by two spaces): any text,
    # ": " included, stays valid YAML, and the tools read it as one line.
    awk '/^description: >-$/ { getline; ok = /^  [^ ]/ } END { exit !ok }' "$d/SKILL.md" \
      || { echo "description is not a folded block (description: >-): $n"; false; }
    [ -f "$d/README.md" ] || { echo "no README.md: $n"; false; }
  done < <(skill_dirs)
}

@test "skill scripts live under <skill>/scripts and each has its bats tests" {
  while IFS= read -r d; do
    loose="$(find "$d" -name '*.sh' -not -path '*/scripts/*')"
    [ -z "$loose" ] || { echo "script outside scripts/: $loose"; false; }
    for f in "$d"scripts/*.sh; do
      [ -e "$f" ] || continue
      t="$d/tests/$(basename "$f" .sh).bats"
      [ -f "$t" ] || { echo "no tests: $t"; false; }
    done
  done < <(skill_dirs)
}

@test "a skill with a script names it in allowed-tools" {
  while IFS= read -r d; do
    n="$(basename "$d")"
    for f in "$d"scripts/*.sh; do
      [ -e "$f" ] || continue
      grep '^allowed-tools:' "$d/SKILL.md" | grep -qF "Bash(skills/$n/scripts/$(basename "$f") " \
        || { echo "allowed-tools lacks $(basename "$f") in $n"; false; }
    done
  done < <(skill_dirs)
}
