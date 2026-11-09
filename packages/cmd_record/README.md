# tekartik_cmd_record

Runs a command and records what it writes on stdout and stderr (and what it
reads on stdin), one timestamped line each, into `cmd_record.log` or
`cmd_record.json`. A command line tool and a Dart function (`record`).
Dart VM only (Linux, macOS, Windows).

## Getting started

Git package, not on pub.dev:

```yaml
dev_dependencies:
  tekartik_cmd_record:
    git:
      url: https://github.com/tekartikprj/io_tools
      path: packages/cmd_record
```

```bash
dart run tekartik_cmd_record:cmd_record sh -c 'echo out; echo err >&2'
cat cmd_record.log
# 00:00.055 > out
# 00:00.057 E err
```

The options of `cmd_record` go before the command:

```
-h, --help              Usage help
-v, --verbose           Verbose: prints every recorded line at the end
-n, --no-stderr         No stderr
-s, --run-in-shell      RunInShell
-j, --json              Save as json (cmd_record.json)
-i, --[no-]stdin        Forward and record stdin
-w, --[no-]own-stdin    Forward and record stdin, line by line
-x, --exit-code         Ignored
    --version           Print the command version
```

From Dart:

```dart
// ignore: implementation_imports
import 'package:tekartik_cmd_record/src/cmd_record.dart';

Future<void> main() async {
  var history = History();
  await record('git', ['status'], history: history, noStdOutput: true);
  print(history.result.exitCode);
  print(historyDumpLines(history).join('\n')); // 00:00.012 > On branch...
}
```

Global activation:
`dart pub global activate -sgit https://github.com/tekartikprj/io_tools --git-path packages/cmd_record`.

## Common pitfalls

* `cmd_record` exits `0` whatever the command returned: the command's exit
  code is in `cmd_record.json` (`exitCode`) or `History.result`.
* `cmd_record.log` and `cmd_record.json` are written in the current
  directory and overwritten on each run.
* With `-i` or `-w` on a terminal, the command sees the end of its input
  only at CTRL-D (CTRL-C to stop).
* A command that exits without reading its whole input can make
  `cmd_record -i` fail with a broken pipe `SocketException`.
* The API has no public library: import `src/cmd_record.dart` as above.

More: the [tekartik-cmd-record-cli skill](skills/tekartik-cmd-record-cli/SKILL.md).
