import 'dart:convert';

class PsParser {
  PsHeader? header;
  List<PsLine> lines = [];

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

  PsLine? findFirstByCmd(String contains) {
    for (final line in lines) {
      try {
        if (line.cmd!.contains(contains)) {
          return line;
        }
      } catch (e) {
        print(e);
        print(line);
      }
    }
    return null;
  }

  List<PsLine> findByCmd(String contains) {
    final psLines = <PsLine>[];
    for (final line in lines) {
      try {
        if (line.cmd!.contains(contains)) {
          psLines.add(line);
        }
      } catch (e) {
        print(e);
        print(line);
      }
    }
    return psLines;
  }
}

// USER      PID   PPID  VSIZE  RSS   WCHAN            PC  NAME
class PsHeader extends _PsLineBase {
  PsHeader(super.line) {
    //devPrint(_parts);
  }

  int findPartIndex(String name) {
    return _parts.indexOf(name);
  }
}

PsHeader _defaultHeader = PsHeader('PID CMD');

class PsLine extends _PsLineBase {
  late PsHeader _header;

  PsLine(super.line, {PsHeader? header}) {
    _header = header ?? _defaultHeader;
  }

  int get pid => int.parse(_getColumn('PID')!);

  String? _getColumn(String name) {
    var index = _header.findPartIndex(name);
    if (index >= 0) {
      return _parts[index];
    }
    return null;
  }

  String? get cmd => _getColumn('CMD'); //_getColumn('NAME');
// shell     7398  1310  1217116 16816 binder_thr a9529424 S com.android.commands.monkey
}

var spaceSplitRegExp = RegExp('\\s+');

class _PsLineBase {
  late List<String> _parts;

  _PsLineBase(String line) {
    _parts = line.trim().split(spaceSplitRegExp);
  }

  @override
  String toString() => _parts.join(' ');
}
