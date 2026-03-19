#!/usr/bin/env bash
# =============================================================================
# setup.sh — AI Dev Pipeline — One-time setup installer
# Configures Claude Code CLI, Jira MCP, GitHub CLI, and slash commands
# =============================================================================

set -euo pipefail

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${BLUE}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
header()  { echo -e "\n${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"; echo -e "${BOLD}${CYAN}  $*${RESET}"; echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"; }

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Welcome ───────────────────────────────────────────────────────────────────
clear
echo -e "${BOLD}"
echo "  ╔══════════════════════════════════════════════════════╗"
echo "  ║        AI Dev Pipeline — Setup Installer             ║"
echo "  ║   Jira → Claude Code CLI → GitHub — Fully Automated  ║"
echo "  ╚══════════════════════════════════════════════════════╝"
echo -e "${RESET}"
echo "  This script will configure everything you need to run"
echo "  the AI-orchestrated development pipeline on your machine."
echo "  It takes about 5 minutes."
echo ""
read -rp "  Press ENTER to begin or Ctrl+C to cancel..."

# ═════════════════════════════════════════════════════════════════════════════
# STEP 1 — CHECK DEPENDENCIES
# ═════════════════════════════════════════════════════════════════════════════
header "Step 1 — Checking dependencies"

MISSING=()

check_dep() {
  local cmd=$1 name=$2 install=$3
  if command -v "$cmd" > /dev/null 2>&1; then
    success "$name found: $(command -v $cmd)"
  else
    error "$name not found"
    warn "Install with: $install"
    MISSING+=("$name")
  fi
}

check_dep "node"   "Node.js"        "https://nodejs.org or: nvm install 20"
check_dep "claude" "Claude Code CLI" "npm install -g @anthropic-ai/claude-code"
check_dep "gh"     "GitHub CLI"     "brew install gh  or  https://cli.github.com"
check_dep "git"    "Git"            "brew install git"
check_dep "curl"   "curl"           "brew install curl"
check_dep "jq"     "jq"             "brew install jq  or  apt install jq"

# Check uv
if command -v uvx > /dev/null 2>&1; then
  success "uvx found: $(command -v uvx)"
  UVX_PATH="$(command -v uvx)"
else
  warn "uvx not found — installing uv now..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
  source "$HOME/.local/bin/env" 2>/dev/null || true
  if command -v uvx > /dev/null 2>&1; then
    success "uvx installed: $(command -v uvx)"
    UVX_PATH="$(command -v uvx)"
  else
    # Try common paths
    for path in "$HOME/.local/bin/uvx" "$HOME/.cargo/bin/uvx" "/usr/local/bin/uvx"; do
      if [[ -f "$path" ]]; then
        UVX_PATH="$path"
        success "uvx found at: $UVX_PATH"
        break
      fi
    done
    if [[ -z "${UVX_PATH:-}" ]]; then
      error "Could not find uvx after installation. Install manually: curl -LsSf https://astral.sh/uv/install.sh | sh"
      MISSING+=("uvx")
    fi
  fi
fi

if [[ ${#MISSING[@]} -gt 0 ]]; then
  echo ""
  error "The following tools are missing: ${MISSING[*]}"
  error "Please install them and re-run setup.sh"
  exit 1
fi

success "All dependencies are installed"

# ═════════════════════════════════════════════════════════════════════════════
# STEP 2 — COLLECT JIRA CREDENTIALS
# ═════════════════════════════════════════════════════════════════════════════
header "Step 2 — Jira credentials"

echo "  You need a Jira API token. Get one at:"
echo -e "  ${CYAN}https://id.atlassian.com/manage-profile/security/api-tokens${RESET}"
echo ""

read -rp "  Jira URL (e.g. https://yourcompany.atlassian.net): " JIRA_URL
JIRA_URL="${JIRA_URL%/}"  # strip trailing slash

read -rp "  Jira email address: " JIRA_EMAIL

read -rsp "  Jira API token (input hidden): " JIRA_TOKEN
echo ""

# Validate credentials
info "Validating Jira credentials..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
  -u "${JIRA_EMAIL}:${JIRA_TOKEN}" \
  -H "Accept: application/json" \
  "${JIRA_URL}/rest/api/3/myself")

if [[ "$HTTP_CODE" == "200" ]]; then
  JIRA_USER=$(curl -s \
    -u "${JIRA_EMAIL}:${JIRA_TOKEN}" \
    -H "Accept: application/json" \
    "${JIRA_URL}/rest/api/3/myself" | jq -r '.displayName')
  success "Jira connected — logged in as: $JIRA_USER"
else
  error "Jira credentials invalid (HTTP $HTTP_CODE). Check your URL, email, and token."
  exit 1
fi

# ═════════════════════════════════════════════════════════════════════════════
# STEP 3 — COLLECT PROJECT INFO
# ═════════════════════════════════════════════════════════════════════════════
header "Step 3 — Project configuration"

echo "  Tell us about your project services."
echo "  Press ENTER to skip a service if you do not have it."
echo ""

read -rp "  Service 1 folder name (e.g. my-backend):        " SERVICE_1
read -rp "  Service 1 type [nextjs/java/other]:             " SERVICE_1_TYPE

read -rp "  Service 2 folder name (e.g. my-frontend):       " SERVICE_2
read -rp "  Service 2 type [nextjs/java/other]:             " SERVICE_2_TYPE

read -rp "  Service 3 folder name (e.g. my-admin-portal):   " SERVICE_3
read -rp "  Service 3 type [nextjs/java/other]:             " SERVICE_3_TYPE

read -rp "  Base branch to cut from (default: main):        " BASE_BRANCH
BASE_BRANCH="${BASE_BRANCH:-main}"

# ═════════════════════════════════════════════════════════════════════════════
# STEP 4 — CONFIGURE JIRA MCP IN ~/.claude.json
# ═════════════════════════════════════════════════════════════════════════════
header "Step 4 — Configuring Jira MCP"

CLAUDE_JSON="$HOME/.claude.json"

# Backup existing file if it has content
if [[ -f "$CLAUDE_JSON" && -s "$CLAUDE_JSON" ]]; then
  BACKUP="${CLAUDE_JSON}.backup.$(date +%Y%m%d%H%M%S)"
  cp "$CLAUDE_JSON" "$BACKUP"
  info "Backed up existing ~/.claude.json to $BACKUP"
fi

cat > "$CLAUDE_JSON" << EOF
{
  "mcpServers": {
    "jira": {
      "command": "${UVX_PATH}",
      "args": [
        "mcp-atlassian",
        "--jira-url",      "${JIRA_URL}",
        "--jira-username", "${JIRA_EMAIL}",
        "--jira-token",    "${JIRA_TOKEN}"
      ]
    }
  }
}
EOF

success "~/.claude.json written with Jira MCP config"
info "Using uvx at: $UVX_PATH"

# ═════════════════════════════════════════════════════════════════════════════
# STEP 5 — SAVE ENV VARS TO SHELL PROFILE
# ═════════════════════════════════════════════════════════════════════════════
header "Step 5 — Saving environment variables"

SHELL_PROFILE=""
if [[ -f "$HOME/.zshrc" ]]; then
  SHELL_PROFILE="$HOME/.zshrc"
elif [[ -f "$HOME/.bashrc" ]]; then
  SHELL_PROFILE="$HOME/.bashrc"
elif [[ -f "$HOME/.bash_profile" ]]; then
  SHELL_PROFILE="$HOME/.bash_profile"
fi

ENV_BLOCK="
# AI Dev Pipeline — Jira credentials
export JIRA_BASE_URL=\"${JIRA_URL}\"
export JIRA_EMAIL=\"${JIRA_EMAIL}\"
export JIRA_API_TOKEN=\"${JIRA_TOKEN}\"
"

if [[ -n "$SHELL_PROFILE" ]]; then
  # Remove existing block if present
  if grep -q "AI Dev Pipeline" "$SHELL_PROFILE" 2>/dev/null; then
    warn "Existing Jira env vars found in $SHELL_PROFILE — replacing..."
    # Remove old block
    sed -i.bak '/# AI Dev Pipeline/,/^export JIRA_API_TOKEN/d' "$SHELL_PROFILE"
  fi
  echo "$ENV_BLOCK" >> "$SHELL_PROFILE"
  success "Env vars written to $SHELL_PROFILE"
  info "Run: source $SHELL_PROFILE  (or open a new terminal)"
else
  warn "Could not find shell profile. Add these manually:"
  echo "$ENV_BLOCK"
fi

# ═════════════════════════════════════════════════════════════════════════════
# STEP 6 — AUTHENTICATE GITHUB CLI
# ═════════════════════════════════════════════════════════════════════════════
header "Step 6 — GitHub CLI authentication"

if gh auth status > /dev/null 2>&1; then
  GH_USER=$(gh api user --jq '.login' 2>/dev/null || echo "unknown")
  success "GitHub CLI already authenticated as: $GH_USER"
else
  info "GitHub CLI not authenticated. Starting login flow..."
  echo ""
  gh auth login
fi

# ═════════════════════════════════════════════════════════════════════════════
# STEP 7 — CREATE /do-ticket SLASH COMMAND
# ═════════════════════════════════════════════════════════════════════════════
header "Step 7 — Creating /do-ticket slash command"

mkdir -p "$HOME/.claude/commands"

# Build service list for the command
SERVICE_LIST=""
[[ -n "$SERVICE_1" ]] && SERVICE_LIST+="   - ${SERVICE_1}/context.md\n"
[[ -n "$SERVICE_2" ]] && SERVICE_LIST+="   - ${SERVICE_2}/context.md\n"
[[ -n "$SERVICE_3" ]] && SERVICE_LIST+="   - ${SERVICE_3}/context.md\n"

cat > "$HOME/.claude/commands/do-ticket.md" << EOF
Read CLAUDE.md first. Then implement Jira ticket \$ARGUMENTS fully:

1. Run: git checkout ${BASE_BRANCH} && git pull origin ${BASE_BRANCH}
   Always cut the new branch from the latest ${BASE_BRANCH}.

2. Fetch ticket \$ARGUMENTS via Jira MCP. Extract: summary, description,
   acceptance criteria, affected services, status.
   Stop if status is not "To Do" or "In Progress".

3. Read context.md for each affected service:
$(echo -e "$SERVICE_LIST")
4. Create branch:
   git checkout -b feat/\$ARGUMENTS-<slugified-summary>
   Slugify: lowercase, hyphens, max 50 chars after ticket ID.

5. Implement all acceptance criteria.
   Commit after each logical unit:
   git commit -m "[\$ARGUMENTS] what changed"

6. Run tests and build for each affected service.
   Next.js: npm run lint && npm run test && npm run build
   Java:    ./mvnw test && ./mvnw clean package -DskipTests
   Fix all failures before continuing.

7. Push branch and create a draft PR:
   git push --set-upstream origin <branch>
   gh pr create --draft --base ${BASE_BRANCH} \\
     --title "[\$ARGUMENTS] <ticket summary>" \\
     --body "<description and AC checklist>"

8. Use Jira MCP to transition \$ARGUMENTS to "In Review"
   and add a comment with the PR URL.

9. Print final summary: branch name, base branch (${BASE_BRANCH}),
   files changed, test results, build status, PR URL, Jira status, notes.

Stop only if: AC is ambiguous, new dependency needed, DB migration
schema unclear, or tests fail after 3 fix attempts.
EOF

success "/do-ticket command created at ~/.claude/commands/do-ticket.md"

# ═════════════════════════════════════════════════════════════════════════════
# STEP 8 — GENERATE context.md FILES
# ═════════════════════════════════════════════════════════════════════════════
header "Step 8 — Generating context.md files"

generate_context() {
  local folder=$1 type=$2
  local file="$REPO_ROOT/$folder/context.md"

  if [[ -f "$file" ]]; then
    warn "context.md already exists for $folder — skipping"
    return
  fi

  if [[ ! -d "$REPO_ROOT/$folder" ]]; then
    warn "Folder $folder does not exist — skipping context.md"
    return
  fi

  case "$type" in
    nextjs|next)
      cat > "$file" << EOF
# $folder — Service Context

## Tech Stack
- Next.js 14 (App Router)
- TypeScript (strict mode — no any types)
- Tailwind CSS
- API client: src/lib/api.ts

## Folder Structure
src/
├── app/           ← Pages and layouts
├── components/    ← Reusable UI components
├── lib/           ← API client, utilities
├── hooks/         ← Custom React hooks
└── types/         ← TypeScript definitions

## Conventions
- No fetch() in components — use src/lib/api.ts
- Tailwind only — no inline styles
- Every component needs a co-located .test.tsx file
- Strict TypeScript — no any types

## Commands
npm run dev
npm run lint
npm run test
npm run build

## Setup
cp .env.example .env.local
EOF
      success "context.md created for $folder (Next.js)"
      ;;

    java)
      cat > "$file" << EOF
# $folder — Service Context

## Tech Stack
- Java 21 / Spring Boot 3.x
- Build: Maven (./mvnw)
- Database: [fill in your DB]
- Migration: [Flyway / Liquibase — fill in]
- Tests: JUnit 5 + Mockito

## Package Structure
com.yourcompany/
├── controller/    ← REST endpoints
├── service/       ← Business logic
├── repository/    ← JPA repositories
├── entity/        ← DB entities
├── dto/           ← Request/response records
└── config/        ← Spring configuration

## Conventions
- Use records for all DTOs
- Annotate all endpoints with @Operation (Springdoc)
- Local config: src/main/resources/application-local.yml
- Never alter an entity without a DB migration file

## Commands
./mvnw spring-boot:run -Dspring-boot.run.profiles=local
./mvnw test
./mvnw clean package -DskipTests
EOF
      success "context.md created for $folder (Java)"
      ;;

    *)
      cat > "$file" << EOF
# $folder — Service Context

## Tech Stack
- [Fill in your stack]

## Folder Structure
[Fill in your folder structure]

## Conventions
[Fill in your coding conventions]

## Commands
[Fill in how to run, test, and build]
EOF
      success "context.md created for $folder (generic template)"
      ;;
  esac
}

