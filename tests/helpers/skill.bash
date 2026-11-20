# shellcheck shell=bash
# Shared by the skill tests (skills/<name>/tests): fakes of system commands.

# fake_cygpath ok|fail: a cygpath first in PATH that logs each call to $CYGPATH_LOG. ok passes the call to
# the real cygpath (Git Bash) or prints the path as it is (Linux, macOS: no drive letters); fail exits 1.
fake_cygpath() {
  local real bin="$BATS_TEST_TMPDIR/cygbin"
  real="$(command -v cygpath || true)"
  CYGPATH_LOG="$BATS_TEST_TMPDIR/cygpath.log"
  mkdir -p "$bin"
  cat > "$bin/cygpath" <<EOF
#!/usr/bin/env bash
echo "\$*" >> "$CYGPATH_LOG"
[ "$1" = ok ] || exit 1
if [ -n "$real" ]; then exec "$real" "\$@"; fi
printf '%s\n' "\${!#}"
EOF
  chmod +x "$bin/cygpath"
  export PATH="$bin:$PATH"
}
