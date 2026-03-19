# CLAUDE.md — AI Dev Pipeline Operating Manual

This file is read by Claude Code CLI at the start of every session.
Follow every rule and convention here before writing any code.

---

## Project Structure

This is a monorepo. It contains multiple services. Before touching any service,
read its `context.md` file to understand its architecture and conventions.

| Service folder | context.md |
|---|---|
| [your-service-1] | [your-service-1]/context.md |
| [your-service-2] | [your-service-2]/context.md |
| [your-service-3] | [your-service-3]/context.md |

> Update this table with your actual service folder names after setup.

---

## Workflow — Ticket to Pull Request

When given a ticket ID, follow these steps in order. Do not skip any step.

### Step 1 — Always start from the base branch
```bash
git checkout main && git pull origin main
```

### Step 2 — Fetch the ticket
Use the Jira MCP tool to fetch the ticket. Extract:
- `ticket_id`
- `summary`
- `description`
- `acceptance_criteria` — every AC item
- `affected_services` — which services to touch
- `status`

Stop immediately if status is not `To Do` or `In Progress`.

### Step 3 — Read service context
For each service listed in `affected_services`, read its `context.md`.
Understand the architecture and patterns before writing any code.
Do not invent new patterns if existing ones solve the problem.

### Step 4 — Create the branch
```bash
git checkout -b feat/<TICKET_ID>-<slugified-summary>
```
Slug rules: lowercase, hyphens only, max 50 chars after the ticket ID.

### Step 5 — Implement the changes
Work through every acceptance criteria item one by one.
Commit after each logical unit:
```bash
git commit -m "[<TICKET_ID>] what changed"
```

### Step 6 — Run tests and build
Run for every affected service. Fix all failures before creating the PR.

**Next.js:**
```bash
npm run lint
npm run test
npm run build
```

**Java / Spring Boot:**
```bash
./mvnw test
./mvnw clean package -DskipTests
```

### Step 7 — Create the pull request
```bash
git push --set-upstream origin <branch>
gh pr create --draft --base main \
  --title "[<TICKET_ID>] <ticket summary>" \
  --body "<description and AC checklist>"
```

### Step 8 — Update Jira
Use the Jira MCP tool to:
- Transition the ticket to `In Review`
- Add a comment with the PR URL

### Step 9 — Print final summary
```
✅ Ticket:     <TICKET_ID> — <summary>
🌿 Branch:     <branch name>
📂 Files:      <list of changed files with one-line reason each>
🧪 Tests:      <pass count> passing, 0 failing
🏗️  Build:      <service> ✓
🔗 PR:         <PR URL>
🎟️  Jira:       Transitioned to In Review — PR link added
⚠️  Notes:      <anything the reviewer must know>
```

---

## Coding Conventions

### All services
- No secrets or API keys in code — use environment variables
- Write tests alongside every new function, component, or endpoint
- One ticket = one PR — never bundle multiple tickets
- Never push directly to `main`

### Next.js (TypeScript)
- Strict TypeScript — no `any` types
- Components in `src/components/`, pages in `src/app/`
- All API calls through the shared API client — never raw `fetch()` in components
- Tailwind CSS only — no inline styles
- Every new component needs a co-located `.test.tsx` file

### Java 21 (Spring Boot)
- Use records for all DTOs
- Annotate all new endpoints with `@Operation` (Springdoc / OpenAPI)
- Create a DB migration file before altering any entity
- Local profile: `src/main/resources/application-local.yml`

---

## Hard Rules — Never Violate These

- Never modify files listed in a ticket's "What Must NOT Change" section
- Never add a new npm or Maven dependency without noting it in the PR description
- Never create a database migration without confirming the schema with the developer
- Never commit `.env` files, API keys, or credentials
- Never push to `main` directly — always PR

---

## When to Stop and Ask

Stop and ask the developer only if:
- Acceptance criteria are ambiguous or contradictory
- A new external dependency (npm package / Maven artifact) is required
- A database migration is needed and the schema is unclear
- A test has failed more than 3 times and the root cause is in pre-existing code
- The Jira ticket fetch returns an error or empty content

In all other cases, use best judgment and document decisions in the PR
body under a section called **AI Notes**.
