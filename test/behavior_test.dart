import 'package:dlu_tkb/behavior.dart';
import 'package:dlu_tkb/paper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('scoreColor theo thang xếp loại', () {
    expect(scoreColor(95), Paper.mint);
    expect(scoreColor(80), Paper.sun);
    expect(scoreColor(73), Paper.peach);
    expect(scoreColor(50), Paper.rose);
  });

  test('gom nhóm tiêu chí, chỉ tính dòng có điểm', () {
    final rows = [
      {
        'BehaviorGroupName': 'Ý thức học tập',
        'MaxScoreGroup': 20,
        'BehaviorDetailName': 'Đi học chuyên cần',
        'MaxScore': 4,
        'LastScore': 4,
      },
      {
        'BehaviorGroupName': 'Ý thức học tập',
        'MaxScoreGroup': 20,
        'BehaviorDetailName': 'Xuất sắc',
        'MaxScore': 10,
        'LastScore': 0,
      },
      {
        'BehaviorGroupName': 'Nội quy',
        'MaxScoreGroup': 25,
        'BehaviorDetailName': 'Chấp hành nội quy',
        'MaxScore': 6,
        'LastScore': 6,
      },
    ];
    final g = behaviorGroups(rows);
    expect(g.length, 2);
    expect(g.first.name, 'Ý thức học tập');
    expect(g.first.max, 20);
    expect(groupScore(g.first.items), 4);
    // Phương án không được chọn vẫn nằm trong phiếu, đừng bày ra màn.
    expect(scoredItems(g.first.items).length, 1);
    expect(groupScore(g[1].items), 6);
  });
}
