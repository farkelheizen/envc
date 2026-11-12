# Contributing

The runtime is a single Zsh script with no installed runtime dependencies.
Run the local syntax, whitespace, and CLI tests on macOS with Zsh:

```zsh
zsh -n envc tests/test_envc.zsh
zsh tests/test_envc.zsh
```

Tests create an isolated temporary `ENVC_CONFIG_DIR` and remove it on exit.
Use only synthetic configuration values and mock editors. Never add real
secrets or copy a user's profiles into tests, fixtures, output, or issues.

Check `git status` before staging. `docs_local/` is intentionally ignored and
contains transient plans and local reference material; do not force-add it or
the local `kch` reference.

This project is licensed under Apache-2.0; see [LICENSE](LICENSE). See
[SECURITY.md](SECURITY.md) for the current reporting status.
