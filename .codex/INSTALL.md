# dev-sensei -- Codex Installation Guide

This guide covers manual installation of dev-sensei for OpenAI Codex CLI.
For Claude Code, hooks and skills are loaded automatically via `plugin.json`.

---

## Prerequisites

- OpenAI Codex CLI installed and configured
- A working project directory where you want dev-sensei active

## Step 1: Symlink the Skills Folder

Codex does not auto-discover plugin skill files. You must symlink the
`skills/` folder into your Codex instructions directory.

```bash
# From your project root:
ln -s /path/to/dev-sensei/skills/ .codex/skills

# Or copy if symlinks cause issues on your OS:
cp -r /path/to/dev-sensei/skills/ .codex/skills/
```

Then reference the skill files in your Codex system prompt or instructions
file (`.codex/instructions.md`):

```markdown
<!-- .codex/instructions.md -->
You are augmented with the dev-sensei mentor system.

Follow the rules in these files:
- .codex/skills/struggle-gate/SKILL.md
- .codex/skills/why-mode/SKILL.md
- .codex/skills/pattern-recognizer/SKILL.md
- .codex/skills/incident-mentor/SKILL.md
```

## Step 2: Register Hooks Manually

Codex does not support the same hook system as Claude Code. To replicate
the ship-gate behavior, you have two options:

### Option A: Git Hook (Recommended)

Install ship-gate as a git `pre-commit` hook:

```bash
cp /path/to/dev-sensei/hooks/ship-gate.sh .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

This runs the 3-question gate every time `git commit` is executed,
regardless of whether Codex or the developer initiates the commit.

### Option B: Codex Instructions Override

Add a commit-time instruction to `.codex/instructions.md`:

```markdown
## Commit Rule

Before every git commit, you MUST ask the developer these 3 questions
and receive non-empty answers:

1. Why did you choose this approach? Were there alternatives?
2. What is the biggest weakness of this code?
3. Will this code survive 10x traffic/data growth?

Do NOT proceed with the commit until all 3 are answered.
```

## Step 3: Verify Installation

```bash
# Check symlinks are in place
ls -la .codex/skills/

# Test the ship-gate hook
echo "" | .git/hooks/pre-commit
# Should exit with code 1 (empty answers blocked)
```

## Platform Differences from Claude Code

| Feature              | Claude Code                          | Codex                                  |
|----------------------|--------------------------------------|----------------------------------------|
| Skill loading        | Automatic via `plugin.json`          | Manual symlink + instructions file     |
| Hook system          | `PreToolUse` event with matchers     | Not supported; use git hooks instead   |
| Hook trigger         | Intercepts before tool execution     | Git hook runs at `git commit` time     |
| Async hooks          | Supported (`"async": true/false`)    | Not applicable                         |
| Slash commands       | Native skill invocation              | Must be described in instructions      |
| Plugin discovery     | `.claude-plugin/plugin.json`         | No plugin manifest; manual setup only  |
| SKILL.md parsing     | Parsed and injected into context     | Must be referenced in instructions.md  |

## Troubleshooting

**Skills not activating:**
Ensure `.codex/instructions.md` explicitly references each SKILL.md file
with a clear directive to follow those rules.

**Ship-gate not running:**
Check that `.git/hooks/pre-commit` is executable (`chmod +x`).

**Symlink not working on Windows:**
Use `cp -r` instead of `ln -s`, or enable Developer Mode for symlink
support on Windows 10+.
