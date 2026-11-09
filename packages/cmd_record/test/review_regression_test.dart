@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart';
import 'package:process_run/process_run.dart';
import 'package:test/test.dart';

void main() {
  test(
    '-w forwards the lines read and ends at the end of stdin',
    () async {
      var packageConfig = (await Isolate.packageConfig)!.toFilePath();
      var script = absolute(join('bin', 'cmd_record.dart'));
      var dir = await Directory.systemTemp.createTemp('cmd_record_test');
      Process? process;
      try {
        var stdinController = StreamController<List<int>>();
        var future = runExecutableArguments(
          Platform.resolvedExecutable,
          ['--packages=$packageConfig', script, '-w', '-j', 'cat'],
          workingDirectory: dir.path,
          stdin: stdinController.stream,
          onProcess: (started) => process = started,
        );
        stdinController.add(utf8.encode('hello\n'));
        await stdinController.close();
        // Before the fix: cat never got the line nor the end of its input.
        var result = await future.timeout(const Duration(seconds: 30));
        expect(result.exitCode, 0);
        var history =
            jsonDecode(
                  await File(join(dir.path, 'cmd_record.json')).readAsString(),
                )
                as Map;
        expect((history['in'] as List).map((item) => (item as List).last), [
          'hello',
        ]);
        expect((history['out'] as List).map((item) => (item as List).last), [
          'hello',
        ]);
      } finally {
        process?.kill();
        await dir.delete(recursive: true);
      }
    },
    testOn: '!windows',
    timeout: const Timeout(Duration(seconds: 60)),
  );
}
