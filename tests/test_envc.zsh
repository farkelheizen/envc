#!/bin/zsh
emulate -L zsh
setopt err_exit no_unset pipe_fail

root=${0:A:h:h}
cli="$root/envc"
tmpdir=$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/envc-test.XXXXXXXX")
config="$tmpdir/config"
config=${config:A}
mkdir -p "$config" "$tmpdir/bin"

cleanup() {
  /bin/rm -rf "$tmpdir"
}
trap cleanup EXIT

fail() {
  print -u2 -r -- "FAIL: $*"
  if [[ -f $tmpdir/out ]]; then
    print -u2 -r -- '--- stdout ---'
    /bin/cat "$tmpdir/out"
  fi
  if [[ -f $tmpdir/err ]]; then
    print -u2 -r -- '--- stderr ---'
    /bin/cat "$tmpdir/err"
  fi
  exit 1
}

expect_failure() {
  if "$@" > "$tmpdir/out" 2> "$tmpdir/err"; then
    fail "expected failure: $*"
  fi
}

envc() {
  if [[ ${1-} == edit ]]; then
    ENVC_CONFIG_DIR="$config" ENVC_EDITOR="$tmpdir/bin/vi" "$cli" "$@"
    return
  fi
  ENVC_CONFIG_DIR="$config" "$cli" "$@"
}

for file in "$cli" "$0"; do
  zsh -n "$file"
done
if /usr/bin/grep -nE '[[:blank:]]+$' "$cli" "$0"; then
  fail 'trailing whitespace found'
fi

envc help | /usr/bin/grep -q 'Usage: envc'
[[ $(envc --version) == 'envc 0.1.0' ]] || fail '--version did not report envc 0.1.0'
[[ $(envc -V) == 'envc 0.1.0' ]] || fail '-V did not report envc 0.1.0'
expect_failure envc --version unexpected
expect_failure envc -V unexpected
envc --version | /usr/bin/grep -q '^envc 0\.1\.0$' || fail '--version output is malformed'
envc completions | /usr/bin/grep -q 'compdef _envc envc'
expect_failure envc
expect_failure envc unknown
expect_failure envc run app

[[ $(envc path app) == "$config/app/default.env" ]] || fail 'app did not resolve to default.env'
[[ $(envc path app/profile) == "$config/app/profile.env" ]] || fail 'profile target did not resolve'
[[ $(envc path app/profile.env) == "$config/app/profile.env" ]] || fail 'redundant .env suffix was not removed'

for target in '' '../foo' 'foo/../bar' 'foo/bar/baz' '/abs/path' '.' 'foo/..' 'foo/.env' 'foo/'; do
  expect_failure envc path "$target"
done
expect_failure envc path --exists app/missing

cat > "$tmpdir/bin/vi" <<'EOF'
#!/bin/zsh
if [[ -n ${MOCK_SYMLINK_TARGET-} ]]; then
  /bin/rm -f "$1"
  /bin/ln -s "$MOCK_SYMLINK_TARGET" "$1"
  exit
fi
if [[ -n ${MOCK_CONTENT-} ]]; then
  print -r -- "$MOCK_CONTENT" >> "$1"
fi
if [[ -n ${MOCK_MODE-} ]]; then
  /bin/chmod "$MOCK_MODE" "$1"
fi
if [[ ${MOCK_FAIL-} == 1 ]]; then
  exit 7
fi
EOF
cat > "$tmpdir/bin/emacs" <<'EOF'
#!/bin/zsh
[[ $1 == -nw && -f $2 ]]
EOF
cat > "$tmpdir/bin/code" <<'EOF'
#!/bin/zsh
print -r -- launched > "${MOCK_MARKER:?}"
EOF
/bin/chmod +x "$tmpdir/bin/vi" "$tmpdir/bin/emacs" "$tmpdir/bin/code"
/bin/ln -s "$cli" "$tmpdir/bin/envc"

EDITOR=code VISUAL=cursor ENVC_EDITOR="$tmpdir/bin/vi" \
  ENVC_CONFIG_DIR="$config" "$cli" edit app/base
[[ $(/usr/bin/stat -f '%Lp' "$config/app") == 700 ]] || fail 'app directory mode is not 0700'
[[ $(/usr/bin/stat -f '%Lp' "$config/app/base.env") == 600 ]] || fail 'profile mode is not 0600'
/usr/bin/grep -q '^# envc config: app/base$' "$config/app/base.env" ||
  fail 'new profile header is missing'

