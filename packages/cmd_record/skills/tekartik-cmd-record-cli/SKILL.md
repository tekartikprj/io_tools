---
name: tekartik-cmd-record-cli
description: >-
  Use when recording what a command line process writes to stdout and stderr
  and reads from stdin, with a timestamp per line, from the shell or from Dart
  with tekartik_cmd_record: the cmd_record command (dart run
  tekartik_cmd_record:cmd_record, cmd_record.log, --json/-j and cmd_record.json,
  --verbose/-v, --stdin/-i, --own-stdin/-w, --no-stderr/-n, --run-in-shell/-s,
  --version) and the record() function, History, HistoryItem, HistorySink,
  dump(), inPrefix/outPrefix/errPrefix from
  package:tekartik_cmd_record/src/cmd_record.dart and durationToString from
  src/utils.dart. Not a process runner or a shell: that is process_run.
---

# tekartik_cmd_record: timestamped recording of a process

`cmd_record` runs a command through `process_run`'s `runCmd`, copies its
stdout and stderr to the terminal as they come, and records every line of
stdout, stderr and stdin with the time elapsed since the start (`mm:ss.mmm`),
into `cmd_record.log` or, as a `History`, into `cmd_record.json`. The same
`record()` function is callable from Dart.

```bash
# In a package that depends on tekartik_cmd_record
dart run tekartik_cmd_record:cmd_record sh -c 'echo out; echo err >&2'
cat cmd_record.log
# 00:00.055 > out
# 00:00.057 E err
```

## Guidelines

* Dependency (git, not on pub.dev):

  ```yaml
  dependencies:
    tekartik_cmd_record:
      git:
        url: https://github.com/tekartikprj/io_tools
        path: packages/cmd_record
  ```

  It brings `process_run`, `args`, `path`, `pub_semver` and
  `tekartik_cmd_echo` (a predictable echo process, handy in tests).
* Two libraries:
  * `package:tekartik_cmd_record/bin/cmd_record.dart`: the command,
    `Future main(List<String> arguments)`, to wrap in your own `bin/`.
  * `package:tekartik_cmd_record/src/cmd_record.dart`: the API (`record`,
    `History`, `HistoryItem`, `HistorySink`, `dump`, `inPrefix`, `outPrefix`,
    `errPrefix`, `version`, `currentScriptName`) and
    `package:tekartik_cmd_record/src/utils.dart` (`durationToString`). There
    is no public export of the API: import `src/` with
    `// ignore: implementation_imports`.

### Command line

* `cmd_record [options] <command> [arguments...]`. Parsing stops at the first
  positional (`allowTrailingOptions: false`): the options of `cmd_record` go
  before the command, the command's own options pass through untouched
  (`cmd_record echo -n hi`). Run it as `dart run bin/cmd_record.dart` from a
  checkout, `dart run tekartik_cmd_record:cmd_record` from a consumer
  (`executables:` declares `cmd_record`), or once globally with
  `dart pub global activate -sgit https://github.com/tekartikprj/io_tools --git-path packages/cmd_record`.
* Default output: `cmd_record.log` in the current directory, overwritten on
  each run, one line per recorded line, `mm:ss.mmm > line` for stdout,
  `mm:ss.mmm E line` for stderr, `mm:ss.mmm $ line` for stdin, time since the
  process start. Stdout and stderr are also copied live to the terminal.
* `-j`/`--json`, or `-v`/`--verbose`: no log, `cmd_record.json` instead:
  `{date, duration, executable, arguments, in, out, err, exitCode}` where
  `in`/`out`/`err` are `[[microseconds, line], ...]` and absent when empty.
  `-v` additionally prints a header (date, duration, command line) followed
  by the stdin lines only: the `dump` function does not print stdout and
  stderr items.
* Exit code: `cmd_record` exits `0` whatever the command returned; the
  command's exit code is only in the json `exitCode`. `-x`/`--exit-code` is
  accepted and ignored. Without a command: `Need a command` and exit `1`.
* `-i`/`--stdin`: the stdin of `cmd_record` is forwarded to the command and
  recorded as `$` lines. A pipe ends it at EOF (`printf 'a\n' | cmd_record -i
  cat`); on a terminal the command only sees EOF at CTRL-C.
