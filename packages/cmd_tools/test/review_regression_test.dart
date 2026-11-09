@TestOn('vm')
library;

import 'package:tekartik_cmd_tools/kill_cmd.dart';
import 'package:tekartik_cmd_tools/src/ps.dart';
import 'package:test/test.dart';

void main() {
  test('an empty name matches every process', () {
    var parser = PsParser('''
    PID    PPID CMD
      1       0 /sbin/init
    100       1 bash
    200     100 code --wait
''');
    // Why killAllCommandsByName refuses it.
    expect(parser.findByCmd('').length, 3);
    // A blank name matches every command line with an argument.
    expect(parser.findByCmd(' ').length, 1);
  });

  test('an empty or blank name kills nothing', () async {
    for (var name in ['', ' ', '\t']) {
      await expectLater(
        killAllCommandsByName(name),
        throwsArgumentError,
        reason: "'$name'",
      );
    }
  }, timeout: const Timeout(Duration(seconds: 30)));
}
