import 'dart:convert';

/// Parses output from the `ps` command.
class PsParser {
  /// The parsed header line.
  PsHeader? header;

  /// The parsed process lines.
  List<PsLine> lines = [];

  /// Creates a [PsParser] from [shellPsStdout].
  PsParser(String shellPsStdout) {
    final lines = LineSplitter.split(shellPsStdout);

    for (final line in lines) {
      if (header == null) {
        header = PsHeader(line);
      } else {
        this.lines.add(PsLine(line, header: header));
      }
    }
  }

  /// Returns the first line whose CMD contains [contains], or null.
  PsLine? findFirstByCmd(String contains) {
    for (final line in lines) {
      try {
        if (line.cmd!.contains(contains)) {
          return line;
        }
      } catch (e) {
        // ignore: avoid_print
        print(e);
        // ignore: avoid_print
        print(line);
      }
    }
    return null;
  }

  /// Returns all lines whose CMD contains [contains].
  List<PsLine> findByCmd(String contains) {
    final psLines = <PsLine>[];
    for (final line in lines) {
      try {
        if (line.cmd!.contains(contains)) {
          psLines.add(line);
        }
      } catch (e) {
        // ignore: avoid_print
        print(e);
        // ignore: avoid_print
        print(line);
      }
    }
    return psLines;
  }

  /// [pid] and the pids of its parents found in the ps output (needs a PPID
  /// column), i.e. the processes running the current command.
  Set<int> selfAndParentPids(int pid) {
    var pids = <int>{};
    int? current = pid;
    while (current != null && pids.add(current)) {
      int? parent;
      for (final line in lines) {
        if (int.tryParse(line._getColumn('PID') ?? '') == current) {
          parent = line.ppid;
          break;
        }
      }
      current = parent;
    }
    return pids;
  }
}

// USER      PID   PPID  VSIZE  RSS   WCHAN            PC  NAME
/// Represents the header row of `ps` output.
class PsHeader extends _PsLineBase {
  /// Creates a [PsHeader] from [line].
  PsHeader(super.line) {
    //devPrint(_parts);
  }

  /// Returns the column index for [name].
  int findPartIndex(String name) {
    return _parts.indexOf(name);
  }
}

PsHeader _defaultHeader = PsHeader('PID CMD');

/// Represents a single process row in `ps` output.
class PsLine extends _PsLineBase {
  late PsHeader _header;

  /// Creates a [PsLine] from [line] using the given [header].
  PsLine(super.line, {PsHeader? header}) {
    _header = header ?? _defaultHeader;
  }

  /// The process ID.
  int get pid => int.parse(_getColumn('PID')!);

  String? _getColumn(String name) {
    var index = _header.findPartIndex(name);
    if (index >= 0 && index < _parts.length) {
      return _parts[index];
    }
    return null;
  }

  /// The parent process ID, null if there is no PPID column.
  int? get ppid => int.tryParse(_getColumn('PPID') ?? '');

  /// The command line (the command and its arguments when CMD is the last
  /// column).
  String? get cmd {
    var index = _header.findPartIndex('CMD');
    if (index >= 0 && index == _header._parts.length - 1) {
      if (index < _parts.length) {
        return _parts.sublist(index).join(' ');
      }
      return null;
    }
    return _getColumn('CMD');
  }
  // shell     7398  1310  1217116 16816 binder_thr a9529424 S com.android.commands.monkey
}

/// Regex for splitting on whitespace.
var spaceSplitRegExp = RegExp('\\s+');

class _PsLineBase {
  late List<String> _parts;

  _PsLineBase(String line) {
    _parts = line.trim().split(spaceSplitRegExp);
  }

  @override
  String toString() => _parts.join(' ');
}
