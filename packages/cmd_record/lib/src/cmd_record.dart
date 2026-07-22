#!/usr/bin/env dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart';
import 'package:process_run/cmd_run.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:tekartik_cmd_record/src/utils.dart';

/// The current version.
Version version = Version(0, 1, 0);

/// The name of the current script.
String get currentScriptName => basenameWithoutExtension(Platform.script.path);

/*
Testing

bin/cmd_record.dart example/echo.dart --stdout out
bin/cmd_record.dart -i cat

Global options:
-h, --help          Usage help
-o, --stdout        stdout content as string
-p, --stdout-hex    stdout as hexa string
-e, --stderr        stderr content as string
-f, --stderr-hex    stderr as hexa string
-i, --stdin         Handle first line of stdin
-x, --exit-code     Exit code to return
    --version       Print the command version
*/

/// Flag name for running in shell.
const String flagRunInShell = 'run-in-shell';

/// Flag name for stdin.
const String flagStdin = 'stdin';

/// Prefix for stdin lines in output.
const String inPrefix = r'$';

/// Prefix for stdout lines in output.
const String outPrefix = r'>';

/// Prefix for stderr lines in output.
const String errPrefix = r'E';

/// Records a command's I/O history.
class History {
  /// Recorded stdin items.
  final List<HistoryItem> inItems = [];

  /// Recorded stdout items.
  final List<HistoryItem> outItems = [];

  /// Recorded stderr items.
  final List<HistoryItem> errItems = [];

  /// The executable that was run.
  String? executable;

  /// The arguments passed to the executable.
  List<String>? arguments;

  /// When the command was started.
  late DateTime date;

  /// The process result.
  late ProcessResult result;

  /// The total duration of the command.
  Duration? duration;

  /// Serializes this history to a JSON-compatible map.
  Map<String, dynamic> toJson() {
    final record = <String, dynamic>{};
    record['date'] = date.toIso8601String();
    record['duration'] = duration.toString();
    record['executable'] = executable;
    record['arguments'] = arguments;

    if (inItems.isNotEmpty) {
      record['in'] = inItems;
    }

    if (outItems.isNotEmpty) {
      record['out'] = outItems;
    }
    if (errItems.isNotEmpty) {
      record['err'] = errItems;
    }
    record['exitCode'] = result.exitCode;
    return record;
  }
}

/// A single recorded I/O event.
class HistoryItem {
  /// Elapsed microseconds when this item was recorded.
  int? time;

  /// The line content.
  String? line;

  /// Serializes to [time, line].
  List<dynamic> toJson() => [time, line];

  /// Returns a formatted output string with the given [prefix].
  String getOutput(String prefix) {
    return '${durationToString(Duration(microseconds: time!))} $prefix $line';
  }
}

/// A [StreamSink] that records items into [HistoryItem]s.
class HistorySink implements StreamSink<List<int>> {
  /// The underlying sink to also write data to, or null.
  final StreamSink? ioSink;

  /// A stream of recorded [HistoryItem]s.
  Stream<HistoryItem> get stream => itemController.stream;

  /// Controller for raw byte chunks.
  StreamController<List<int>> lineController = StreamController(sync: true);

  /// Controller for decoded history items.
  StreamController<HistoryItem> itemController = StreamController(sync: true);

  /// Stopwatch used to timestamp items.
  final Stopwatch stopwatch;

  /// Whether [close] has been called.
  bool get isClosed => _isClosed;
  var _isClosed = false;

  @override
  Future get done => _doneCompleter.future;
  final _doneCompleter = Completer<dynamic>();

  /// Creates a new [HistorySink] wrapping optional [ioSink] and using [stopwatch] for timestamps.
  HistorySink(this.ioSink, this.stopwatch) {
    lineController.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((String line) {
          itemController.add(
            HistoryItem()
              ..time = stopwatch.elapsedMicroseconds
              ..line = line,
          );
        });
  }

  @override
  void add(List<int> data) {
    lineController.add(data);
    ioSink?.add(data);
  }

  @override
  void addError(error, [StackTrace? stackTrace]) {}