ENVC_EDITOR= ENVC_CONFIG_DIR="$config" PATH="$tmpdir/bin:$PATH" "$cli" edit app/default
[[ -f $config/app/default.env ]] || fail 'empty ENVC_EDITOR did not fall back to vi'
ENVC_CONFIG_DIR="$config" ENVC_EDITOR=true "$cli" edit app/base
ENVC_CONFIG_DIR="$config" ENVC_EDITOR="$tmpdir/bin/emacs -nw" "$cli" edit app/emacs
expect_failure env ENVC_CONFIG_DIR="$config" ENVC_EDITOR="$tmpdir/bin/vi" \
  MOCK_MODE=644 MOCK_FAIL=1 "$cli" edit app/base
[[ $(/usr/bin/stat -f '%Lp' "$config/app/base.env") == 600 ]] ||
  fail 'profile mode was not restored after an editor failure'
/usr/bin/grep -q 'editor exited with status 7' "$tmpdir/err" ||
  fail 'editor failure status was not reported'

for editor in code codium cursor 'cursor --wait' windsURF zed subl sublime_text \
  idea pycharm webstorm goland clion fleet open "$tmpdir/bin/code"; do
  expect_failure env ENVC_CONFIG_DIR="$config" ENVC_EDITOR="$editor" MOCK_MARKER="$tmpdir/blocked" "$cli" edit app/blocked
done
[[ ! -e $tmpdir/blocked ]] || fail 'a blocked editor was launched'
[[ ! -e $config/app/blocked.env ]] || fail 'a blocked editor created a profile'
editor_injection="vi; touch $tmpdir/editor-marker"
expect_failure env ENVC_CONFIG_DIR="$config" ENVC_EDITOR="$editor_injection" "$cli" edit app/blocked
[[ ! -e $tmpdir/editor-marker ]] || fail 'editor command syntax was executed'
expect_failure env ENVC_CONFIG_DIR="$config" ENVC_EDITOR='emacs' "$cli" edit app/blocked

MOCK_CONTENT='export API_SECRET=synthetic-value' \
  ENVC_CONFIG_DIR="$config" ENVC_EDITOR="$tmpdir/bin/vi" "$cli" edit app/linted \
  2> "$tmpdir/lint.err"
/usr/bin/grep -q 'possible secret variable(s)' "$tmpdir/lint.err" ||
  fail 'secret-like assignment did not warn'
/usr/bin/grep -q 'API_SECRET' "$tmpdir/lint.err" || fail 'warning omitted suspect name'
MOCK_CONTENT='API_SECRET=synthetic-value # envc:allow' \
  ENVC_CONFIG_DIR="$config" ENVC_EDITOR="$tmpdir/bin/vi" "$cli" edit app/allowed \
  2> "$tmpdir/lint.err"
if /usr/bin/grep -q 'possible secret variable(s)' "$tmpdir/lint.err"; then
  fail 'envc:allow did not suppress the warning'
fi

mkdir -p "$config/alpha" "$config/Beta"
print -r -- 'NAME=alpha' > "$config/alpha/first.env"
print -r -- 'NAME=beta' > "$config/Beta/second.env"
expected=$'Beta/second\nalpha/first\napp/allowed\napp/base\napp/default\napp/emacs\napp/linted'
[[ $(envc list) == "$expected" ]] || fail 'list output is not sorted or complete'
[[ $(envc list ALPHA) == 'alpha/first' ]] || fail 'list filter is not case-insensitive'
[[ -z $(envc list '[*]') ]] || fail 'list filter treated a pattern as a wildcard'
[[ $(envc ls) == $(envc list) ]] || fail 'ls alias differs from list'
envc edit app/modefix
/bin/chmod 000 "$config/app/modefix.env"
ENVC_EDITOR=true envc edit app/modefix
[[ $(/usr/bin/stat -f '%Lp' "$config/app/modefix.env") == 600 ]] ||
  fail 'edit did not repair an unreadable profile mode'

