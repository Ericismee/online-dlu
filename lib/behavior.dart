import 'package:flutter/material.dart';

import 'paper.dart';
import 'portal.dart';

/// Màu theo thang xếp loại rèn luyện của trường.
Color scoreColor(num score) => switch (score) {
  >= 90 => Paper.mint,
  >= 80 => Paper.sun,
  >= 65 => Paper.peach,
  _ => Paper.rose,
};

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
      if (mounted) setState(() => _scores = s);
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
                40,
              ),
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Điểm rèn luyện',
                        style: TextStyle(
                          fontFamily: 'Baloo',
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
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Paper.ink),
                    ),
                  )
                else if (_scores == null)
                  const Skeleton(height: 160, radius: 16, ink: true)
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
            style: const TextStyle(
              color: Paper.ink,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Pill(
          '${s['LastScore']} · ${s['BehaviorScoreRank']}',
          color: scoreColor(s['LastScore'] as num? ?? 0),
        ),
      ],
    ),
  );
}
