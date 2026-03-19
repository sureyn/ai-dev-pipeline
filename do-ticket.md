Read CLAUDE.md first. Then implement Jira ticket $ARGUMENTS fully:

1. Run: git checkout main && git pull origin main
   Always cut the new branch from the latest main.

2. Fetch ticket $ARGUMENTS via Jira MCP. Extract: summary, description,
   acceptance criteria, affected services, status.
   Stop if status is not "To Do" or "In Progress".

3. Read context.md for each affected service.

4. Create branch:
   git checkout -b feat/$ARGUMENTS-<slugified-summary>
   Slugify: lowercase, hyphens, max 50 chars after ticket ID.

5. Implement all acceptance criteria.
   Commit after each logical unit:
   git commit -m "[$ARGUMENTS] what changed"

6. Run tests and build for each affected service.
   Next.js: npm run lint && npm run test && npm run build
   Java:    ./mvnw test && ./mvnw clean package -DskipTests
   Fix all failures before continuing.

7. Push branch and create a draft PR:
   git push --set-upstream origin <branch>
   gh pr create --draft --base main \
     --title "[$ARGUMENTS] <ticket summary>" \
     --body "<description and AC checklist>"

8. Use Jira MCP to transition $ARGUMENTS to "In Review"
   and add a comment with the PR URL.

9. Print final summary: branch name, base branch (main),
   files changed, test results, build status, PR URL, Jira status, notes.

Stop only if: AC is ambiguous, new dependency needed, DB migration
schema unclear, or tests fail after 3 fix attempts.
