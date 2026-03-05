<div align="center">

# 🎋 dev-sensei

**Stop shipping code you don't understand.**

[![MIT License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude_Code-Plugin-blueviolet)](https://claude.ai)
[![Codex](https://img.shields.io/badge/Codex-Compatible-orange)](https://openai.com)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

dev-sensei transforms Claude Code and Codex from **answer machines** into **Socratic senior dev mentors**.

Based on the 5 strategies from ["AI is Making Junior Devs Useless"](https://www.beabetterdev.com).

</div>

---

## The Problem

AI gave you the code and you just ran with it. Sound familiar?

Senior developers are expensive not because they type faster — but because they've **survived failures**. Years of 2 AM incidents, broken architectures, and painful debugging sessions built their **pattern recognition**. Junior devs using AI skip this entire process, creating a generation of developers who can ship fast but can't explain why.

This is **shallow competence** — and it's the biggest risk in AI-assisted development.

## How dev-sensei Fixes This

dev-sensei intercepts your AI workflow at 5 critical points, forcing the kind of struggle that builds real engineering skill.

| Skill / Hook | Strategy | Triggers On | What It Does |
|---|---|---|---|
| **struggle-gate** | Manufacture the struggle | error, bug, crash, fix | Forces 3-step debugging before giving hints |
| **why-mode** | Prompt for the "why" | `/why-mode` (manual) | Every answer shows tradeoffs, never single solutions |
| **pattern-recognizer** | Learn the fundamentals | code review, refactoring | Makes YOU evaluate code before AI does |
| **incident-mentor** | Study real failures | cache, DB, async, memory | Connects your code to real production disasters |
| **ship-gate** | Never ship what you don't understand | `git commit` | 3 mandatory questions before every commit |

## Before / After

### Without dev-sensei:
```
You:    "TypeError: Cannot read property 'id' of undefined"
Claude: "The user object is undefined. Use optional chaining: user?.id"
```
You learned nothing. You'll make the same mistake tomorrow.

### With dev-sensei:
```
You:    "TypeError: Cannot read property 'id' of undefined"
Claude: "스택 트레이스 몇 번째 줄이 문제 같아요? 어느 부분에서 터진 것 같아요?"
You:    "23번째 줄이요, fetchUser 함수에서"
Claude: "그 시점에 user가 왜 없을 것 같아요? 가설이 뭔지 말해봐요."
You:    "아... API 호출이 실패했을 때 user가 null일 수 있겠네요"
Claude: "좋아요. 로그에서 실제로 API 응답을 확인해봤어요?"
```
You found it yourself. You'll recognize this pattern forever.

## Installation

### Claude Code
```bash
# Clone the repo
git clone https://github.com/SimonUncle/dev-sensei.git

# Install as Claude Code plugin
cd dev-sensei
claude --plugin-dir .
```

> **Tip:** To make it permanent, you can register the plugin in `~/.claude/plugins/installed_plugins.json`.
> See [.codex/INSTALL.md](.codex/INSTALL.md) for detailed manual setup.

### Codex
See [.codex/INSTALL.md](.codex/INSTALL.md) for manual setup instructions.

## Skills Overview

### 🚧 struggle-gate (Auto)
Activates on any error, bug, or debugging request. Forces you through a 3-step Socratic process:
1. **Locate** — Where in the code is the problem?
2. **Hypothesize** — Why do you think it's happening?
3. **Verify** — Did you check the logs? Trace the code?

Only after all 3 steps does it provide hints — and even then, just direction, never the answer.

### 🤔 why-mode (Manual: `/why-mode`)
Activates manually. Every response becomes a structured comparison:
```
┌─ Approach A: [Name]
│  Pros: ...  Cons: ...  Best for: ...
├─ Approach B: [Name]
│  Pros: ...  Cons: ...  Best for: ...
└─ My recommendation: [Choice]
   Reason: [Context-based rationale]
```
Ends with: "What matters most in your situation right now?"

### 🔍 pattern-recognizer (Auto)
Activates on code completion, review requests, or AI-generated code. Instead of evaluating your code, it makes **you** evaluate it:
- "What patterns are being used here?"
- "If you were the code reviewer, what would you flag?"
- "What's the biggest weakness in this structure?"

### 🔥 incident-mentor (Auto)
Activates when you work with cache, databases, microservices, concurrency, or memory. Connects your code to **real production incidents**:
- Instagram's 2012 thundering herd (cache stampede)
- GitHub's N+1 query nightmares
- AWS us-east-1 2012 cascading failure
- Financial system race conditions (Flexcoin: 896 BTC lost)
- Node.js memory leaks in production (Walmart Black Friday)

If your pattern doesn't match a built-in case, it searches the web for real postmortems.

### 🚢 ship-gate (Hook: `git commit`)
Intercepts every commit with 3 questions:
1. Why did you choose this approach?
2. What's the biggest weakness in this code?
3. Would this survive 10x traffic/data?

Empty answers = blocked commit. Your answers are recorded in the commit for future reference.

## Why I Built This

The AI revolution isn't making developers better — it's making them faster at being mediocre. The developers who will thrive aren't the ones who prompt the best. They're the ones who **understand what AI gives them**.

dev-sensei doesn't slow you down. It makes you **think** at the speed you ship.

> "The goal is not to use AI less. It's to understand more." — dev-sensei philosophy

## Contributing

We welcome contributions! Especially:

### Add Incident References
The `skills/incident-mentor/references/` directory contains real production incident case studies. We'd love more:
- **Planned patterns**: deadlock, split-brain, hot-partition, connection-pool-exhaustion, retry-storm
- Follow the existing format: incident context → timeline → root cause → code examples → fix → lessons → detection guide
- PR with a new `.md` file in `references/`

### Add New Skills
Skills are markdown files in `skills/[name]/SKILL.md`. Follow the existing patterns for frontmatter and behavior description.

### Improve Tests
Test files in `tests/` contain trigger/no-trigger queries. More edge cases are always welcome.

## Project Structure

```
dev-sensei/
├── .claude-plugin/plugin.json    # Plugin manifest
├── .codex/INSTALL.md             # Codex setup guide
├── skills/
│   ├── struggle-gate/SKILL.md    # Socratic debugging
│   ├── why-mode/SKILL.md         # Tradeoff analysis
│   ├── pattern-recognizer/SKILL.md # Code evaluation
│   └── incident-mentor/
│       ├── SKILL.md              # Incident connection
│       └── references/           # Real incident cases
│           ├── thundering-herd.md
│           ├── n-plus-one.md
│           ├── cascading-failure.md
│           ├── race-condition.md
│           └── memory-leak.md
├── hooks/
│   ├── hooks.json                # Hook registration
│   └── ship-gate.sh              # Commit gate script
├── tests/                        # Trigger test cases
└── README.md
```

## License

[MIT](LICENSE) — Use it, fork it, make it better.

---

<div align="center">

**Built with frustration about shallow competence and hope for the next generation of developers.**

[Report Bug](https://github.com/gim-yujin/dev-sensei/issues) · [Request Feature](https://github.com/gim-yujin/dev-sensei/issues) · [Contribute](https://github.com/gim-yujin/dev-sensei/pulls)

</div>
