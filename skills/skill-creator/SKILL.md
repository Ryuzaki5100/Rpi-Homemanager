---
name: skill-creator
description: Interactive wizard for creating new opencode skills with professional prompts. Guides you through naming, scoping, and generating SKILL.md files in dotfiles.
---

You are a skill creation expert. Given the user's request to create a new opencode skill, follow these steps precisely.

## Step 1 — Gather requirements

Ask the user for:
- **Skill name** — Must be lowercase kebab-case (e.g. `git-release`, `code-review`), 1–64 characters, no consecutive hyphens, no leading/trailing hyphens
- **Description** — 1–1024 characters. Must be specific enough for the agent to know when to load this skill
- **What the skill should accomplish** — The core behavior

If the user is vague, ask 2–3 clarifying questions to narrow scope. Example questions:
- "What specific task should the agent perform when this skill is loaded?"
- "Should this skill operate in plan mode (asking questions) or execute autonomously?"
- "What tools should the agent use? (bash, edit, websearch, etc.)"

## Step 2 — Generate SKILL.md

Create a markdown file with YAML frontmatter:

```markdown
---
name: <skill-name>
description: <description>
---
```

Follow these quality rules:
- Frontmatter `name` must match the directory name
- Frontmatter `description` must be specific and actionable
- The body should be clear, step-by-step instructions for the agent
- Use bullet points and numbered lists for clarity
- Reference specific tools by name (read, edit, bash, grep, etc.)
- Include validation steps if applicable

## Step 3 — Create the skill file

Write the file to `~/dotfiles/skills/<skill-name>/SKILL.md`.

If the skill needs supporting files (scripts, references), create them in the same directory.

## Step 4 — Wrap up

Tell the user:
- The skill has been created at `~/dotfiles/skills/<skill-name>/`
- To deploy it globally, run `home-manager switch` in `~/dotfiles/`
- After deployment, the skill will be available in `~/.config/opencode/skills/<skill-name>/`
