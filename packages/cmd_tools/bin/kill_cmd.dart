#!/usr/bin/env bash

library;

import 'dart:async';

import 'package:tekartik_cmd_tools/bin/kill_cmd.dart' as kill_cmd;

// example
// windows:
// dart .\bin\kill_cmd.dart qemu-system-i386.exe
Future main(List<String> arguments) => kill_cmd.main(arguments);
