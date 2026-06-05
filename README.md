# Ruby Agent

An agentic coding harness written in plain Ruby.

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

Ragent reads `.ragent.yml` from the repo root if it exists.

### Allowed commands

List command prefixes that may run without an interactive prompt. Useful for trusted
project-specific commands (tests, linters, build steps) so the agent can run them
without interrupting the session:

```yaml
allowed_commands:
  - bundle exec rake test
  - bundle exec rubocop
  - npm test
  - pytest
```

A command matches if it equals a listed prefix exactly or starts with the prefix
followed by a space (so `bundle exec rake test --verbose` matches `bundle exec rake test`).
Dangerous commands are always rejected even if listed.

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
bundle exec rake
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

This mounts the current project into `/app` inside the container.

### Point at a target repository

Set `WORKSPACE_PATH` to the absolute path of the repo you want ragent to work on:

```bash
WORKSPACE_PATH=/path/to/your/repo docker compose run --rm ragent "hello"
```

The repo will be mounted at `/workspace` inside the container, which is the default workspace root the CLI uses.

You can also set it permanently in a `.env` file:

```
WORKSPACE_PATH=/path/to/your/repo
```
