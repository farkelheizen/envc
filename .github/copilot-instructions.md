# Project instructions

## Project shape

- Keep `envc` a self-contained Zsh script with macOS tools as its only runtime
  dependencies.
- Follow the existing CLI parsing and error-reporting patterns. Update inline
  help and `README.md` when command behavior or options change.
- Keep changes focused. Do not silently change existing command behavior or
  compatibility; add or update tests for behavior changes.
- Keep tests in `tests/`, separate from the root `envc` executable.

## Versioning and releases

- Use Semantic Versioning (`MAJOR.MINOR.PATCH`) for releases: patch for
  backward-compatible fixes, minor for backward-compatible features, and
  major for incompatible CLI changes.
- Before `1.0.0`, minor releases may also contain incompatible CLI changes;
  document them clearly. Apply the compatibility guarantees above starting
  with `1.0.0`.
- Keep the authoritative version in `envc` and expose it with
  `envc --version` and `envc -V`. When cutting a release, make the script
  version match the Git tag `vMAJOR.MINOR.PATCH`.
- Do not bump the version or create a release tag for ordinary unreleased
  changes.
- Before tagging, run relevant checks, review user-facing documentation, and
  ensure release notes accurately describe compatibility and security
  implications.

## Plans and documentation

- Put substantial or design-dependent work plans in the ignored `docs_local/`
  directory. Record decisions, proposed behavior, implementation steps, and
  validation.
- Use `docs_local/` for planning, not as a substitute for durable project
  documentation. Put finalized user-facing behavior and contributor guidance
  in `README.md` or `CONTRIBUTING.md`.
- Treat local plans as private working material: do not stage or commit them,
  and never put secrets or sensitive user data in them.

## Validation and safety

- Run `zsh -n envc tests/test_envc.zsh` and `zsh tests/test_envc.zsh` for CLI
  changes.
- Use synthetic configuration values and mock editors only. Tests must use an
  isolated temporary `ENVC_CONFIG_DIR`; never read or write a user's real
  profiles.
- Preserve explicit error reporting and document security limitations
  honestly. Do not claim guaranteed LLM/IDE isolation.
- Do not add runtime dependencies or broaden the project beyond the requested
  change.
