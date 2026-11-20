#!/usr/bin/env bats
# Repo-wide checks of every script and test: portability, shellcheck and bats assertions that can fail.

load helpers/repo

# Prints file:line of each assertion that cannot fail the test. One rule: a line that
# starts with `[`, `[[`, `((` or `!` is an assertion and must end with `|| false` (or
# a `|| { ...; false; }` block, `return N`/`exit N` with N > 0 also count, on one line
# or several), with only checks joined by `||` before it (`|| echo` in between makes
# it never run); control flow is written as `if`. A `;` outside quotes, `[[ ]]`, `(( ))`,
# `$( )` and that block always flags the line. The only exception is a lone `[ ... ]`
# with no `&&` or `;`, a plain command that fails the test in every bash, alone or
# with each `||` followed by `[ ... ]`, `skip`, `return`, `continue` or `exit`.
# if/elif/while/until conditions do not start with those tokens, so they are never
# matched, and neither is a list that starts with another command
# (`grep -q a f && grep -q b f`), by design. The rule looks at the logical line: lines
# ending in `\`, `&&`, `||` or `|` joined with the next, quoted strings and the
# trailing comment removed line by line, a `|| {` block joined up to its `}`, the
# inside of `${ }`, `[[ ]]`, `(( ))` and `$( )` emptied, heredoc bodies skipped (a
# heredoc or a `|| {` block still open at the end of a file is reported).
# Known limits: an odd number of `"` inside '...' can confuse the quote stripping; a
# `]]`, `))` or `)` nested inside a check (`[[:digit:]]` inside `[[ ]]`) closes it too
# early; and `( ... )` and `{ ... }` other than the final block are not emptied.
silent_assertions() {
  awk '
    # The line without quoted strings and trailing comment; a quoted heredoc
    # delimiter (<<"EOF", or in single quotes) is unquoted first so it survives.
    function clean(s,   w) {
      while (match(s, /<<-?[ \t]*["\047][A-Za-z_][A-Za-z0-9_]*["\047]/)) {
        w = substr(s, RSTART, RLENGTH); gsub(/["\047 \t-]/, "", w)
        s = substr(s, 1, RSTART - 1) w substr(s, RSTART + RLENGTH)
      }
      gsub(/"([^"\\]|\\.)*"/, "\"\"", s); gsub(/\047[^\047]*\047/, "\047\047", s)
      sub(/^#.*$/, "", s); sub(/[ \t]#.*$/, "", s)
      return s
    }
    # s with what is between each open and its close emptied, so a || or && inside
    # [[ ]], (( )) or $( ) is not taken for the list operator.
    function blank(s, op, ed,   i, j, out) {
      out = ""
      while ((i = index(s, op)) > 0) {
        j = index(substr(s, i + length(op)), ed)
        if (j == 0) break
        out = out substr(s, 1, i - 1) op " " ed
        s = substr(s, i + length(op) + j - 1 + length(ed))
      }
      return out s
    }
    # A part of a || list after a lone [ ] that still fails the test: [ ] or a jump.
    function failing_tail(p) {
      return p ~ /^[ \t]*\[[ \t]/ || p ~ /^[ \t]*(skip|return|continue|exit)([ \t]|$)/
    }
    function silent(s,   n, i, p) {
      if (s !~ /^[ \t]*(\[|\(\(|![ \t])/) return 0
      s = blank(blank(blank(blank(s, "${", "}"), "$(", ")"), "[[", "]]"), "((", "))")
      gsub(/\$\{ \}/, "$v", s)
      # A final block counts as || false only when it ends in a command that fails.
      sub(/\|\|[ \t]*\{([^{}]*;)?[ \t]*(false|return[ \t]+[1-9][0-9]*|exit[ \t]+[1-9][0-9]*)[ \t]*;?[ \t]*\}[ \t]*$/, "|| false", s)
      if (s ~ /;/) return 1
      # Before the final || false, every || part must be a check: `|| echo` in between
      # always succeeds, so the || false after it never runs.
      if (s ~ /\|\|[ \t]*false[ \t]*$/) {
        n = split(s, p, /\|\|/)
        for (i = 2; i < n; i++) if (p[i] !~ /^[ \t]*(\[|\(\(|![ \t])/) return 1
        return 0
      }
      if (s !~ /^[ \t]*\[[ \t]/ || s ~ /&&/) return 1
      # A lone [ ], alone or with each || followed by another [ ] or skip/return/continue/exit.
      n = split(s, p, /\|\|/)
      for (i = 2; i <= n; i++) if (!failing_tail(p[i])) return 1
      return 0
    }
    function unterminated() {
      if (tag != "") print file ": unterminated heredoc " tag
      if (block) print file ": unterminated || { block"
    }
    FNR == 1 { unterminated(); tag = ""; line = ""; cl = ""; block = 0; file = FILENAME }
    tag != "" { if ($0 ~ "^[ \t]*" tag "[ \t]*$") tag = ""; next }
    # line is the raw logical line, for the report; cl the same line cleaned line by
    # line, so a comment on one line does not hide the lines joined after it.
    {
      c = clean($0)
      if (c ~ /<<-?[ \t]*[A-Za-z_]/ && c !~ /<<</) {
        tag = c; sub(/.*<<-?[ \t]*/, "", tag); sub(/[^A-Za-z0-9_].*$/, "", tag)
      }
      line = line $0; cl = cl c
    }
    c ~ /\\$/ { sub(/\\$/, "", line); sub(/\\$/, "", cl); next }
    cl ~ /(&&|\|)[ \t]*$/ { next }
    # A `|| {` block written over several lines is joined, with `;`, up to its `}`.
    {
      c = cl
      if ((block || c ~ /\|\|[ \t]*\{/) && gsub(/\{/, "{", c) > gsub(/\}/, "}", c)) {
        block = 1; line = line ";"; cl = cl ";"; next
      }
      block = 0
    }
    {
      if (silent(cl)) print FILENAME ":" FNR ": " line
      line = ""; cl = ""
    }
    END { unterminated() }
  ' "$@"
}

@test "every script has a bash shebang, LF endings and is executable" {
  while IFS= read -r f; do
    [ "$(head -1 "$f")" = "#!/usr/bin/env bash" ] || { echo "shebang: $f"; false; }
    ! grep -q $'\r' "$f" || { echo "CRLF: $f"; false; }
    [ -x "$f" ] || { echo "not executable: $f"; false; }
  done < <(entry_scripts)
}

@test "every library declares bash for shellcheck, has LF endings and is not executable" {
  while IFS= read -r f; do
    head -1 "$f" | grep -q '^# shellcheck shell=bash' || { echo "no shell=bash: $f"; false; }
    ! grep -q $'\r' "$f" || { echo "CRLF: $f"; false; }
    [ ! -x "$f" ] || { echo "executable: $f"; false; }
  done < <(lib_scripts)
}

@test "no GNU-only flags in scripts" {
  run grep -nE 'readlink -f|sed -i|date -d|grep -P|mapfile|readarray' $(entry_scripts) $(lib_scripts)
  [ "$status" -ne 0 ] || { echo "$output"; false; }
}

@test "shellcheck passes" {
  command -v shellcheck >/dev/null || skip "shellcheck not installed"
  run shellcheck -x -P SCRIPTDIR $(entry_scripts)
  [ "$status" -eq 0 ] || { echo "$output"; false; }
  # shellcheck reports nothing inside a sourced file: each library is checked on its own, without the
  # checks that need the whole script (a global set in one block and read in another).
  [ -n "$(lib_scripts)" ] || return 0
  run shellcheck -e SC2034,SC2153,SC2154 $(lib_scripts)
  [ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "no bats assertion is silent in bash 3.2" {
  run silent_assertions $(test_files)
  [ "$status" -eq 0 ]
  [ -z "$output" ] || {
    echo "make each file:line assertion a list of checks ([, [[, ((, !) ending in || false, with no other command between them and no ; outside quotes and checks (write control flow and messages as if), and close each unterminated heredoc or || { block:"
    echo "$output"; false
  }
}

@test "the silent assertion check flags lines starting with [, [[, (( or ! that do not end in || false, and nothing else" {
  d="$(mktemp -d)"
  cat > "$d/x.bats" <<'EOF'
  [[ "$output" == *a* ]]
  ! grep -q a f
  ! grep -q a \
      f
  [ "$status" -eq 0 ] && [[ "$output" == *a* && "$output" == *b* ]]
  [[ "$output" == *a* ]] && [ "$status" -eq 0 ]
  [ -f x ] && [ -d y ]
  [ -f x ] && rm x
  [ -f x ] && [ -d y ] && rm x
  [[ "$output" == *a* ]]  # c
  (( x > 1 ))
  [ -n "$x" ] && (( x > 1 ))
  [[ "$output" == "a # b" ]]
  [ "$x" = 'a ] && [ b' ] && echo "] && ["
  [ "$status" -eq 0 ]
  [ "$x" = "a && b" ]
  [ "$x" = "a # b" ]  # c
  [[ "$output" == *a* ]] || false
  ! grep -q a f || false
  ! grep -q a f || { echo no; false; }
  ! grep -q a f || false  # c
  (( x > 1 )) || false
  ! grep -q a \
      f || false
  if [[ "$output" == *a* ]]; then :; fi
  if [ -f x ] && [ -d y ]; then :
  elif [ -f y ]; then :; fi
  while [[ -n "$x" ]]; do :; done
  until [ -f x ]; do :; done
  [ "$status" -eq 0 ] && [ -z "$output" ] || false
  [ "$status" -eq 4 ] && [[ "$output" == *a* ]] || { echo no; false; }
  [[ "$output" == *a* && "$output" == *b* ]] || false
  grep -q a f && grep -q b f
  [[ "$output" == a || "$output" == b ]]
  (( x > 1 || y > 1 ))
  ! [[ -n "$a" || -n "$b" ]]
  [ -n "$a" ] && [[ -n "$b" || -n "$c" ]]
  [ -n "$a" ] &&
    [ -n "$b" ]
  [[ "$output" == a || "$output" == b ]] || false
  [ -n "$a" ] &&
    [ -n "$b" ] || false
  if [[ -n "$a" ]] &&
     [[ -n "$b" ]]; then :; fi
  [[ "$output" == a ]] || [[ "$output" == b ]]
  ! grep -q a f || ! grep -q b f
  [[ -n "$a" ]] || false && [[ -n "$b" ]]
  [ "$status" -eq 0 ]; [[ "$output" == *a* ]]
  [ -n "$a" ] || [ -n "$b" ]
  [[ -n "$a" ]] || { echo no; false; }
  [ -n "$a" ] || [[ -n "$b" ]]
  [ -n "$a" ] || ! grep -q b f
  [ "$status" -eq 0 ] || echo "$output"
  [[ -n "$a" ]] || { echo no; }
  [[ -n "$a" ]] || { echo; }; [[ -n "$b" ]] || { echo no; false; }
  [[ -z "$output" ]] || {
    echo "$output"
  }
  [ -x /bin/bash ] || skip "no bash"
  [[ -n "$a" ]] || { echo no; return 1; }
  [[ -z "$output" ]] || {
    echo "$output"; false
  }
  [ -n "$a" ] || echo no || [ -n "$b" ]
  [[ -n "$a" ]] || { false; }
  ! grep -q a f || { exit 1; }
  [[ -n "$a" ]] || { echo ${#lines[@]}; false; }
  [[ -z "$output" ]] || {  # c
    echo "$output"; false  # d
  }
  [[ "$output" == *z* ]]
  [[ -n "$a" ]] || { echo no; return 0; }
  ! grep -q a f || { exit 0; }
  [ -f x ] || return
  [ -f x ] || continue
  [ -f x ] || exit 1
  [ "$status" -eq 0 ] || echo "$output" || false
  [[ -n "$a" ]] || echo no || { echo; false; }
  [[ -n "$a" ]] || [[ -n "$b" ]] || false
  run cmd  # x \
  [[ "$output" == *a* ]]
  cat > f <<'IN'
  [[ heredoc text, not an assertion ]]
  ! neither is this
IN
EOF
  run silent_assertions "$d/x.bats"
  rm -rf "$d"
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "${lines[@]}" | cut -d: -f2 | tr '\n' ' ')" = "1 2 4 5 6 7 8 9 10 11 12 13 14 34 35 36 37 39 45 46 47 48 51 52 53 54 55 58 64 71 72 73 77 78 81 " ]
  [ "${lines[2]}" = "$d/x.bats:4:   ! grep -q a       f" ]
  [ "${lines[8]}" = "$d/x.bats:10:   [[ \"\$output\" == *a* ]]  # c" ]
}

@test "the silent assertion check handles column-0 comments, closed quoted heredocs and continuations across files" {
  d="$(mktemp -d)"
  printf '# cat <<EOF\n  [[ a ]]\n' > "$d/a.bats"
  printf '  cat <<"EOF"\n  [[ in ]]\nEOF\n  cat <<-'\''X'\''\n\t[[ in ]]\n\tX\n  [[ b ]]\n' > "$d/b.bats"
  printf '  ! grep -q a \\\n' > "$d/c.bats"
  printf '  [[ d ]]\n' > "$d/d.bats"
  run silent_assertions "$d/a.bats" "$d/b.bats" "$d/c.bats" "$d/d.bats"
  rm -rf "$d"
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 3 ]
  [ "${lines[0]}" = "$d/a.bats:2:   [[ a ]]" ]
  [ "${lines[1]}" = "$d/b.bats:7:   [[ b ]]" ]
  [ "${lines[2]}" = "$d/d.bats:1:   [[ d ]]" ]
}

@test "the silent assertion check skips no file after a heredoc look-alike and fails on an unterminated one" {
  d="$(mktemp -d)"
  printf '  # cat <<EOF\n  [[ a ]]\n' > "$d/a.bats"
  printf '  [[ b ]]\n' > "$d/b.bats"
  printf '  echo "<<EOF"\n  [[ c ]]\n  cat <<EOF\n' > "$d/c.bats"
  printf '  [[ d ]]\n' > "$d/d.bats"
  run silent_assertions "$d/a.bats" "$d/b.bats" "$d/c.bats" "$d/d.bats"
  rm -rf "$d"
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 5 ]
  [ "${lines[0]}" = "$d/a.bats:2:   [[ a ]]" ]
  [ "${lines[1]}" = "$d/b.bats:1:   [[ b ]]" ]
  [ "${lines[2]}" = "$d/c.bats:2:   [[ c ]]" ]
  [ "${lines[3]}" = "$d/c.bats: unterminated heredoc EOF" ]
  [ "${lines[4]}" = "$d/d.bats:1:   [[ d ]]" ]
}

@test "the silent assertion check reports a || { block left open at the end of a file" {
  d="$(mktemp -d)"
  printf '  [[ a ]] || {\n    echo no; false\n' > "$d/a.bats"
  printf '  [[ b ]]\n' > "$d/b.bats"
  run silent_assertions "$d/a.bats" "$d/b.bats"
  rm -rf "$d"
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 2 ]
  [ "${lines[0]}" = "$d/a.bats: unterminated || { block" ]
  [ "${lines[1]}" = "$d/b.bats:1:   [[ b ]]" ]
}

@test "the silent assertion check reports a heredoc left open at the end of the last file" {
  d="$(mktemp -d)"
  printf '  cat <<'\''EOF'\''\n  [[ a ]]\n' > "$d/a.bats"
  run silent_assertions "$d/a.bats"
  rm -rf "$d"
  [ "$status" -eq 0 ]
  [ "$output" = "$d/a.bats: unterminated heredoc EOF" ]
}