/bin/mkdir -p "$tmpdir/outside"
/bin/ln -s "$tmpdir/outside" "$config/linkapp"
expect_failure envc edit linkapp/profile
[[ ! -e $tmpdir/outside/profile.env ]] || fail 'edit followed a symlinked app directory'
print -r -- ": > '$tmpdir/internal-marker'" > "$tmpdir/outside/direct.env"
expect_failure envc __run "$tmpdir/outside/direct.env" -- /usr/bin/true
expect_failure envc __env "$tmpdir/outside/direct.env"
[[ ! -e $tmpdir/internal-marker ]] || fail 'internal command sourced a profile outside the config root'
/bin/ln -s "$tmpdir/outside/other.env" "$config/app/symlink.env"
expect_failure envc cat app/symlink
expect_failure envc delete app/symlink
expect_failure envc path --exists app/symlink
[[ $(envc list) != *app/symlink* ]] || fail 'list included a symlinked profile'
print -r -- 'outside' > "$tmpdir/outside/replace-target"
ENVC_CONFIG_DIR="$config" ENVC_EDITOR="$tmpdir/bin/vi" "$cli" edit app/replaced
replace_mode=$(/usr/bin/stat -f '%Lp' "$tmpdir/outside/replace-target")
expect_failure env MOCK_SYMLINK_TARGET="$tmpdir/outside/replace-target" \
  ENVC_CONFIG_DIR="$config" ENVC_EDITOR="$tmpdir/bin/vi" "$cli" edit app/replaced
[[ $(/usr/bin/stat -f '%Lp' "$tmpdir/outside/replace-target") == "$replace_mode" ]] ||
  fail 'editor symlink replacement changed an outside file'
/bin/rm -f "$config/app/replaced.env"