[[ -n "$SERVICE_1" ]] && generate_context "$SERVICE_1" "$SERVICE_1_TYPE"
[[ -n "$SERVICE_2" ]] && generate_context "$SERVICE_2" "$SERVICE_2_TYPE"
[[ -n "$SERVICE_3" ]] && generate_context "$SERVICE_3" "$SERVICE_3_TYPE"

# ═════════════════════════════════════════════════════════════════════════════
# STEP 9 — VERIFY MCP CONNECTION
# ═════════════════════════════════════════════════════════════════════════════
header "Step 9 — Verifying Jira MCP"

info "Testing mcp-atlassian can start..."
if "$UVX_PATH" mcp-atlassian --help > /dev/null 2>&1; then
  success "mcp-atlassian is working"
else
  warn "mcp-atlassian test was inconclusive — verify inside Claude Code with /mcp"
fi

# ═════════════════════════════════════════════════════════════════════════════
# DONE
# ═════════════════════════════════════════════════════════════════════════════
echo ""
echo -e "${BOLD}${GREEN}"
echo "  ╔══════════════════════════════════════════════════════╗"
echo "  ║            Setup Complete!                           ║"
echo "  ╚══════════════════════════════════════════════════════╝"
echo -e "${RESET}"
echo -e "  ${BOLD}What was configured:${RESET}"
echo "   ✅  Jira MCP — connected as $JIRA_USER"
echo "   ✅  ~/.claude.json — written with uvx path"
echo "   ✅  /do-ticket command — ~/.claude/commands/do-ticket.md"
echo "   ✅  GitHub CLI — authenticated"
[[ -n "$SERVICE_1" ]] && echo "   ✅  $SERVICE_1/context.md"
[[ -n "$SERVICE_2" ]] && echo "   ✅  $SERVICE_2/context.md"
[[ -n "$SERVICE_3" ]] && echo "   ✅  $SERVICE_3/context.md"
[[ -n "$SHELL_PROFILE" ]] && echo "   ✅  Jira env vars — $SHELL_PROFILE"
echo ""
echo -e "  ${BOLD}Next steps:${RESET}"
echo ""
echo "   1. Open a new terminal tab (to load env vars)"
echo "   2. Navigate to your project:"
echo -e "      ${CYAN}cd $(pwd)${RESET}"
echo "   3. Start Claude Code:"
echo -e "      ${CYAN}claude${RESET}"
echo "   4. Verify Jira is connected:"
echo -e "      ${CYAN}/mcp${RESET}"
echo "   5. Run your first ticket:"
echo -e "      ${CYAN}/do-ticket YOUR-TICKET-ID${RESET}"
echo ""
echo -e "  ${BOLD}Need help?${RESET} See README.md"
echo ""