* `-w`/`--own-stdin`: stdin is read line by line and each line is forwarded
  with a newline, but the forwarded stream is only closed after the command
  exits: a command that waits for EOF (`cat`) never ends. Use `-i` for those,
  `-w` only for commands that stop by themselves.
* `-n`/`--no-stderr`: stderr is neither shown nor recorded.
* `-s`/`--run-in-shell`: `Process.start(runInShell: true)`, needed for
  `.bat`/`.cmd` files on Windows and shell built-ins. Arguments stay quoted:
  `$HOME` is not expanded, and a single string with spaces is looked up as one
  command. For shell syntax run `sh -c '...'` (or `cmd /c`) as the command.
* `--version` prints `cmd_record version 0.1.0` on stderr: the hardcoded
  `version` constant, not the pubspec version. The `--help` usage starts with
  `Echo utility` (inherited from cmd_echo); the option list is right.

### API

* `record(executable, arguments, {runInShell, recordStdin, noStdOutput,
  dumpSink, history, inStream, noStderr})` runs `ProcessCmd(executable,
  arguments)` with `runCmd` from `package:process_run/cmd_run.dart` and
  completes when the process has exited. It returns nothing: pass a
  `History` to get `result` (`ProcessResult`, so `exitCode`), `date`,
  `duration` and the `inItems`, `outItems`, `errItems` lists, and/or a
  `dumpSink` (any `StringSink`: `StringBuffer`, `stdout`, a file `IOSink`)
  that receives the `mm:ss.mmm > line` lines as they arrive. `History.result`
  is `late`: read it (and call `toJson()`) only after `record` completed.
* `noStdOutput: true` stops the live copy to the current process's stdout
  and stderr: always set it in tests. `noStderr: true` drops stderr, it is
  not recorded either.
* stdin: `inStream` (`Stream<List<int>>`) is forwarded to the process and
  recorded; `recordStdin` defaults to `inStream != null`. `recordStdin: true`
  without `inStream` forwards the real `stdin` of the current process: never
  in a test. Close the stream so the process sees EOF, otherwise `record`
  waits for a command that waits for input.
* Lines: split by `LineSplitter` (`\n` and `\r\n`, newline removed); a final
  line without newline is recorded when the stream closes. `HistoryItem.time`
  is in microseconds since the `Stopwatch` started (just before the process),
  `getOutput(prefix)` formats `mm:ss.mmm <prefix> line`, `toJson()` gives
  `[time, line]`. Items of the three streams are kept in three lists: merge
  them by `time` for a timeline.
* `HistorySink(ioSink, stopwatch)` is the recorder itself, a
  `StreamSink<List<int>>` usable as the `stdout:`/`stderr:` of any
  `runCmd`: `stream` yields the `HistoryItem`s, `ioSink` (nullable) gets a
  copy of the bytes, `close()` flushes the last line.
* `dump(history)` prints the header and the stdin items only.
  `durationToString(Duration)` is the `mm:ss.mmm` formatter (`01:01.090`,
  minutes wrap at 60).
* Tests that spawn a process are VM only (`@TestOn('vm')`); use
  `dart run tekartik_cmd_echo:echo -o out -e err -x 3` (a dependency of this
  package) as a predictable command, through `DartCmd` from
  `package:process_run/cmd_run.dart`.

## Examples

### Command line

```bash
dart run tekartik_cmd_record:cmd_record make test            # cmd_record.log
dart run tekartik_cmd_record:cmd_record -j make test         # cmd_record.json, with exitCode
printf 'a\nb\n' | dart run tekartik_cmd_record:cmd_record -i cat   # $ a, $ b, > a, > b
dart run tekartik_cmd_record:cmd_record -n flutter build web # stderr dropped
dart run tekartik_cmd_record:cmd_record sh -c 'echo $HOME'   # shell syntax: through sh -c
dart run tekartik_cmd_record:cmd_record --version            # cmd_record version 0.1.0 (stderr)
```

### Record a build to a timed log file and return its exit code

