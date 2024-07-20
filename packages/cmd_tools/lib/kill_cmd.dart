import 'dart:async';
import 'dart:io';
import 'package:process_run/cmd_run.dart';
import 'package:tekartik_cmd_tools/src/process_win.dart';
import 'package:tekartik_cmd_tools/src/ps.dart';

Future killCommand(String name) async {
  return await killAllCommandsByName(name);
}

// dart.exe,
Future<int> killAllCommandsByName(String name) async {
  if (Platform.isWindows) {
    var pids = await getProcessIds(name);
    for (var pid in pids) {
      await killProcess(pid);
    }
    return pids.length;
  } else {
    final cmd = ProcessCmd('ps', ['x', '-o', 'pid,cmd']);

    final processResult = await runCmd(cmd, commandVerbose: true);
    final psParser = PsParser(processResult.stdout.toString());
    final lines = psParser.findByCmd(name);
    for (final line in lines) {
      print(line);
      final cmd = ProcessCmd('kill', ['-9', '${line.pid}']);
      await runCmd(cmd, verbose: true);
    }

    return lines.length;
  }
}
