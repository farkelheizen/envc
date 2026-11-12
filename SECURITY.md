# Security

`envc` is for non-secret configuration. Do not store passwords, tokens,
private keys, or other credentials in profile files; use a secret manager such
as `kch` for those values. The post-edit name check is only a heuristic and
does not make it safe to store secrets here.

## Trust and execution

Profile files are sourced as Zsh code to provide sequential interpolation.
Sourcing can execute arbitrary commands, modify files, and affect the selected
child process. Only source profiles you trust. `envc env` evaluates profiles
in a subprocess with a small baseline environment and writes shell code to
stdout; that output contains plaintext and must only be evaluated when it came
from the expected `envc` executable and trusted profiles.

`envc run` does not alter the parent shell. The child inherits the caller's
environment along with the selected profile values. Environment values may be
observable to the child, its descendants, and local processes with sufficient
privileges.

## Editors and isolation

`envc edit` ignores `EDITOR` and `VISUAL`. `ENVC_EDITOR` is restricted to a
small set of terminal editor executable names; known GUI/IDE names are
rejected. Only `emacs -nw` accepts an argument. Editor launch configuration
is not evaluated by a shell.

This is a defense against accidental opening in common AI-enabled IDEs, not a
guarantee that the file cannot be observed by an editor extension or other
software. A user can replace an allowed executable, install a wrapper with an
allowed name, or run other monitoring software. Use only trusted editor
executables and installations.

## Files and permissions

Profiles are stored outside the project by default. `envc` sets app-directory
permissions to `0700` and profile permissions to `0600`. It rejects symlinked
app directories and profile files for operations that read or modify them;
listing ignores such entries. These checks reduce common path-redirection
risks, but are not a defense against a concurrent attacker able to modify the
configuration root.

The permissions protect against other unprivileged local accounts, not
malware or other processes running as the same user or with elevated
privileges. Back up profiles with the same care as other local configuration.

## Reporting

No private vulnerability reporting channel is currently configured. Do not
put sensitive vulnerability details in a public issue. Maintainers should
enable a private reporting route before publishing the project; no email
address or private channel is implied by this document.
