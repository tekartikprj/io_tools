@TestOn('vm')
// Copyright (c) 2015, <your name>. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

library apk_utils_test;

import 'package:tekartik_cmd_tools/src/ps.dart';
import 'package:test/test.dart';

void main() {
  group('ps', () {
    test('ps_parser', () {
      final out = '''
  PID CMD
  533 /opt/google/chrome/chrome --type=renderer --field-trial-handle=17660443550131646686,17099240203673097896,131072 --service-pipe-token=E8D0B5C944EDF94261882ECC919EF782 --lang=en-US --enable-offline-auto-reload --enable-offline-auto-reload-visible-only --blink-settings=disallowFetchForDocWrittenScriptsInMainFrame=false,disallowFetchForDocWrittenScript
  561 /opt/google/chrome/chrome --type=renderer --field-trial-handle=17660443550131646686,17099240203673097896,131072 --service-pipe-token=34F14D3B12A6FB140D1ABCE5DF2A12EA --lang=en-US --enable-offline-auto-reload --enable-offline-auto-reload-visible-only --blink-settings=disallowFetchForDocWrittenScriptsInMainFrame=false,disallowFetchForDocWrittenScript
  958 /usr/lib/thunderbird/thunderbird
 9092 /media/ssd/apps/android-sdk-linux/emulator/qemu/linux-x86_64/qemu-system-i386 -netdelay none -netspeed full -avd 10.1_WXGA_Tablet_GAPI_26
 9094 /media/ssd/apps/android-sdk-linux/emulator/emulator64-crash-service -pipe 4 -ppid 9092 -data-dir /tmp/android-alex/56f6a900-3b12-4da0-8557-41edb14b5aa8
''';
      final parser = PsParser(out);
      expect(parser.header!.findPartIndex('PID'), 0);
      expect(parser.header!.findPartIndex('CMD'), 1);
      expect(parser.findFirstByCmd('thunder')!.pid, 958);
      expect(parser.findByCmd('chrome').length, 2);
    });
  });
}
