import 'package:flutter/material.dart';

import 'paper.dart';
import 'portal.dart';

int unread(Iterable<dynamic> messages) =>
    messages.where((m) => m['IsRead'] == 0).length;

/// Chuông + popup hộp thư, dán ở góc phải top bar.
class Bell extends StatefulWidget {
  const Bell({super.key, required this.session, this.portal});
  final Session session;
  final Portal? portal;

  @override
  State<Bell> createState() => _BellState();
}

class _BellState extends State<Bell> {
  List<dynamic>? _msgs;

  @override
  void initState() {
    super.initState();
    (widget.portal ?? Portal())
        .messages(widget.session.token)
        .then((m) => mounted ? setState(() => _msgs = m) : null)
        .catchError((_) => null);
  }

  @override
  Widget build(BuildContext context) {
    final n = unread(_msgs ?? const []);
    return GestureDetector(
      onTap: _msgs == null ? null : () => _open(context),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Paper.card,
              border: Paper.border,
              borderRadius: BorderRadius.circular(14),
              boxShadow: Paper.shadow(3),
            ),
            child: const Icon(
              Icons.notifications_rounded,
              size: 22,
              color: Paper.ink,
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
    final isNew = m['IsRead'] == 0;
    return PaperBox(
      color: isNew ? Paper.sun : Paper.card,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            m['MessageSubject'] as String? ?? '',
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
