# Ruby Agent

An agentic coding harness written in plain Ruby.

<img width="758" height="450" alt="Screenshot 2026-06-06 at 18 14 59" src="https://github.com/user-attachments/assets/c308bd49-9469-42df-b048-b40b97733626" />

<img width="757" height="452" alt="Screenshot 2026-06-06 at 18 15 51" src="https://github.com/user-attachments/assets/6b66cade-121d-461a-82ea-0767df3a3ae2" />

<img width="756" height="214" alt="Screenshot 2026-06-06 at 18 16 42" src="https://github.com/user-attachments/assets/7630399c-a351-484c-99c9-06b5792d7ce5" />

## Setup

```bash
bundle install
chmod +x bin/ragent
```

## Usage

Pass a prompt as the first argument:

```bash
bin/ragent --repo /path/to/repo "explain what this project does"
```

### Options

| Flag | Description |
|---|---|
| `--repo PATH` | Path to the target repository (default: `/workspace`) |
| `--yes` | Auto-approve all proposed patches without prompting |
| `--allow-commands` | Allow the agent to propose and run shell commands |
| `--clean-runs` | Delete run artifacts after the session ends |
| `--artifact-dir PATH` | Store run artifacts in a custom directory (default: `<repo>/.ragent/runs/`) |
| `--allow-external-artifacts` | Allow `--artifact-dir` to point outside the repository |

Run artifacts (transcript, patches, checkpoint) are written to
`<repo>/.ragent/runs/<timestamp>/` and kept after the session for inspection and rollback.
Pass `--clean-runs` to delete them automatically when the session ends.

The workspace defaults to the `RAGENT_WORKSPACE` environment variable (default: `/workspace`).

## Proposing patches

The agent proposes code changes as unified diffs. By default it prompts you to review
and approve each patch before applying it:

```
Apply this patch? [y/N]
```

Pass `--yes` to auto-approve all patches:

```bash
bin/ragent --repo /path/to/repo --yes "fix the typo in README"
```

Before applying, ragent saves a checkpoint so the change can be rolled back.

## Shell commands

By default the agent can read files but cannot run shell commands. Pass
`--allow-commands` to enable command proposals:

```bash
bin/ragent --repo /path/to/repo --allow-commands "run the test suite and fix any failures"
```

Each proposed command shows the command and reason, then prompts for approval:

```
$ bundle exec rake test
Reason: run the test suite to check for failures
Run this command? [y/N]
```

Pass both `--yes` and `--allow-commands` to auto-approve commands as well as patches:

```bash
bin/ragent --repo /path/to/repo --yes --allow-commands "..."
```

### Dangerous command rejection

Ragent always rejects commands that touch destructive targets regardless of any other
settings: recursive root deletes, `dd`, `mkfs`, `shutdown`, `reboot`, curl/wget piped
to a shell, `/etc`, and `~/.ssh`.

## Configuration

Ragent reads `.ragent.yml` from the repo root if it exists. All keys are optional.
An invalid value produces a clear error at startup.

```yaml
# Auto-approve patches without prompting ('ask' is the default).
approval_mode: auto

# Command prefixes that run without a prompt when --allow-commands is set.
allowed_commands:
  - bundle exec rake test
  - bundle exec rubocop
  - npm test
  - pytest

# Directory names to exclude from file listing and search.
ignored_paths:
  - dist
  - coverage
  - .cache

# Maximum file size ragent will read, in bytes (default: 102400).
max_file_size: 51200

# Maximum number of search matches returned (default: 50).
max_search_results: 100
```

### approval_mode

| Value | Behaviour |
|---|---|
| `ask` | Prompt before applying each patch (default) |
| `auto` | Auto-approve patches — equivalent to passing `--yes` |

### allowed_commands

A command matches if it equals a listed prefix exactly or starts with the prefix
followed by a space (`bundle exec rake test --verbose` matches `bundle exec rake test`).
`--allow-commands` must still be passed for the agent to propose commands at all.
Dangerous commands are always rejected even if listed.

### ignored_paths

Directory basenames to skip during `list_files` and `search_text`. Added on top of
the built-in ignore list (`.git`, `node_modules`, `vendor`, `tmp`, `log`, `.bundle`).

## Model configuration

Ragent uses an OpenAI-compatible chat completions API. Set the following environment
variables before running:

| Variable | Default | Description |
|---|---|---|
| `OPENAI_API_KEY` | — | Required to use the real model. Falls back to a fake client when unset. |
| `OPENAI_BASE_URL` | `https://api.openai.com` | Override for local models or compatible APIs (Ollama, LM Studio, etc.). |
| `RAGENT_MODEL` | `gpt-4o` | Model name passed in every request. |

### Using a real model

```bash
export OPENAI_API_KEY=sk-...
bin/ragent --repo /path/to/repo "summarize this repo"
```

The harness prints each tool call to stderr as the agent works, then writes the
final answer to stdout. Example session:

```
[list_files]
[read_file] path: README.md
[read_file] path: lib/ragent.rb
[search_text] query: def run

=== Answer ===

This is a plain-Ruby CLI that sends a prompt to an OpenAI-compatible model and
lets it explore a target repository through a set of tools: list_files,
read_file, search_text, propose_patch, and propose_command.
```

Because tool-call progress goes to stderr and the final answer goes to stdout,
you can capture just the answer:

```bash
bin/ragent --repo /path/to/repo "summarize this repo" > answer.txt
```

### Using a local model (e.g. Ollama)

```bash
export OPENAI_BASE_URL=http://localhost:11434
export RAGENT_MODEL=llama3.2
bin/ragent --repo /path/to/repo "what does this project do?"
```

### Development / offline mode

