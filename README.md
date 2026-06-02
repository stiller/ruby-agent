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

Run artifacts (transcript, patches, checkpoint) are written to
`<repo>/.ragent/runs/<timestamp>/` and kept after the session for inspection and rollback.
Pass `--clean-runs` to delete them automatically when the session ends.

The workspace defaults to the `RAGENT_WORKSPACE` environment variable (default: `/workspace`).

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
lets it explore a target repository through three read-only tools: list_files,
read_file, and search_text.
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
