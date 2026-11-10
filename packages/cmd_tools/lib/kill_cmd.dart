/// Command process management and termination utilities.
library;

import 'dart:async';
import 'dart:io' show pid;

import 'package:process_run/cmd_run.dart';
import 'package:process_run/utils/shell_context.dart';
import 'package:tekartik_cmd_tools/src/process_win.dart';
import 'package:tekartik_cmd_tools/src/ps.dart';

/// Kills all processes whose name matches [name].
Future killCommand(String name) async {
  return await killAllCommandsByName(name);
}

// dart.exe,
/// Kills all processes matching [name] and returns the count killed.
///
/// Throws an [ArgumentError] when [name] is empty or blank: it would match
/// every process.
Future<int> killAllCommandsByName(String name) async {
  if (name.trim().isEmpty) {
    throw ArgumentError.value(name, 'name', 'An empty name matches everything');
  }
  // The platform of the shell running the commands: the local one, unless
  // a remote shell context is set.
  if (shellContext.platform.isWindows) {
    var pids = await getProcessIds(name);
    for (var pid in pids) {
      await killProcess(pid);
    }
    return pids.length;
  } else {
    final cmd = ProcessCmd('ps', ['x', '-o', 'pid,ppid,cmd']);

    final processResult = await runCmd(cmd, commandVerbose: true);
    final psParser = PsParser(processResult.stdout.toString());
    // The name might be in our own command line (or its parents)
    final selfPids = _selfAndParentPids(psParser);
    final lines = psParser
        .findByCmd(name)
        .where((line) => !selfPids.contains(line.pid))
        .toList();
    for (final line in lines) {
      // ignore: avoid_print
      print(line);
      final cmd = ProcessCmd('kill', ['-9', '${line.pid}']);
      await runCmd(cmd, verbose: true);
    }

    return lines.length;
  }
}

/// The pids of this process and its parents in [psParser], none where there
/// is no local process (the web, the commands running in a remote shell).
Set<int> _selfAndParentPids(PsParser psParser) {
  try {
    return psParser.selfAndParentPids(pid);
  } on UnsupportedError catch (_) {
    return <int>{};
  }
}
