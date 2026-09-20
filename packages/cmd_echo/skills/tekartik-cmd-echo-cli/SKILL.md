---
name: tekartik-cmd-echo-cli
description: >-
  Use when a test or a script needs a process with predictable stdout, stderr,
  binary output, stdin echo and exit code: the tekartik_cmd_echo command
  (bin/echo.dart, dart run tekartik_cmd_echo:echo) and its options --stdout/-o,
  --stdout-hex/-p, --stderr/-e, --stderr-hex/-f, --stdin/-i, --exit-code/-x,
  --version, --help, plus the library entry points main(arguments), version and
  currentScriptName from package:tekartik_cmd_echo/cmd_echo.dart.
---

# tekartik_cmd_echo: a scriptable echo process

`tekartik_cmd_echo` is a tiny `dart:io` command whose only job is to produce
exactly the output a test asks for: a string on stdout, raw bytes on stderr, a
given exit code, a crash, or the first line read from stdin. It is a test
fixture and a debugging aid for process spawning code, not an application
library.

## Guidelines

* Dependency (git, private project repo, not on pub.dev); it is a test fixture,
  so it belongs in `dev_dependencies`:
  ```yaml
  dev_dependencies:
    tekartik_cmd_echo:
      git:
        url: https://github.com/tekartikprj/io_tools
        path: packages/cmd_echo
  ```
* The package has a single public library,
  `package:tekartik_cmd_echo/cmd_echo.dart`, with only three members:
  `Future main(List<String> arguments)` (the whole command),
  `Version version` (a `pub_semver` `Version`, the version the `--version`
  option prints, which is *not* the pubspec version) and
  `String get currentScriptName` (`Platform.script` basename without
  extension). There is no reusable `runEcho()`/result object: call the command
  as a process, or call `main(args)` and let it write to `stdout`/`stderr`.
* Run it as a process, never as an import, when you need real stream and exit
  code behaviour:
  * from a consumer package: `dart run tekartik_cmd_echo:echo <options>`;
  * from a checkout of this package: `dart run bin/echo.dart <options>`;
  * compiled once for speed: `dart compile exe bin/echo.dart -o .local/echo`.
  `pubspec.yaml` declares no `executables:` section, so
  `dart pub global activate` does not install an `echo` command; spawn
  `dartExecutable` (from `package:process_run/process_run.dart`) with
  `['run', 'tekartik_cmd_echo:echo', ...]` instead.
* Options (all optional, all combinable), applied in this order:
  1. `--stdin` / `-i`: read one line with `stdin.readLineSync()` and write it
     back to stdout (nothing if stdin is closed/empty);
  2. `--stdout <text>` / `-o`: `stdout.write(text)`, **no trailing newline**;
  3. `--stdout-hex <hex>` / `-p`: write the raw bytes of a hex string
     (`010203` -> `[1, 2, 3]`); read the result with `stdoutEncoding: null`;
  4. `--stderr <text>` / `-e` and `--stderr-hex <hex>` / `-f`: the same two on
     stderr;
  5. every remaining positional argument, one `stdout.writeln()` each;
  6. `--exit-code <n>` / `-x`: `exit(n)`.
  `--help` / `-h` prints the usage and returns, `--version` prints
  `<script> version <version>` followed by the resolved VM path and version,
  `--verbose` / `-v` is accepted and currently does nothing.
* Exit codes: `0` by default; the value of `--exit-code` when it parses as an
  int; **`255` when it does not** (`int.parse` throws, the VM prints the stack
  trace on stderr). That non numeric value is the supported way to test a
  crashing process.
* Parsing is `ArgParser(allowTrailingOptions: false)`: options must come before
  the positional arguments, and an unknown option throws a `FormatException`
  (uncaught, so exit code 255 too).
* Use the `--option=value` form when the value itself starts with `-`
  (`--stdout=-x`), and put every option before the positional arguments.