If `OPENAI_API_KEY` is not set, a `FakeModelClient` is used. It calls `list_files`
once and returns a placeholder final answer, useful for testing the harness without
a live API key.

## Rollback

When ragent applies a patch it saves a checkpoint under `.ragent/runs/<timestamp>/`.
To undo the last applied patch:

```bash
bin/ragent rollback .ragent/runs/<timestamp>
```

Ragent reads the checkpoint, shows the patch that was applied, and asks for
confirmation before reversing it with `git apply --reverse`.

If automatic reversal fails (e.g. the file has since changed), ragent prints
manual recovery instructions including the branch and repo state at the time the
patch was applied.

## Running Tests

```bash
bundle exec rake test
```

To run a single test file:

```bash
bundle exec ruby -Itest test/ragent/tools/test_list_files.rb
```

## Docker

### Build the image

```bash
docker compose build
```

### Run a prompt

```bash
docker compose run --rm ragent "hello"
```

Docker mode is **containment, not hard sandboxing**. The default Compose setup is
designed for practical development: it can build native gems, write generated
files and caches, run test tooling, and reach the model API. Its safety boundary
is mostly approval UX, Docker isolation, resource limits, and not mounting
secrets into the container.

### Docker modes

| Mode | Command shape | Workspace | Commands | Network |
|---|---|---|---|---|
| *(default)* | `docker compose run --rm ragent "..."` | Read-write | Not enabled | Default |
| `inspect` | `docker compose -f docker-compose.yml -f docker-compose.ro.yml run --rm ragent "..."` | Read-only | Not enabled | Default |
| `develop` | `docker compose run --rm ragent --allow-commands "..."` | Read-write | Prompt for approval | Default |
| `danger` | `docker compose run --rm ragent --yes --allow-commands "..."` | Read-write | Auto-approved, except built-in dangerous-command rejection | Default |
| `offline` | `docker compose -f docker-compose.yml -f docker-compose.nonet.yml run --rm ragent "..."` | Read-write unless combined with `docker-compose.ro.yml` | Not enabled unless `--allow-commands` is passed | Disabled |

`/workspace` is mounted **read-write** by default so the agent can apply patches
and write run artifacts to `<workspace>/.ragent/runs/`.

### Point at a target repository

Set `WORKSPACE_PATH` to the absolute path of the repo you want ragent to work on:

```bash
WORKSPACE_PATH=/path/to/your/repo docker compose run --rm ragent "summarize this repo"
```

The repo is mounted at `/workspace` inside the container, which is the default
workspace root the CLI uses. Set it permanently in a `.env` file:

```
WORKSPACE_PATH=/path/to/your/repo
```

### Inspect mode: read-only workspace

To prevent the agent from writing to the workspace at all, use the read-only override:

```bash
docker compose -f docker-compose.yml -f docker-compose.ro.yml run --rm ragent \
  "explain what this project does"
```

In this mode the agent can explore and propose patches but cannot apply them.
Run artifacts (transcript, patches) are disabled — the workspace is read-only, so
ragent falls back to a null transcript and prints a warning. Use `--artifact-dir`
with a writable path to preserve artifacts in read-only mode:

```bash
docker compose -f docker-compose.yml -f docker-compose.ro.yml run --rm \
  -v /tmp/ragent-runs:/runs ragent \
  --artifact-dir /runs --allow-external-artifacts \
  "explain what this project does"
```

### Offline mode: network off

For maximum isolation, disable all container networking:

```bash
docker compose -f docker-compose.yml -f docker-compose.nonet.yml run --rm ragent "list files"
```

The container gets no network interfaces at all — not even loopback — so it cannot
reach the OpenAI API or any other external service.

**Model clients compatible with offline mode:**

| Client | How to use |
|---|---|
| `FakeModelClient` | Unset `OPENAI_API_KEY` (or remove it from the environment). Calls `list_files` once and returns a placeholder answer. Useful for testing the harness itself. |
| Local model on host | **Not reachable** with `network_mode: none`. Use `--network host` (Linux only) or a shared Docker network instead. |
| OpenAI API | **Not reachable**. Will fail with a connection error at startup. |

To run a real offline workflow, combine network-off mode with the fake client:

```bash
# No API key → FakeModelClient → no network needed
unset OPENAI_API_KEY
docker compose -f docker-compose.yml -f docker-compose.nonet.yml run --rm ragent "list files"
```

### Security hardening

The default `docker-compose.yml` applies several containment restrictions. These
settings are useful guardrails, but they are not a hard sandbox:

| Control | Setting |
|---|---|
| User | root (inside container) |
| `/workspace` | Read-write bind mount |
| `/app` | Read-only bind mount |
| Memory | 512 MB limit |
| PIDs | 64 process limit |
| Privileged mode | Disabled |
| Writable surface | `/workspace` (bind mount) and `/tmp` (tmpfs) |

#### Security limitations

- **The agent runs shell commands** when `--allow-commands` is passed. With write
  access to `/workspace`, a compromised prompt can modify the target repo.
- **The container runs as root**, so a compromised prompt has full access to the
  container filesystem. The security boundary is the container itself, not the user.
- **`/workspace` is writable by default** — a compromised prompt can modify the
  target repo even without `--allow-commands`. Use `docker-compose.ro.yml` to restrict
  the agent to read-only exploration, or review prompts carefully before running.
- **Network is unrestricted by default** — the agent has full outbound access
  (needed for the OpenAI API). Use `docker-compose.nonet.yml` to disable it
  entirely, at the cost of only being able to use the fake or a pre-bundled model.
- **Memory and PID limits** are a DoS floor, not a security boundary. They do not
  prevent a sufficiently patient process from exhausting other resources.
