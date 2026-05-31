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
bin/ragent "hello"
# Workspace: /workspace
# Received prompt: hello
```

The workspace defaults to the `RAGENT_WORKSPACE` environment variable (default: `/workspace`).

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
