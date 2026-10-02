import 'package:flutter/material.dart';

import 'data.dart';
import 'lms.dart';
import 'paper.dart';
import 'portal.dart';

int unread(Iterable<dynamic> messages) => messages
    .where((m) => m is LmsNotification ? m.unread : m['IsRead'] == 0)
    .length;

/// Chuông + popup hộp thư, dán ở góc phải top bar.
class Bell extends StatefulWidget {
  const Bell({super.key, required this.session, this.portal});
  final Session session;
  final Portal? portal;

  @override
  State<Bell> createState() => _BellState();
}

class _BellState extends State<Bell>
    with Reloadable<Bell>, SingleTickerProviderStateMixin {
  /// Lắc chuông kiểu bell-wiggle của codex-resets.com: -14deg, 11deg, -5deg.
  late final _wiggle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  late final _angle = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.24), weight: 25),
    TweenSequenceItem(tween: Tween(begin: -0.24, end: 0.19), weight: 30),
    TweenSequenceItem(tween: Tween(begin: 0.19, end: -0.09), weight: 25),
    TweenSequenceItem(tween: Tween(begin: -0.09, end: 0.0), weight: 20),
  ]).animate(_wiggle);

  @override
  Future<void> reload() => _load();

  List<dynamic>? _msgs;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _wiggle.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final combined = <dynamic>[];
    try {
      combined.addAll(
        await (widget.portal ?? Portal()).messages(widget.session.token),
      );
    } on PortalError {
      // LMS remains independent when Online is unavailable.
    }
    try {
      final session = await Lms.phien();
      if (session != null) {
        combined.addAll(await Lms().notifications(session));
      }
    } on PortalError {
      // Online messages remain visible when LMS is unavailable.
    }
    if (mounted) {
      setState(() => _msgs = combined);
      if (unread(combined) > 0) _wiggle.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = unread(_msgs ?? const []);
    return Semantics(
      button: true,
      label: n > 0 ? 'Thông báo, $n tin chưa đọc' : 'Thông báo',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _msgs == null
            ? null
            : () {
                _wiggle.forward(from: 0);
                _open(context);
              },
        child: AnimatedBuilder(
          animation: _angle,
          builder: (context, child) =>
              Transform.rotate(angle: _angle.value, child: child),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                // 12+22+12 = 46pt, đủ ngưỡng chạm.
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Paper.card,
                  border: Paper.border,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: Paper.shadow(3),
                ),
                child: Icon(
                  Icons.notifications_rounded,
                  size: 22,
                  color: _msgs == null ? Paper.ink3 : Paper.ink,
                ),
              ),
              if (n > 0)
                Positioned(
                  top: -6,
                  right: -6,
                  child: Transform.rotate(
                    angle: -0.12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Paper.accent,
                        border: Paper.border,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$n',
                        style: const TextStyle(
                          fontFamily: 'Baloo',
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: Paper.card,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context) => showDialog(
    context: context,
    builder: (_) => _Inbox(messages: _msgs!),
  );
}

class _Inbox extends StatelessWidget {
  const _Inbox({required this.messages});
  final List<dynamic> messages;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    insetPadding: const EdgeInsets.all(20),
    child: Container(
      constraints: const BoxConstraints(maxWidth: 520, maxHeight: 560),
      decoration: BoxDecoration(
        color: Paper.paper,
        border: Paper.border,
        borderRadius: BorderRadius.circular(20),
        boxShadow: Paper.shadow(6),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Thông báo',
                  style: TextStyle(
                    fontFamily: 'Baloo',
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    color: Paper.ink,
                  ),
                ),
              ),
              PaperButton(
                label: 'Đóng',
                color: Paper.card,
                onColor: Paper.ink,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (messages.isEmpty)
            const Text('Hộp thư trống.', style: TextStyle(color: Paper.ink2))
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: messages.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _Message(messages[i]),
              ),
            ),
        ],
      ),
    ),
  );
}

class _Message extends StatelessWidget {
  const _Message(this.m);
  final dynamic m;

  @override
  Widget build(BuildContext context) {
    if (m is LmsNotification) {
      final notification = m as LmsNotification;
      return PaperBox(
        color: notification.unread ? Paper.sun : Paper.card,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              clean(notification.subject),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Paper.ink,
              ),
            ),
            if (notification.body.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                clean(notification.body),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Pill('LMS · ${clean(notification.sender)}', color: Paper.mint),
                const SizedBox(width: 6),
                Text(
                  notification.date,
                  style: const TextStyle(fontSize: 12, color: Paper.ink3),
                ),
              ],
            ),
          ],
        ),
      );
    }
    final isNew = m['IsRead'] == 0;
    return PaperBox(
      color: isNew ? Paper.sun : Paper.card,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            clean(m['MessageSubject']),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Paper.ink,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Pill(m['SenderName'] as String? ?? '—', color: Paper.mint),
              const SizedBox(width: 6),
              Text(
                m['CreationDate'] as String? ?? '',
                style: const TextStyle(fontSize: 12, color: Paper.ink3),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