[[ $(envc path -e app/base) == "$config/app/base.env" ]] || fail 'path --exists failed for an existing profile'
[[ $(envc path app/base alpha/first) == "$config/app/base.env
$config/alpha/first.env" ]] || fail 'multi-target path order is incorrect'
[[ $(envc cat app/base) == "$( /bin/cat "$config/app/base.env" )" ]] || fail 'cat did not print the profile'
expect_failure envc cat app/base app/missing
[[ ! -s $tmpdir/out ]] || fail 'cat wrote partial output before validating all targets'
[[ $(envc show app/base) == $(envc cat app/base) ]] || fail 'show alias differs from cat'
multi_cat=$(envc cat alpha/first app/base)
[[ $multi_cat == *'# --- alpha/first ('* && $multi_cat == *'# --- app/base ('* ]] ||
  fail 'multi-file cat omitted profile headers'

print -r -- 'UNREADABLE=synthetic' > "$config/app/unreadable.env"
/bin/chmod 000 "$config/app/unreadable.env"
expect_failure envc cat app/unreadable
expect_failure envc run app/unreadable -- /usr/bin/true
/bin/chmod 600 "$config/app/unreadable.env"
print -r -- 'UNREADABLE_DELETE=synthetic' > "$config/app/unreadable-delete.env"
/bin/chmod 000 "$config/app/unreadable-delete.env"
envc delete app/unreadable-delete
[[ ! -e $config/app/unreadable-delete.env ]] ||
  fail 'delete could not remove an unreadable regular profile'

cat > "$config/app/base.env" <<'EOF'
A=1
B=1
SAME=baseline
files=base-files
EOF
cat > "$config/app/override.env" <<'EOF'
B=2
INTERP="${A}-later"
SPECIAL=$'space " quote \'single\' \\ dollar $ and newline\nnext\n\n'
SAME=baseline
files=override-files
command_args=profile-value
EOF

envc run app/base app/override -- zsh -fc \
  '[[ $A == 1 && $B == 2 && $INTERP == "1-later" && $SAME == baseline && $files == override-files && $command_args == profile-value ]]'
if envc run app/base app/override -- zsh -fc 'exit 23'; then
  fail 'run did not propagate a nonzero child status'
else
  [[ $? == 23 ]] || fail 'run returned the wrong child status'
fi
payload="\$(touch $tmpdir/argument-marker)"
actual=$(envc run app/base app/override -- /usr/bin/printf '%s' 'two words' "$payload")
[[ $actual == "two words$payload" ]] || fail 'run did not preserve command arguments'
[[ ! -e $tmpdir/argument-marker ]] || fail 'run evaluated a child argument as shell code'

print -r -- 'return 1' > "$config/app/failing.env"
expect_failure envc run app/failing -- /usr/bin/touch "$tmpdir/source-failure-marker"
[[ ! -e $tmpdir/source-failure-marker ]] || fail 'run launched a child after profile evaluation failed'

marker="$tmpdir/source-marker"
print -r -- ": > '$marker'" > "$config/app/base.env"
expect_failure envc run app/base app/missing -- /usr/bin/true
[[ ! -e $marker ]] || fail 'run sourced a profile before validating every target'
expect_failure envc run app/base app/missing -- /usr/bin/touch "$marker"
[[ ! -e $marker ]] || fail 'run started a child before validating every target'
expect_failure envc env app/base app/missing
[[ ! -s $tmpdir/out ]] || fail 'env emitted output before validating every target'
expect_failure envc path --exists app/base app/missing
[[ ! -s $tmpdir/out ]] || fail 'path emitted output before validating every target'

cat > "$config/app/base.env" <<'EOF'
A=one
B=two
C='literal $HOME and "quotes"'
D=$'line one\nline two\n\n'
EMPTY=''
files=base-profile
candidates=profile-candidates
baseline_values=profile-baseline
name=profile-name
EOF
envc env app/base > "$tmpdir/exports"
[[ $(/usr/bin/grep -c '^export ' "$tmpdir/exports") == 9 ]] ||
  fail 'env emitted unrelated baseline values or missed target variables'
BASELINE_ONLY=outside ENVC_CONFIG_DIR="$config" "$cli" env app/base > "$tmpdir/exports"
if /usr/bin/grep -q '^export BASELINE_ONLY=' "$tmpdir/exports"; then
  fail 'env emitted an unrelated inherited variable'
fi
envc env app/base app/override > "$tmpdir/exports"
cat > "$tmpdir/check-env.zsh" <<'EOF'
eval "$(/bin/cat "$1")"
[[ $A == one && $B == 2 && $C == 'literal $HOME and "quotes"' &&
  $D == $'line one\nline two\n\n' && $EMPTY == '' && $INTERP == one-later &&
  $files == override-files && $command_args == profile-value &&
  $SPECIAL == $'space " quote \'single\' \\ dollar $ and newline\nnext\n\n' ]]
EOF
ENVC_CONFIG_DIR="$config" zsh -f "$tmpdir/check-env.zsh" "$tmpdir/exports" ||
  fail 'env output did not safely preserve layered values'
cat > "$tmpdir/check-env.bash" <<'EOF'
eval "$(/bin/cat "$1")"
[[ $A == one && $B == 2 && $C == 'literal $HOME and "quotes"' &&
  $D == $'line one\nline two\n\n' && $EMPTY == '' && $INTERP == one-later &&
  $files == override-files && $command_args == profile-value &&
  $SPECIAL == $'space " quote \'single\' \\ dollar $ and newline\nnext\n\n' ]]
EOF
/bin/bash "$tmpdir/check-env.bash" "$tmpdir/exports" ||
  fail 'env output was not safely evaluable by a POSIX-style shell'
/usr/bin/grep -q '^export SAME=' "$tmpdir/exports" ||
  fail 'env omitted a variable explicitly assigned its baseline value'

print -r -- 'print -r -- partial; return 1' > "$config/app/failing.env"
expect_failure envc env app/failing
[[ ! -s $tmpdir/out ]] || fail 'env emitted partial output after a source failure'

envc completions > "$tmpdir/completions.zsh"
/usr/bin/grep -q -- '--exists' "$tmpdir/completions.zsh" ||
  fail 'path completion omitted the existence flags'
cat > "$tmpdir/check-completions.zsh" <<'EOF'
compdef() { : }
compadd() { shift; print -r -l -- "$@" }
words=(envc env '')
CURRENT=3
source "$1"
_envc
EOF
ENVC_CONFIG_DIR="$config" PATH="$tmpdir/bin:$PATH" \
  zsh -f "$tmpdir/check-completions.zsh" "$tmpdir/completions.zsh" > "$tmpdir/completed"
/usr/bin/grep -qx 'app/base' "$tmpdir/completed" ||
  fail 'dynamic profile completion did not return an existing slug'

envc delete alpha/first
[[ ! -e $config/alpha ]] || fail 'delete did not remove the now-empty app directory'
expect_failure envc delete app/missing
[[ $(envc rm app/allowed) == '' ]] || fail 'rm alias did not delete the profile'
[[ ! -e $config/app/allowed.env ]] || fail 'rm alias left the profile in place'

/bin/mkdir -p "$tmpdir/home/.local/bin"
/bin/cp "$cli" "$tmpdir/home/.local/bin/envc"
/bin/chmod +x "$tmpdir/home/.local/bin/envc"
HOME="$tmpdir/home" PATH="$tmpdir/home/.local/bin:$PATH" "$tmpdir/home/.local/bin/envc" help |
  /usr/bin/grep -q 'Usage: envc' || fail 'installed executable did not run'

print -r -- 'envc tests passed.'
