# Refresh Workspace Docs

Scan the workspace directory structure and update all READMEs and CLAUDE.md to reflect the current state of the repo. Run this after adding, removing, or renaming commands, skills, agents, directories, or scripts.

## Usage

```bash
/refresh-workspace-docs         # Full scan and update of all docs
```

## Files to Update

These are the documentation files that must be kept in sync:

1. **`CLAUDE.md`** — AI context file. Contains: directory structure summary, command list with count, skills list, agents summary, integration details.
2. **`README.md`** — Root README. Contains: file structure tree, setup instructions, available commands/skills/agents overview, workflows, file naming conventions.
3. **`.claude/commands/README.md`** — Commands index. Lists all commands grouped by category with one-line descriptions.
4. **`.claude/agents/README.md`** — Agents index. Lists all agents grouped by category with one-line descriptions and total count.

## Steps

1. **Scan the current directory structure**

   Build an accurate picture of what exists right now:

   ```bash
   # Top-level directories (exclude node_modules, .git, repositories)
   ls -d */

   # Commands
   ls .claude/commands/*.md | grep -v README

   # Skills
   ls -d .claude/skills/*/

   # Agents (scan category folders)
   find .claude/agents -name '*.md' ! -name README.md

   # Scripts
   find scripts -type f -name '*.js' -o -name '*.sh' 2>/dev/null
   ```

2. **Read each documentation file**

   Read all four files listed above to understand their current content.

3. **Compare and identify drift**

   For each file, check:
   - **Commands**: Does the list match the actual `.md` files in `.claude/commands/`? Is the count correct? Are descriptions accurate?
   - **Skills**: Does the list match the actual directories in `.claude/skills/`?
   - **Agents**: Does the list match the actual `.md` files in `.claude/agents/` subdirectories? Is the count correct? Are categories correct?
   - **Directory structure**: Does the file tree in `README.md` match the actual top-level directories?
   - **Cross-references**: Do command/skill/agent counts in `CLAUDE.md` match the indexes?

4. **Generate updates**

   For each file that has drift, generate the updated content. Show the user a summary of what changed before applying:
   - Which files need updates
   - What specifically changed (added/removed/renamed items)
   - The proposed edits

5. **Apply updates after confirmation**

   After user confirmation, apply the edits to each file. Do not rewrite entire files — use targeted edits to update only the sections that drifted.

## Rules

These rules apply every time this command runs. No exceptions.

- **Only update documentation files**: This command updates READMEs and CLAUDE.md only. It never modifies commands, skills, agents, scripts, or code.
- **Scan before updating**: Always scan the actual directory to determine truth. Never assume the docs are correct.
- **Preserve manual content**: Sections like workflows, best practices, setup instructions, and integration details in README.md should not be touched unless they reference stale items (e.g., a removed directory or renamed command).
- **Always confirm**: Show the user what will change before applying edits.
- **Keep descriptions accurate**: When adding a new item to a list, read its `.md` file to write an accurate one-line description. Do not guess.
- **Consistent formatting**: Match the existing style of each file (bullet format, heading levels, grouping conventions).

## What to Check

| Section                 | Source of Truth          | Found In                              |
| ----------------------- | ------------------------ | ------------------------------------- |
| Commands list + count   | `.claude/commands/*.md`  | CLAUDE.md, commands README            |
| Skills list             | `.claude/skills/*/`      | CLAUDE.md, root README                |
| Agents list + count     | `.claude/agents/**/*.md` | CLAUDE.md, agents README, root README |
| Directory tree          | Actual top-level dirs    | Root README                           |
| File naming conventions | Actual file patterns     | CLAUDE.md, root README                |
| Setup script dirs       | `setup.sh`, `setup.js`   | Root README (setup section)           |

## Notes

- This command is idempotent — running it when everything is in sync should produce no changes.
- If a new command, skill, or agent was added but has no description in its `.md` file, flag it to the user rather than writing a placeholder.
- The `$ARGUMENTS` variable below captures any additional context the user provides.

## Additional Guidance

$ARGUMENTS
