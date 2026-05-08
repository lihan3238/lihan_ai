# Research

## Sources
- GitHub Spec Kit repository: specification-driven development with lifecycle artifacts and checks. https://github.com/github/spec-kit
- GitHub Spec Kit reference: `specify` manages lifecycle setup, workflow automation, agent integrations, presets, and extensions. https://github.com/github/spec-kit/blob/main/docs/reference/overview.md
- GitHub Spec Kit integrations reference: Codex integration is skills-based and `specify init` installs the agent-specific structure. https://github.com/github/spec-kit/blob/main/docs/reference/integrations.md
- Superpowers local skills: agent discipline for brainstorming, planning, TDD, debugging, and verification.
- Current repository scripts and docs: wrapper-first New API operations, backup, restore, E2E, and production gates.

## Common Practice
AI-assisted development works best when the project separates product intent, technical plan, executable tasks, and verification evidence. External tools such as Spec Kit provide artifact structure; execution frameworks such as Superpowers provide discipline during implementation.

## Risks
- Duplicate workflow systems can conflict if both generate templates, agent instructions, or approval gates.
- Cleanup can accidentally remove useful operational scripts if no evidence proves they are stale.
- Documentation drift can cause agents to skip Research Gate, implementation approval, or production gates.

## Decision
Keep the repo-native workflow as the active standard, keep official Spec Kit as a sandboxed future integration, and clean only conflicts that are proven by repository inspection or tests.
