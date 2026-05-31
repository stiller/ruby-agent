# ragent

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
# => Received prompt: hello
```

## Running Tests

```bash
bundle exec ruby -Itest test/test_ragent.rb
```