  @override
  Future addStream(Stream<List<int>> stream) {
    var completer = Completer<void>.sync();
    stream.listen(add, onError: addError, onDone: completer.complete);
    return completer.future;
  }

  @override
  Future close() async {
    /*
    // eventually close lose command
    add('\n'.codeUnits);
    if (results.last.line.isEmpty) {
      results.removeLast();
    }
    */
    _isClosed = true;
    await lineController.close();
    await itemController.close();
  }
}

///
/// write rest arguments as lines
/// if history is not null
///
Future record(
  String executable,
  List<String> arguments, {
  bool? runInShell,
  bool? recordStdin,

  /// prevent streaming to stderr and stdout in real time
  bool? noStdOutput,
  StringSink? dumpSink,
  History? history,
  Stream<List<int>>? inStream,
  bool? noStderr,
}) async {
  noStdOutput ??= false;
  noStderr ??= false;

  final stdinStream = inStream ?? stdin;
  // by default record if there is an incoming stream
  recordStdin ??= inStream != null;

  // Run the command
  final cmd = ProcessCmd(executable, arguments, runInShell: runInShell);

  final stopwatch = Stopwatch();

  final outSink = HistorySink(noStdOutput ? null : stdout, stopwatch);
  outSink.stream.listen((HistoryItem item) {
    // Output
    dumpSink?.writeln(item.getOutput(outPrefix));
    history?.outItems.add(item);
  });
  HistorySink? errSink;
  if (!noStderr) {
    errSink = HistorySink(noStdOutput ? null : stderr, stopwatch);
    errSink.stream.listen((HistoryItem item) {
      // Output
      dumpSink?.writeln(item.getOutput(errPrefix));
      history?.errItems.add(item);
    });
  }

  final stdinController = StreamController<List<int>>(sync: true);
  final stdinRecordController = StreamController<List<int>>(sync: true);

  if (recordStdin) {
    stdinStream.listen((List<int> data) {
        stdinController.add(data);
        stdinRecordController.add(data);
      })
      ..onError((Object e, StackTrace st) {
        stdinController.addError(e, st);
        stdinRecordController.addError(e, st);
      })
      ..onDone(() {
        stdinController.close();
        stdinRecordController.close();
      });

    stdinRecordController.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((String line) {
          var item = HistoryItem()
            ..time = stopwatch.elapsedMicroseconds
            ..line = line;
          // Output
          dumpSink?.writeln(item.getOutput(inPrefix));
          history?.inItems.add(item);
        });
  }

  history?.date = DateTime.now();
  history?.executable = executable;
  history?.arguments = arguments;

  stopwatch.start();
  final result = await runCmd(
    cmd,
    stdout: outSink,
    stderr: errSink,
    stdin: recordStdin ? stdinController.stream : null,
  );

  await outSink.close();
  await errSink?.close();
  history?.result = result;
  history?.duration = stopwatch.elapsed;
}

class _Parser {
  int? index = 0;
  final List<HistoryItem> list;
  final String prefix;

  _Parser(this.prefix, this.list);

  HistoryItem? get current {
    if (index == null) {
      return null;
    } else if (index! >= (list.length)) {
      index = null;
      return null;
    }
    return list[index!];
  }

  void next() {
    index = index! + 1;
  }
}

/// Dumps [history] to stdout in a human-readable format.
void dump(History history) {
  final inParser = _Parser(r'$', history.inItems);
  var parsers = [inParser];
  stdout.writeln('date ${history.date}\nduration ${history.duration}');
  stdout.writeln(
    '\$ ${executableArgumentsToString(history.executable!, history.arguments)}\n',
  );

  var done = false;
  while (!done) {
    _Parser? minParser;
    int? minTime;
    for (final parser in parsers) {
      final item = parser.current;
      if (item != null) {
        if ((minTime == null) || (item.time! < minTime)) {
          minParser = parser;
          minTime = item.time;
        }
      }
    }

    if (minParser != null) {
      stdout.writeln(minParser.current!.getOutput(inParser.prefix));

      /*
    }
      for (_Parser parser in parsers) {
        if (identical(parser, minParser)) {
      }
      */
      minParser.next();
    } else {
      done = true;
    }
  }
}
