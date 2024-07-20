@TestOn('vm')
// Copyright (c) 2015, <your name>. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

library tekartik_cmd_tools.test.pid_test;

import 'dart:io';

import 'package:tekartik_cmd_tools/src/process_win.dart';
import 'package:test/test.dart';

void main() {
  group('pid', () {
    test('win_pid', () async {
      var list = await getProcessIds('dart.exe');
      expect(list, isNotEmpty);
      list = await getProcessIds('__dummy_process_that_should_not_exists__');
      expect(list, isEmpty);
    }, skip: !Platform.isWindows);
  });
}
