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

Each run writes a JSONL transcript to `/tmp/ragent-runs/<timestamp>/transcript.jsonl`
and prints the path at the end.

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
bin/ragent --repo /path/to/repo "list all Ruby files"
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
