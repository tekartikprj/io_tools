---
name: tekartik-cmd-tools-kill-cmd
description: >-
  Use when killing processes by (part of) their command name from Dart or from
  the shell with tekartik_cmd_tools: killAllCommandsByName(name),
  killCommand(name), the kill_cmd command (dart run tekartik_cmd_tools:kill_cmd
  chrome), and the internal ps output parser (PsParser, PsLine, PsHeader,
  findByCmd, findFirstByCmd, getProcessIds/killProcess on Windows). Covers the
  linux/macos `ps x -o pid,cmd` + `kill -9` path and the Windows tasklist /
  taskkill path.
---

# kill_cmd: kill processes by name (tekartik_cmd_tools)

`tekartik_cmd_tools` is a very small `dart:io` helper around the platform
process tools: it finds the processes whose command matches a name and kills
them. Typical use: get rid of leftover `chrome`, `qemu` or emulator processes
between test or CI runs.

## Guidelines

* Dependency (git, private project repo, not on pub.dev); it is usually a
  tooling/test dependency:
  ```yaml
  dev_dependencies:
    tekartik_cmd_tools:
      git:
        url: https://github.com/tekartikprj/io_tools
        path: packages/cmd_tools
  ```
* One public library, `package:tekartik_cmd_tools/kill_cmd.dart`, with two
  functions:
  * `Future<int> killAllCommandsByName(String name)`: kills every matching
    process and returns how many were killed (0 when none matched);
  * `Future killCommand(String name)`: an alias that just forwards to
    `killAllCommandsByName` and returns its untyped result. Prefer
    `killAllCommandsByName`, whose count you can assert on.
  Everything is `dart:io` based: VM only, no web, no Flutter web.
* Matching rules differ per platform, and this is the main pitfall:
  * linux/macos: runs `ps x -o pid,cmd`, keeps the lines whose **full command
    line contains** `name` (a plain `String.contains`, no glob, no regexp),
    prints them, then runs `kill -9 <pid>` on each. So `dart` also matches
    `/usr/lib/dart/bin/dart --your-analysis-server`: pass something specific
    (`qemu-system-i386`, `chrome --type=renderer`, an absolute path fragment).
  * Windows: runs `tasklist /FO CSV` and keeps the rows whose `Image Name` is
    **exactly equal** to `name`, then `taskkill /F /PID <pid>`. The `.exe`
    suffix is required (`chrome.exe`, `dart.exe`) and a substring does not
    match. Write platform aware code:
    `Platform.isWindows ? 'chrome.exe' : 'chrome'`.
* The calls shell out with `process_run`'s `runCmd(ProcessCmd(...))` with
  verbose on, so the `ps`/`kill` commands and the matched lines are written to
  stdout. There is no quiet mode and no dry-run: to preview what would be
  killed, run `ps x -o pid,cmd` yourself and filter with `PsParser` before
  calling the kill function.
* `kill -9` / `taskkill /F` is an unconditional kill: no signal handler, no
  graceful shutdown, unsaved state is lost. Never call it on a name that can
  match the current process or the test runner itself.
* Command line (the package declares no `executables:`, so use `dart run`, not
  `dart pub global activate`): `dart run tekartik_cmd_tools:kill_cmd <part> [...]`
  from a package that depends on it, or `dart run bin/kill_cmd.dart <part>` from
  a checkout. It accepts several names, prints `<n> process killed` per name or
  `*<name>* process not found` on stderr, and `-h`/`--help` prints the usage.
  With no argument it prints the usage and exits with code 1. The exit code is
  0 even when nothing matched, so check the output (or call the library) when a
  script depends on it.
* `package:tekartik_cmd_tools/src/ps.dart` and `.../src/process_win.dart` are
  internal (`src/`): `PsParser(psStdout)` with `findFirstByCmd(contains)` /
  `findByCmd(contains)` returning `PsLine`s (`pid`, `cmd`), `PsHeader` with
  `findPartIndex(columnName)`, and on Windows `getProcessIds(imageName)` /
  `killProcess(pid)`. They work (the package's own tests use them) but are not
  part of the public API: importing them from another package needs
  `// ignore: implementation_imports` and may break without notice.
  `PsParser` assumes the first line is the header and reads the `PID` and `CMD`
  columns, i.e. exactly the `ps x -o pid,cmd` output; `PsLine.pid` throws a
  `FormatException` on a line whose first column is not an int.
* Tests: `@TestOn('vm')`, and guard anything that really kills a process behind
  a name you own. The Windows-only test in this package is skipped with
  `skip: !Platform.isWindows`. CI for the package itself is
  `dart run tool/run_ci.dart` (`packageRunCi` from `dev_build`).

## Examples

### Command line

```bash
# From a package that depends on tekartik_cmd_tools
dart run tekartik_cmd_tools:kill_cmd chrome
dart run tekartik_cmd_tools:kill_cmd qemu emulator64   # several names at once
dart run tekartik_cmd_tools:kill_cmd --help

# From a checkout of the package
dart run bin/kill_cmd.dart qemu-system-i386
dart run bin/kill_cmd.dart chrome.exe                  # windows: exact image name
dart test
```

### Kill leftover processes from a Dart script

```dart
import 'dart:io';

import 'package:tekartik_cmd_tools/kill_cmd.dart';

Future<void> main() async {
  // Windows matches the exact image name, others a substring of the command.
  var names = Platform.isWindows
      ? ['chrome.exe', 'qemu-system-i386.exe']
      : ['chrome --type=renderer', 'qemu-system-i386'];
  for (var name in names) {
    var count = await killAllCommandsByName(name);
    stdout.writeln(count == 0 ? 'no $name process' : '$count $name killed');
  }
}
```

### Clean up spawned processes after a test run

```dart
@TestOn('vm')
library;

import 'dart:io';

import 'package:tekartik_cmd_tools/kill_cmd.dart';
import 'package:test/test.dart';

void main() {
  // Only ever pass a name that cannot match the test runner itself.
  var serverName = Platform.isWindows
      ? 'my_test_server.exe'
      : 'my_test_server.dart';

  tearDownAll(() async {
    await killAllCommandsByName(serverName);
  });

  test('server is reachable', () async {
    // ... start my_test_server.dart and talk to it ...
  });
}
```

### Preview what would be killed, without killing

```dart
import 'dart:io';

import 'package:process_run/cmd_run.dart';
// Internal library of tekartik_cmd_tools, no stability guarantee.
// ignore: implementation_imports
import 'package:tekartik_cmd_tools/src/ps.dart';

Future<void> main() async {
  if (Platform.isWindows) {
    stdout.writeln('ps parsing is for linux/macos only');
    return;
  }
  var result = await runCmd(ProcessCmd('ps', ['x', '-o', 'pid,cmd']));
  var parser = PsParser(result.stdout.toString());
  for (var line in parser.findByCmd('chrome')) {
    stdout.writeln('would kill ${line.pid}: ${line.cmd}');
  }
  var first = parser.findFirstByCmd('dart');
  stdout.writeln('first dart process: ${first?.pid}');
}
```
