# tekartik_cmd_echo

A small echo command for tests of process spawning code: it writes exactly what
you ask on stdout and stderr (text or raw bytes), echoes the first line of its
stdin and exits with a given code. Dart VM (Linux, macOS, Windows).

## Getting started

The package is not on pub.dev, add it as a git dev dependency:

```yaml
dev_dependencies:
  tekartik_cmd_echo:
    git:
      url: https://github.com/tekartikprj/io_tools
      path: packages/cmd_echo
```

Then run it from your package:

```bash
dart run tekartik_cmd_echo:echo -o 'Hello world' -e err -x 3  # stdout "Hello world", stderr "err", exit code 3
echo line | dart run tekartik_cmd_echo:echo --stdin            # stdout "line"
dart run tekartik_cmd_echo:echo --stdout-hex 414243 one two    # stdout "ABC" then the lines "one" and "two"
```

From a test, spawn it with process_run (`runExecutableArguments(dartExecutable!,
['run', 'tekartik_cmd_echo:echo', ...])` or a `Shell`) and check
`stdout`, `stderr` and `exitCode`.

## Options

| Option                     | Effect                                                     |
|----------------------------|------------------------------------------------------------|
| `-i`, `--stdin`            | write the first line of stdin to stdout                     |
| `-o`, `--stdout <text>`    | write the text to stdout (no line feed)                     |
| `-p`, `--stdout-hex <hex>` | write the bytes of a hex string to stdout                   |
| `-e`, `--stderr <text>`    | write the text to stderr (no line feed)                     |
| `-f`, `--stderr-hex <hex>` | write the bytes of a hex string to stderr                   |
| `-x`, `--exit-code <n>`    | exit with this code (a non number crashes: exit code 255)   |
| other arguments            | written to stdout, one per line                             |
| `-h`, `--help`, `--version` | usage, version                                             |

Options come before the other arguments; use `--stdout=-text` for a value
starting with `-`. Read the `*-hex` output with `stdoutEncoding: null`.

Agent skill: [skills/tekartik-cmd-echo-cli](skills/tekartik-cmd-echo-cli/SKILL.md).
process_run_test (tekartik/process_run.dart) has a richer compiled echo
(`--wait`, `--all-env`, `-l`).
