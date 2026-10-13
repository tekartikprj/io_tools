import 'package:dev_test/test.dart';
import 'package:tekartik_cmd_record/src/cmd_record.dart';

HistoryItem _item(int ms, String line) => HistoryItem()
  ..time = ms * 1000
  ..line = line;

void main() {
  group('cmd_record dump', () {
    test('historyDumpLines', () {
      var history = History();
      history.inItems.add(_item(1, 'in1'));
      history.outItems.addAll([_item(2, 'out1'), _item(5, 'out2')]);
      history.errItems.add(_item(3, 'err1'));
      history.inItems.add(_item(4, 'in2'));
      expect(historyDumpLines(history), [
        '00:00.001 \$ in1',
        '00:00.002 > out1',
        '00:00.003 E err1',
        '00:00.004 \$ in2',
        '00:00.005 > out2',
      ]);
    });
  });
}
