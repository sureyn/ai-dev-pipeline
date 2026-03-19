# AI Dev Pipeline 🤖

> **Jira ticket in → Tested pull request out. One command.**

An AI-orchestrated development pipeline that connects Jira, Claude Code CLI,
and GitHub so a single command takes a ticket from **To Do** to a reviewed
pull request — with zero manual context switching.

```bash
/do-ticket LVP-47
```

That's it. Claude Code reads the ticket, understands your codebase, creates
the branch, writes the code, runs tests, fixes failures, and opens a PR.

---

## How it works

```
PM writes Jira ticket (9-section template)
         ↓
Developer runs /do-ticket LVP-47 in Claude Code CLI
         ↓
Claude reads CLAUDE.md + fetches ticket via Jira MCP
         ↓
Claude reads context.md for each affected service
         ↓
git checkout main && git pull
         ↓
Creates branch: feat/LVP-47-ticket-summary
         ↓
Writes code + commits incrementally
         ↓
Runs lint + tests + build — fixes failures
         ↓
Creates draft PR targeting main
         ↓
Updates Jira ticket to In Review + posts PR link
         ↓
Developer reviews and merges
```

---

## Setup (5 minutes)

### Prerequisites

| Tool | Install |
|---|---|
| Node.js 20+ | https://nodejs.org |
| Claude Code CLI | `npm install -g @anthropic-ai/claude-code` |
| GitHub CLI | `brew install gh` |
| jq | `brew install jq` |
| uv | Auto-installed by setup.sh |

You also need:
- A **Jira Cloud** account with API access
- A **Jira API token** from [id.atlassian.com/manage-profile/security/api-tokens](https://id.atlassian.com/manage-profile/security/api-tokens)

### Run the installer

```bash
# 1. Clone this repo into your project root
git clone https://github.com/yourname/ai-dev-pipeline .

# 2. Run setup
chmod +x setup.sh
./setup.sh
```

The setup script will:
- ✅ Check all dependencies are installed
- ✅ Validate your Jira credentials
- ✅ Ask for your service folder names
- ✅ Write `~/.claude.json` with the Jira MCP config
- ✅ Save Jira env vars to your shell profile
- ✅ Authenticate GitHub CLI
- ✅ Create the `/do-ticket` slash command
- ✅ Generate `context.md` templates for each service

### After setup

```bash
# Open a new terminal to load env vars
cd /your/project/root
claude
```

Inside Claude Code:
```
/mcp           ← verify jira shows green tick
/do-ticket LVP-47
```

---

## File structure

```
your-repo/
├── setup.sh                    ← Run once to configure everything
├── CLAUDE.md                   ← AI operating manual (read at session start)
├── JIRA_TICKET_TEMPLATE.md     ← Template for PMs to write tickets
├── .env.example                ← Reference for required env vars
├── .claude/
│   └── commands/
│       └── do-ticket.md        ← /do-ticket slash command definition
├── service-a/
│   └── context.md              ← Architecture notes for service-a
├── service-b/
│   └── context.md              ← Architecture notes for service-b
└── service-c/
    └── context.md              ← Architecture notes for service-c
```

**Global files** (on your machine, not in the repo):

| File | Purpose |
|---|---|
| `~/.claude.json` | Jira MCP config — written by setup.sh |
| `~/.claude/commands/do-ticket.md` | Slash command — written by setup.sh |

---

## Writing Jira tickets

Use the `JIRA_TICKET_TEMPLATE.md` file. Fill in all 9 sections and paste
into the Jira ticket Description field. The AI reads every section.

**The most important sections:**
- **Section 4 — What Must Happen** — write each AC as: `Given X, when Y, then Z`
- **Section 5 — What Must NOT Change** — be specific about files to leave alone
- **Section 9 — AI Metadata** — fill in affected_services with your folder names

---

## Customising for your project

### 1. Update CLAUDE.md
Edit the services table to match your actual folder names.
Add any project-specific conventions your team follows.

### 2. Fill in context.md for each service
The auto-generated files are templates. Fill in:
- Your actual tech stack and versions
- Your real folder structure
- Your team's coding conventions
- The exact commands to run tests and builds

### 3. Update do-ticket.md if needed
Located at `~/.claude/commands/do-ticket.md`.
Edit the service list to match your folder names.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| `/mcp` shows no servers | Check `~/.claude.json` has `mcpServers` block |
| jira shows red cross | Use full path to uvx — run `which uvx` and update `~/.claude.json` |
| Branch has wrong name | Ensure `do-ticket.md` uses `$ARGUMENTS` not `<ticket-id>` |
| PR targets wrong branch | Check step 7 in `do-ticket.md` says `--base main` |
| Jira not transitioning | Check `JIRA_BASE_URL`, `JIRA_EMAIL`, `JIRA_API_TOKEN` env vars are set |
| Claude modifies wrong files | Strengthen Section 5 of the ticket with exact file paths |

---

## What makes this an agentic workflow

This pipeline is a **multi-tool autonomous coding agent**:

| Property | What it does |
|---|---|
| **Perceives** | Reads Jira ticket, CLAUDE.md, context.md files |
| **Plans** | Maps ticket requirements to code changes across services |
| **Acts** | Writes code, runs commands, calls APIs |
| **Observes** | Reads test output, fixes failures, retries |
| **Loops** | Continues until all tests pass |
| **Uses tools** | Jira MCP, Git, GitHub CLI, test runners |

---

## Tech stack

- **Claude Code CLI** — the AI agent
- **Model Context Protocol (MCP)** — Jira integration
- **mcp-atlassian** — Jira MCP server (runs via uvx)
- **GitHub CLI (gh)** — pull request automation
- **Jira REST API** — ticket management

---

## Contributing

1. Fork this repo
2. Run `./setup.sh` to configure your environment
3. Make your changes
4. Open a PR — ideally using `/do-ticket` 😄

---

## License

MIT — use freely, attribution appreciated.
