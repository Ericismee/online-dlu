import 'package:flutter/material.dart';

import 'courses.dart';
import 'data.dart';
import 'graph.dart';
import 'paper.dart';
import 'portal.dart';

/// Màu theo thang xếp loại rèn luyện của trường.
Color scoreColor(num score) => switch (score) {
  >= 90 => Paper.mint,
  >= 80 => Paper.sun,
  >= 65 => Paper.peach,
  _ => Paper.rose,
};

/// Nhóm tiêu chí của phiếu rèn luyện, giữ nguyên thứ tự trường xếp.
List<({String name, num max, List<dynamic> items})> behaviorGroups(
  List<dynamic> rows,
) {
  final out = <String, List<dynamic>>{};
  final max = <String, num>{};
  for (final r in rows) {
    final ten = clean(r['BehaviorGroupName']);
    out.putIfAbsent(ten, () => []).add(r);
    max[ten] = toNum(r['MaxScoreGroup']);
  }
  return [
    for (final e in out.entries)
      (name: e.key, max: max[e.key] ?? 0, items: e.value),
  ];
}

/// Điểm chốt của một nhóm. Tiêu chí không được tính thì LastScore = 0,
/// cộng vào cũng không đổi gì.
num groupScore(List<dynamic> items) =>
    items.fold(0, (a, i) => a + toNum(i['LastScore']));

/// Chỉ những dòng thật sự có điểm — phiếu còn chứa cả phương án không chọn.
List<dynamic> scoredItems(List<dynamic> items) => [
  for (final i in items)
    if (toNum(i['LastScore']) != 0) i,
];

/// Điểm rèn luyện từng học kỳ, mới nhất trước.
class BehaviorScreen extends StatefulWidget {
  const BehaviorScreen({super.key, required this.session, this.portal});
  final Session session;
  final Portal? portal;

  @override
  State<BehaviorScreen> createState() => _BehaviorScreenState();
}