```dart
import 'dart:io';

// ignore: implementation_imports
import 'package:tekartik_cmd_record/src/cmd_record.dart';

/// Streams the output live, writes `mm:ss.mmm > line` lines to [logPath]
/// and returns the command's exit code.
Future<int> recordToFile(
  String executable,
  List<String> arguments, {
  String logPath = 'build.log',
}) async {
  var history = History();
  var sink = File(logPath).openWrite();
  try {
    await record(
      executable,
      arguments,
      history: history,
      dumpSink: sink,
    );
  } finally {
    await sink.close();
  }
  // Available only once record completed.
  return history.result.exitCode;
}
```

### Feed stdin from Dart and get a timeline

```dart
import 'dart:async';
import 'dart:convert';

// ignore: implementation_imports
import 'package:tekartik_cmd_record/src/cmd_record.dart';

/// Runs `cat`, sends [lines], returns every recorded line in time order.
Future<List<String>> timeline(List<String> lines) async {
  var history = History();
  var inController = StreamController<List<int>>();
  var done = record(
    'cat',
    [],
    noStdOutput: true,
    inStream: inController.stream, // recordStdin defaults to true here
    history: history,
  );
  for (var line in lines) {
    inController.add(utf8.encode('$line\n'));
  }
  await inController.close(); // EOF, cat exits
  await done;

  var items = [
    for (var item in history.inItems) (item, inPrefix),
    for (var item in history.outItems) (item, outPrefix),
    for (var item in history.errItems) (item, errPrefix),
  ]..sort((a, b) => a.$1.time!.compareTo(b.$1.time!));
  return [for (var (item, prefix) in items) item.getOutput(prefix)];
}
```

### Test with the cmd_echo fixture

```dart
@TestOn('vm')
library;

import 'dart:convert';

import 'package:process_run/cmd_run.dart';
// ignore: implementation_imports
import 'package:tekartik_cmd_record/src/cmd_record.dart';
// ignore: implementation_imports
import 'package:tekartik_cmd_record/src/utils.dart';
import 'package:test/test.dart';

void main() {
  test('stdout, stderr, exit code', () async {
    var history = History();
    // dart run tekartik_cmd_echo:echo -o out -e err -x 3
    var cmd = DartCmd(['run', 'tekartik_cmd_echo:echo', '-o', 'out', '-e', 'err', '-x', '3']);
    var log = StringBuffer();
    await record(
      cmd.executable,
      cmd.arguments,
      noStdOutput: true,
      history: history,
      dumpSink: log,
    );
    // '-o out' has no trailing newline: still recorded on close.
    expect(history.outItems.map((item) => item.line), ['out']);
    expect(history.errItems.map((item) => item.line), ['err']);
    expect(history.result.exitCode, 3);
    expect(log.toString(), contains(' > out'));
    expect(log.toString(), contains(' E err'));

    var json = jsonDecode(jsonEncode(history)) as Map;
    expect(json['exitCode'], 3);
    expect(((json['out'] as List).first as List)[1], 'out');
  });

  test('duration format', () {
    expect(durationToString(const Duration(milliseconds: 61090)), '01:01.090');
    expect(HistoryItem()
      ..time = 900000
      ..line = 'x', isNotNull);
  });
}
```

## Common mistakes

* `cmd_record` exits `0` after a failing command: the exit code is only in
  `cmd_record.json` (`-j`), or in `history.result.exitCode` from Dart.
* `-w cat` (or any command waiting for EOF) hangs: use `-i`.
* `-s 'echo $HOME'` gives `not found` and `-s echo '$HOME'` prints `$HOME`:
  `-s` does not give shell syntax, run `sh -c '...'`.
* `-v` shows no stdout lines: `dump` prints the stdin items only; read
  `cmd_record.json`.
* `LateInitializationError: Field 'result'`: `history.result` read before
  `record` completed.
* The test hangs: `recordStdin: true` without `inStream` reads the test
  runner's stdin, or the `inStream` controller was never closed.
* Output of the recorded command appears in the test output: `noStdOutput`
  left unset.

## More

* Package README for the option list and the `--stdout`/`--stderr` quick
  tests with `example/echo.dart`.
