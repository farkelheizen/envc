# envc

`envc` is a small Zsh command-line tool for managing non-secret application
configuration profiles outside project workspaces. Profiles are stored under
`${ENVC_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}}`, edited with a
validated terminal editor, and loaded in order for commands or shell exports.
Use [`kch`](https://github.com/farkelheizen/kch) for secrets.

`envc` is a single executable script with no installed runtime packages. It
requires Zsh and standard macOS command-line utilities.

Created by [Bill Spratley](https://github.com/farkelheizen).

## Install

Clone the [envc repository](https://github.com/farkelheizen/envc) and change
into its directory:

```zsh
git clone https://github.com/farkelheizen/envc.git
cd envc
```

Check `command -v envc` for an existing command, then install the script for
your user:

```zsh
mkdir -p "$HOME/.local/bin"
cp -i envc "$HOME/.local/bin/envc"
chmod +x "$HOME/.local/bin/envc"
```

If you decline an overwrite, do not run `chmod` on the existing file. If
`~/.local/bin` is not on `PATH`, add this to `~/.zshrc` and start a new
terminal or source the file:

```zsh
export PATH="$HOME/.local/bin:$PATH"
```

Run `envc help` to verify installation. To update, copy the newer script over
the installed version and preserve its executable bit. To uninstall, remove
`~/.local/bin/envc`; stored profiles are not deleted.

## Versioning

Run `envc --version` (or `envc -V`) to see the installed script version. The
authoritative version is maintained in `envc`. Releases follow Semantic
Versioning (`MAJOR.MINOR.PATCH`) and use a matching Git tag, such as `v1.2.3`.
A major release may include incompatible CLI changes; minor releases add
backward-compatible features, and patch releases contain backward-compatible
fixes. Until `1.0.0`, minor releases may also contain incompatible changes;
document them clearly. At release, the script version must match its tag.
Ordinary unreleased changes do not require a version bump or tag.

## Storage and profile format

By default, profiles are stored as:

```text
${XDG_CONFIG_HOME:-$HOME/.config}/<app>/<profile>.env
```

Set `ENVC_CONFIG_DIR` to override the root. App directories are secured to
mode `0700`; profile files are secured to mode `0600`. `envc` rejects
symlinked app directories and profile files for operations that read or modify
them.

Targets use either `<app>` (the `default` profile) or
`<app>/<profile>`. A trailing `.env` is optional:

```text
matlock2          -> matlock2/default.env
matlock2/common   -> matlock2/common.env
matlock2/mcp.env  -> matlock2/mcp.env
```

App and profile names may contain ASCII letters, digits, `.`, `_`, and `-`,
but cannot be empty, `.` or `..`. Absolute paths, traversal, and targets with
more than one slash are rejected.

Profiles are trusted **Zsh code**, not a dotenv parser. They may use shell
quoting and interpolation, and `envc` sources them in order. Only put
configuration you trust in profile files. Do not use profiles for secrets:
shell files and their values can be exposed through processes, logs, child
environments, or shell history depending on how they are used.
The `__envc_` variable prefix is reserved for the implementation.

## Commands

```zsh
envc edit matlock2/common
envc path matlock2/common
envc path --exists matlock2/common
envc cat matlock2/common
envc list
envc list matlock2
envc delete matlock2/common
envc help
```

- `edit <target>` creates a missing profile with a header and opens it in a
  terminal editor. `ENVC_EDITOR` selects the editor; `EDITOR` and `VISUAL` are
  ignored. The accepted commands are `vi`, `vim`, `nvim`, `nano`, `helix`,
  `hx`, `micro`, or `emacs -nw`; no extra arguments are accepted except
  `emacs -nw`. `true` is accepted as a no-op for tests, not as a useful editor.
  GUI and IDE executables including VS Code, Cursor, Windsurf, Zed, Sublime,
  JetBrains IDEs, and macOS `open` are rejected. The selected executable and
  its installation must still be trusted.
- After editing, `envc` warns (without failing) about nonempty assignments
  whose names contain `SECRET`, `PASSWORD`, `PASSWD`, `TOKEN`, `PRIVATE_KEY`,
  `API_KEY`, `CLIENT_SECRET`, or `SIGNING_KEY`. Add an inline
  `# envc:allow` comment to suppress a warning for that line. This heuristic
  cannot identify every secret.
- `path <target>...` prints canonical absolute paths. Add `-e` or `--exists`
  to require every path to be a regular file.
- `cat`/`show <target>...` prints one or more files in order. Multi-file output
  includes a header for each profile.
- `list`/`ls [filter]` prints sorted `<app>/<profile>` names. The optional
  filter is a case-insensitive literal substring; no matches is successful
  with no output.
- `delete`/`rm <target>` removes a profile immediately. An empty app directory
  is removed when possible.
- `completions` prints Zsh completion code. Load it after `compinit`:

  ```zsh
  autoload -Uz compinit
  compinit
  eval "$(envc completions)"
  ```

  Completion queries profile names through `envc list`; names are restricted
  to validated slugs and are not evaluated as shell code.

## Layered configuration

`run`, `env`, `path`, and `cat` accept one or more targets. Every required
file is checked before any profile is sourced or child process started.
Files are sourced left-to-right, so later values override earlier ones and
can interpolate values from earlier profiles:

```zsh
envc run matlock2/common matlock2/mcp -- \
  kch run MATLOCK_GOOGLE_CLIENT_SECRET -- python app.py
```

`run` leaves the calling shell unchanged. Its command inherits the caller's
existing environment in addition to the selected profile values; it is not a
clean-room environment. Profile-file stdout is discarded while loading for
both `run` and `env`; stderr remains visible.

`env` prints single-quoted shell `export` statements for exported scalar
variables changed by the profiles, plus statically assigned names even when a
value matches the isolated baseline. Export output contains plaintext:

```zsh
load_app_config() {
  local exports
  if exports=$(envc env matlock2/common matlock2/mcp); then
    eval "$exports"
  else
    return 1
  fi
}
load_app_config
```

Only evaluate output from this installed `envc` and trusted profile files.
The evaluation subprocess starts with only `HOME`, `USER`, and `PATH` from the
caller. Zsh code can perform arbitrary side effects; dynamically constructed
variables and shell behavior are supported when their resulting exported
scalar values differ from that baseline. `env` does not export arrays or
variables that a profile unsets. Shell environment variables cannot contain
NUL bytes.

## Security and license

Profiles are trusted executable shell code. `0600`/`0700` permissions and a
terminal-editor allowlist reduce accidental exposure but cannot guarantee
isolation from all editors, extensions, malware, privileged processes, or
other code running as the same user. Environment variables are available to
the child process and its descendants and may be observable by authorized
local processes. See [SECURITY.md](SECURITY.md).

## License

Copyright 2026 William Spratley. Licensed under the
[Apache License, Version 2.0](LICENSE).