class _BehaviorScreenState extends State<BehaviorScreen>
    with Reloadable<BehaviorScreen> {
  @override
  Future<void> reload() => _load();

  List<dynamic>? _scores;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await (widget.portal ?? Portal()).behaviorScores(
        widget.session.token,
      );
      if (mounted) {
        setState(() {
          _scores = s;
          _error = null;
        });
      }
    } on PortalError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: DotBackground(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 940),
          child: PullRefresh(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                20,
                MediaQuery.paddingOf(context).top + 20,
                20,
                MediaQuery.paddingOf(context).bottom + 40,
              ),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Điểm rèn luyện',
                        style: TextStyle(
                          fontFamily: 'Display',
                          fontWeight: FontWeight.w800,
                          fontSize: 30,
                          color: Paper.ink,
                        ),
                      ),
                    ),
                    PaperButton(
                      label: 'Quay lại',
                      color: Paper.card,
                      onColor: Paper.ink,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_error != null)
                  PaperBox(
                    color: Paper.rose,
                    child: Text(_error!, style: TextStyle(color: Paper.ink)),
                  )
                else if (_scores == null)
                  const Skeleton(height: 160, ink: true)
                else
                  PaperBox(
                    child: Column(
                      children: [for (final s in _scores!.reversed) _Score(s)],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _Score extends StatelessWidget {
  const _Score(this.s);
  final dynamic s;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(
          child: Text(
            '${s['YearStudy']} · ${s['TermID']}',
            style: TextStyle(
              color: Paper.ink,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Pill(
          '${s['LastScore']} · ${s['BehaviorScoreRank']}',
          color: scoreColor(toNum(s['LastScore'])),
        ),
      ],
    ),
  );
}

/// Phiếu chấm rèn luyện một kỳ: từng tiêu chí cho bao nhiêu điểm, vì sao
/// tổng ra con số đó.
class BehaviorDetailScreen extends StatefulWidget {
  const BehaviorDetailScreen({super.key, required this.session, this.portal});
  final Session session;
  final Portal? portal;

  @override
  State<BehaviorDetailScreen> createState() => _BehaviorDetailScreenState();
}

class _BehaviorDetailScreenState extends State<BehaviorDetailScreen>
    with Reloadable<BehaviorDetailScreen> {
  @override
  Future<void> reload() => _load();

  late (String, String) _pick = yearTermFor(DateTime.now());
  Map<String, dynamic>? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool blank = false}) async {
    final pick = _pick;
    setState(() {
      if (blank) _data = null;
      _error = null;
    });
    try {
      final d = await (widget.portal ?? Portal()).behaviorDetail(
        widget.session.token,
        year: pick.$1,
        term: pick.$2,
      );
      if (mounted && pick == _pick) setState(() => _data = d);
    } on PortalError catch (e) {
      if (mounted && pick == _pick) setState(() => _error = e.message);
    }
  }

  void _set((String, String) p) {
    setState(() => _pick = p);
    _load(blank: true);
  }

  @override
  Widget build(BuildContext context) {
    final rows =
        _data?['ResultDataBangDanhGia'] as List<dynamic>? ?? const <dynamic>[];
    // Portal trả tổng kết trong một mảng một phần tử.
    final ket = (_data?['KetQuaDanhGia'] as List<dynamic>?)?.firstOrNull;
    return Scaffold(
      body: DotBackground(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 940),
            child: PullRefresh(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  MediaQuery.paddingOf(context).top + 20,
                  20,
                  MediaQuery.paddingOf(context).bottom + 40,
                ),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Phiếu rèn luyện',
                            maxLines: 1,
                            style: TextStyle(
                              fontFamily: 'Display',
                              fontWeight: FontWeight.w800,
                              fontSize: 30,
                              color: Paper.ink,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      PaperButton(
                        label: 'Quay lại',
                        color: Paper.card,
                        onColor: Paper.ink,
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Choice(
                        label: _pick.$1,
                        onTap: () async {
                          final y = await chooseOption(
                            context,
                            recentYears(DateTime.now()),
                            _pick.$1,
                          );
                          if (y != null) _set((y, _pick.$2));
                        },
                      ),
                      const SizedBox(width: 8),
                      Choice(
                        label: _pick.$2,
                        color: Paper.mint,
                        onTap: () async {
                          final t = await chooseOption(context, const [
                            'HK01',
                            'HK02',
                            'HK03',
                          ], _pick.$2);
                          if (t != null) _set((_pick.$1, t));
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_error != null)
                    PaperBox(
                      color: Paper.rose,
                      child: Text(_error!, style: TextStyle(color: Paper.ink)),
                    )
                  else if (_data == null) ...[
                    const Skeleton(height: 110, ink: true),
                    const SizedBox(height: 12),
                    const Skeleton(height: 200, ink: true),
                  ] else if (rows.isEmpty)
                    PaperBox(
                      child: Container(
                        color: Paper.sun,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        child: Text(
                          'Kỳ này chưa chấm',
                          style: TextStyle(
                            fontFamily: 'Display',
                            fontWeight: FontWeight.w800,
                            fontSize: 26,
                            color: Paper.ink,
                          ),
                        ),
                      ),
                    )
                  else ...[
                    if (ket != null) _Total(ket),
                    const SizedBox(height: 16),
                    for (final g in behaviorGroups(rows))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _Group(g),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Total extends StatelessWidget {
  const _Total(this.ket);
  final dynamic ket;

  @override
  Widget build(BuildContext context) {
    final diem = toNum(ket['Scores']);
    return PaperBox(
      color: scoreColor(diem),
      child: Row(
        children: [
          Text(
            '$diem',
            style: TextStyle(
              fontFamily: 'Display',
              fontWeight: FontWeight.w800,
              fontSize: 42,
              height: 1,
              color: Paper.ink,
            ),
          ),
          const SizedBox(width: 6),
          Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
              '/100',
              style: TextStyle(fontSize: 14, color: Paper.ink2),
            ),
          ),
          const Spacer(),
          Pill(clean(ket['BehaviorScoreRank']), color: Paper.card),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group(this.g);
  final ({String name, num max, List<dynamic> items}) g;

  @override
  Widget build(BuildContext context) {
    final co = scoredItems(g.items);
    return PaperBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  g.name,
                  style: TextStyle(
                    fontFamily: 'Display',
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    height: 1.2,
                    color: Paper.ink,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Pill('${groupScore(g.items)}/${g.max}', color: Paper.sun),
            ],
          ),
          const SizedBox(height: 8),
          if (co.isEmpty)
            Text(
              'Không có tiêu chí nào được tính điểm.',
              style: TextStyle(fontSize: 13, color: Paper.ink2),
            )
          else
            for (final i in co)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        clean(i['BehaviorDetailName']),
                        style: TextStyle(fontSize: 14, color: Paper.ink2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Pill(
                      '${toNum(i['LastScore'])}/${toNum(i['MaxScore'])}',
                      color: Paper.card,
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
