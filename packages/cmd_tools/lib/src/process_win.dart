// windows only
import 'dart:async';

import 'package:csv/csv.dart';
import 'package:process_run/cmd_run.dart';

Future<List<String>> getProcessIds(String command) async {
  // tasklist /FO CSV
  var cmd = ProcessCmd('tasklist', ['/FO', 'CSV']);
  var pids = <String>[];
  var result = await runCmd(cmd);
  var csv = result.stdout.toString();
  final rows = const CsvToListConverter().convert(csv);
  // [Image Name, PID, Session Name, Session#, Mem Usage]
  var columns = rows.first;
  var commandNameIndex = columns.indexOf('Image Name');
  var pidIndex = columns.indexOf('PID');
  for (var i = 1; i < rows.length; i++) {
    var row = rows[i];
    var commandName = row[commandNameIndex].toString();

    if (commandName == command) {
      var pid = row[pidIndex].toString();
      pids.add(pid);
    }
  }
  // print(pids);
  return pids;
}

Future killProcess(String pid) async {
  // taskkill /F /PID pid_number.
  var cmd = ProcessCmd('taskkill', ['/F', '/PID', pid]);
  await runCmd(cmd);
}
