# shellcheck shell=bash
# Shared by the repo-wide checks: the repo root and the lists of files they check.

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

# Skill folders, one path per line, each ending in "/".
skill_dirs() {
  local d
  for d in "$REPO_ROOT"/skills/*/; do [ -d "$d" ] && printf '%s\n' "$d"; done
}

# Entry scripts: the test runner and every skill script.
entry_scripts() {
  local d f
  printf '%s\n' "$REPO_ROOT/scripts/test.sh"
  while IFS= read -r d; do
    for f in "$d"scripts/*.sh; do [ -e "$f" ] && printf '%s\n' "$f"; done
  done < <(skill_dirs)
}

# Libraries: the blocks an entry script sources from its scripts/lib/.
lib_scripts() {
  local f
  for f in "$REPO_ROOT"/skills/*/scripts/lib/*.sh; do
    if [ -e "$f" ]; then printf '%s\n' "$f"; fi
  done
}

# Test files: every bats file and its helpers.
test_files() {
  find "$REPO_ROOT/skills" "$REPO_ROOT/tests" -type f \( -name '*.bats' -o -name '*.bash' \)
}
