# Research

## Sources
- Official documentation: GitHub Spec Kit repository and core command reference checked for `specify init`, `--here`, `--integration codex`, `--integration-options="--skills"`, `--script`, and `--ignore-agent-tools`.
- Mature adjacent projects: Current repository workflow already follows a lightweight Spec Kit style with `Research -> Spec -> Plan -> Tasks -> Implement -> Verify -> Commit`.
- GitHub issues or release notes: Version is pinned to Spec Kit `v0.8.7`; integration is validated locally with `specify version` and `specify check`.
- Community discussions: Not needed for this wrapper workflow change because official CLI behavior and local sandbox output are sufficient.

## Common Practice
Spec Kit projects keep generated workflow assets in `.specify/` and expose agent-specific entrypoints. For Codex skills mode, the generated entrypoints live under `.agents/skills/speckit-*` and are invoked as `$speckit-*`.

## Risks
- `specify init --here` can create or overwrite workflow files if run without inspecting generated output.
- `.agents/` may later contain agent-local state or private artifacts if other tools write into it.
- Spec Kit's generated process could conflict with the repository's existing Research Gate and production gate if treated as a replacement.
- Windows PowerShell may emit profile-policy warnings and non-UTF-8 output unless `PYTHONIOENCODING=utf-8` is set.

## Decision
Initialize Spec Kit in Codex skills mode and commit only stable workflow assets. Keep `.specify/`, `AGENTS.md`, and `.agents/skills/speckit-*`; ignore other `.agents` content by default. Treat Spec Kit as the upstream spec lifecycle layer, while this repository's approval and verification gates remain authoritative.
