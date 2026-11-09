# tekartik_cmd_tools

`kill_cmd`: kill processes by (part of) their command line, from the shell
or from Dart (`killAllCommandsByName`). Typical use: leftover `chrome`,
`qemu` or emulator processes between test runs. Dart VM only.

## Getting started

Git package, not on pub.dev:

```yaml
dev_dependencies:
  tekartik_cmd_tools:
    git:
      url: https://github.com/tekartikprj/io_tools
      path: packages/cmd_tools
```

```bash
dart run tekartik_cmd_tools:kill_cmd qemu-system-x86_64
dart run tekartik_cmd_tools:kill_cmd chrome.exe   # Windows: the exact image name
```

```dart
import 'dart:io';

import 'package:tekartik_cmd_tools/kill_cmd.dart';

Future<void> main() async {
  var name = Platform.isWindows ? 'qemu-system-x86_64.exe' : 'qemu-system-x86_64';
  var count = await killAllCommandsByName(name);
  print('$count process(es) killed');
}
```

## Common pitfalls

* It is `kill -9` (`taskkill /F` on Windows): no clean shutdown.
* Linux matches any part of the whole command line, arguments included:
  `kill_cmd qemu` also kills `less qemu.log`. Pass something specific. The
  current process and its parents are left out. macOS is not checked (its
  `ps` may not know the `cmd` column).
* Windows matches the exact image name (`chrome.exe`) and does not leave the
  current process out (`dart.exe` kills the caller).
* An empty or blank name throws an `ArgumentError` (it would match every
  process).

More: the [tekartik-cmd-tools-kill-cmd skill](skills/tekartik-cmd-tools-kill-cmd/SKILL.md).
