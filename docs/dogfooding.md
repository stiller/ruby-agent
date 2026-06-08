# Dogfooding ragent

Running ragent against its own repository is a good way to validate the harness,
explore its behaviour, and find things worth improving.

## Before you start

Make sure the image is built and your API key is set:

```bash
docker compose build
export OPENAI_API_KEY=sk-...
```

All examples below assume you are in the `ruby-agent` repository root.

---

## Phase 1 — Read-only exploration

Mount the repository read-only so the agent can look around but cannot change
anything. This is the safer starting point for getting familiar with a codebase.

```bash
WORKSPACE_PATH=$(pwd) docker compose -f docker-compose.yml -f docker-compose.ro.yml \
  run --rm ragent --allow-commands
```

> **Safety**: `/workspace` is read-only. The agent can read files, run searches,
> and propose patches, but cannot apply them. Any `bundle exec` or `git` commands
> it proposes run inside the container, but this is containment rather than hard
> sandboxing.

### Suggested prompts

**Summarise the repository**
```
summarize this repository: its purpose, main components, and how they fit together
```

**Find TODOs**
```
search for TODO, FIXME, and HACK comments across the codebase and list them with file and line number
```

**Suggest a refactor**
```
look at lib/ragent/runner.rb and suggest one concrete refactoring that would improve
readability without changing behaviour
```

---

## Phase 2 — Edits on a throwaway branch

Create a branch so any changes are easy to inspect and discard:

```bash
git checkout -b dogfood-$(date +%Y%m%d)
```

Run the agent with write access and command execution enabled:

```bash
WORKSPACE_PATH=$(pwd) docker compose run --rm ragent --allow-commands
```

> **Safety warnings**
>
> - The agent has write access to the repository. Review every proposed patch
>   before approving it.
> - `--allow-commands` lets the agent propose shell commands. Read the command
>   and reason before typing `y`.
> - The agent runs as root inside the container. A malicious or confused prompt
>   could modify files, run `git reset`, or install packages.
> - When in doubt, deny the command (`n`) and rephrase the prompt more narrowly.

### Suggested prompts

**Apply a tiny patch**
```
add a comment above the MAX_ITERATIONS constant in lib/ragent/agent_loop.rb
explaining what happens when the limit is reached
```
Review the proposed diff, approve it with `y`, then check the result:
```bash
git diff lib/ragent/agent_loop.rb
```

**Run the test suite**
```
run the test suite and report which tests pass and fail
```
The agent will propose `bundle exec rake`. Approve it and watch the output.

**Fix a real issue**
```
run rubocop and fix any offenses it finds
```

---

## Phase 3 — Inspect and clean up

After experimenting, review what changed:

```bash
git diff main
git log --oneline main..HEAD
```

Keep anything useful, discard the rest:

```bash
git checkout main
git branch -D dogfood-$(date +%Y%m%d)
```

Run artifacts (transcripts, patches) are written to `.ragent/runs/` in the
repository. They are useful for reviewing what the agent did step by step.
Delete them when done:

```bash
rm -rf .ragent/runs/
```

---

## Tips

- **Use `--debug`** to see model request sizes and tool call JSON:
  ```bash
  WORKSPACE_PATH=$(pwd) docker compose run --rm ragent --debug
  ```
- **Use the REPL** (no prompt argument) for multi-turn sessions where you want
  to follow up on answers without losing conversation history.
- **Be specific**. Narrow prompts produce better results than open-ended ones.
  "Refactor the `build_registry` method to reduce its line count" works better
  than "improve the code".
- **Start read-only**. Even when you intend to make changes, start with a
  read-only session to understand the codebase first, then switch to a write
  session with a focused prompt.