* Testing style used by this package: spawn the script with both
  `Process.run` and `process_run`'s `runExecutableArguments`, then assert on
  `result.stdout`, `result.stderr` and `result.exitCode`; pass
  `stdoutEncoding: null` / `stderrEncoding: null` for the `*-hex` options. Such
  tests are VM only: start the file with `@TestOn('vm')`.
* Related fixture: `process_run_test` exposes a similar but richer echo program
  (`compileEcho()`, `--wait`, `--all-env`, `--write-line`) as a compiled
  executable. Prefer it when testing `process_run` itself or when the extra
  options are needed; `tekartik_cmd_echo` stays useful as a plain `dart run`
  target with no compilation step.

## Examples

### Command line usage

```bash
# In a package that depends on tekartik_cmd_echo
dart run tekartik_cmd_echo:echo --stdout 'Hello world'   # writes: Hello world (no newline)
dart run tekartik_cmd_echo:echo -o out -e err -x 123     # stdout out, stderr err, exit code 123
dart run tekartik_cmd_echo:echo --stdout-hex 010203      # 3 raw bytes on stdout
echo 'line' | dart run tekartik_cmd_echo:echo --stdin    # writes: line
dart run tekartik_cmd_echo:echo --exit-code crash        # stack trace on stderr, exit code 255
dart run tekartik_cmd_echo:echo one two                  # two lines: one, two
dart run tekartik_cmd_echo:echo --help

# From a checkout of the package itself
dart run bin/echo.dart --version
dart test
```

### Spawn it from a test and assert on the streams

```dart
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:process_run/process_run.dart';
import 'package:test/test.dart';

/// `dart run tekartik_cmd_echo:echo <args>`, run from the current package.
Future<ProcessResult> runEcho(
  List<String> args, {
  Encoding? stdoutEncoding = systemEncoding,
}) => runExecutableArguments(dartExecutable!, [
  'run',
  'tekartik_cmd_echo:echo',
  ...args,
], stdoutEncoding: stdoutEncoding);

void main() {
  test('stdout, stderr and exit code', () async {
    var result = await runEcho(['-o', 'out', '-e', 'err', '-x', '123']);
    expect(result.stdout, 'out');
    expect(result.stderr, 'err');
    expect(result.exitCode, 123);
  });

  test('binary output', () async {
    var result = await runEcho(['--stdout-hex', '010203'], stdoutEncoding: null);
    expect(result.stdout, [1, 2, 3]);
  });

  test('crash', () async {
    var result = await runEcho(['--exit-code', 'crash']);
    expect(result.exitCode, 255);
    expect(result.stderr, isNotEmpty);
  });
}
```

### Feed it on stdin

```dart
@TestOn('vm')
library;

import 'dart:async';

import 'package:process_run/shell.dart';
import 'package:test/test.dart';

void main() {
  test('stdin is echoed back', () async {
    var stdinController = StreamController<List<int>>();
    var shell = Shell(
      options: ShellOptions(
        stdin: stdinController.stream,
        commandVerbose: false,
        verbose: false,
      ),
    );
    var resultFuture = shell.runExecutableArguments(dartExecutable!, [
      'run',
      'tekartik_cmd_echo:echo',
      '--stdin',
    ]);
    stdinController.add('in\n'.codeUnits);
    await stdinController.close();
    expect((await resultFuture).stdout, 'in');
  });
}
```

### Reuse the command in your own executable

```dart
// bin/my_echo.dart of your own package (add `#!/usr/bin/env dart` on top if
// you want it directly executable).
import 'package:tekartik_cmd_echo/cmd_echo.dart' as cmd_echo;

/// Same options as the echo command, under your own script name.
Future<void> main(List<String> arguments) async {
  await cmd_echo.main(arguments);
}
```

### Read the command version from Dart

```dart
import 'package:tekartik_cmd_echo/cmd_echo.dart';

void main() {
  // The version reported by `--version` (pub_semver Version), and the basename
  // of the running script without its extension.
  print('$currentScriptName echo version $version');
}
```
