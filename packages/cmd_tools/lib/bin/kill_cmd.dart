#!/usr/bin/env dart
// Copyright (c) 2015, <your name>. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:tekartik_cmd_tools/kill_cmd.dart';

/// Flag name for the help option.
const String flagHelp = 'help';

/// Script name for usage messages.
const String scriptName = 'kill_cmd';

Future main(List<String> args) async {
  var parser = ArgParser();

  parser.addFlag(flagHelp, abbr: 'h', help: 'Usage help', negatable: false);

  var results = parser.parse(args);

  parser.parse(args);

  final help = results[flagHelp] as bool;

  void printUsage() {
    stdout.writeln(
      '$scriptName <part_of_process_name> [<other_part_of_process_name> ...]',
    );
    stdout.writeln(parser.usage);
  }

  if (help) {
    printUsage();
    return;
  }

  if (results.rest.isEmpty) {
    printUsage();
    exit(1);
  }

  for (final name in results.rest) {
    var count = await killAllCommandsByName(name);
    if (count == 0) {
      stderr.writeln('*$name* process not found');
    } else {
      stdout.writeln('$count process killed');
    }
  }
}
