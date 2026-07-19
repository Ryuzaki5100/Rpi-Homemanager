---
name: update-docs
description: Analyzes git changes (working tree diff + recent commits) to identify and update outdated documentation. Creates new documentation from scratch if none exists. Operates conservatively — updates only what changed without unnecessary rewrites.
---

You are a documentation maintenance expert. When this skill is loaded, analyze the repository's git changes and update documentation accordingly. Be conservative — don't rewrite unchanged sections, but be thorough about documenting new changes.

## Step 1 — Investigate changes

1. Run `git diff` to inspect unstaged changes in the working tree.
2. Run `git diff --cached` to inspect staged changes.
3. Run `git log --oneline -20` to review recent commit messages for broader context.
4. Run `git diff HEAD~5..HEAD` if there are many recent changes.
5. Identify which files were added, modified, or deleted.
6. Categorize changes (new features, API changes, config changes, bug fixes, refactors, formatting-only, etc.).
7. If changes are purely cosmetic/formatting, stop — no doc update needed.

## Step 2 — Discover existing documentation

1. Search for documentation files: `README.md`, `CONTRIBUTING.md`, `CHANGELOG.md`, `docs/`, `wiki/`, etc. Use `glob` or `grep`.
2. Read the main documentation to understand the current structure, tone, and style.
3. Map which documentation sections correspond to the changed areas.

## Step 3 — Update existing documentation

1. For each affected area, locate the corresponding section and update it.
2. Follow these principles:
   - **Conservative** — Update only sections directly affected by changes. Never rewrite unrelated content.
   - **Professional & maintainable** — Match the existing tone. Use clear, concise language.
   - **Elaborate where needed** — If a change is significant, add explanatory context (what changed and why).
   - **No restructuring** — Keep the existing document structure unless the changes are massive (50%+ of codebase or major architectural shift), and in that case ask the user before restructuring.
3. Use `edit` to make targeted changes to documentation files.

## Step 4 — Create documentation (if none exists)

1. If no README.md or docs/ directory exists, analyze the full repository:
   - Read key config files (package.json, Cargo.toml, pyproject.toml, etc.) to understand the project.
   - Explore the directory tree and identify main entry points, modules, and architecture.
   - Read source files to understand functionality.
2. Create a comprehensive README.md covering:
   - Project name and description
   - Quick start / installation
   - Basic usage examples
   - Project structure overview
   - Configuration (if applicable)
3. Create additional docs only if meaningful (API guide, configuration reference, etc.). Don't over-document.

## Step 5 — Validate

1. Re-read all changed documentation to ensure accuracy.
2. Verify no broken references (links, file paths, CLI flag names, etc.).
3. Confirm the docs match actual code behavior.
4. Run `git diff` to review your changes before finishing.
