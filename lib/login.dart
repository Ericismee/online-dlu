import 'package:flutter/material.dart';

import 'cache.dart';
import 'paper.dart';
import 'portal.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onLoggedIn, this.initialError});

  final void Function(Session) onLoggedIn;
  final String? initialError;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  late String? _error = widget.initialError;
  bool _remember = true;
  bool _hidePass = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    Vault.read().then((c) {
      if (c != null && mounted) {
        setState(() {
          _user.text = c.$1;
          _pass.text = c.$2;
        });
      }
    });
  }

  Future<void> _submit() async {
    final user = _user.text.trim();
    final pass = _pass.text;
    if (user.isEmpty || pass.isEmpty) {
      return setState(() => _error = 'Nhập tài khoản và mật khẩu');
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = await Portal().login(user, pass);
      if (_remember) {
        await Vault.save(user, pass);
      } else {
        await Vault.clear();
      }
      // Sổ đi theo tài khoản vừa đăng nhập, trước khi màn nào kịp đọc: đổi
      // người là đổi tệp SQLite, không có vụ người sau thấy lịch tự đặt hay
      // thông báo của người trước.
      await Cache.doiSo(user);
      if (mounted) widget.onLoggedIn(session);
    } on PortalError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: DotBackground(
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Paper.card,
                        border: Paper.border,
                        borderRadius: BorderRadius.all(Paper.radius),
                        boxShadow: Paper.shadow(5),
                      ),
                      child: Image.asset(
                        'assets/logo_icon.png',
                        width: 108,
                        height: 108,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Đại Học Đà Lạt',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Display',
                      fontWeight: FontWeight.w800,
                      fontSize: 38,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Đăng nhập bằng tài khoản portal DLU',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Paper.ink2),
                  ),
                  const SizedBox(height: 24),
                  PaperBox(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        PaperLabel('Mã sinh viên'),
                        PaperField(
                          nhan: 'Mã sinh viên',
                          controller: _user,
                          enabled: !_busy,
                          keyboardType: TextInputType.number,
                          autofillHints: const [AutofillHints.username],
                          action: TextInputAction.next,
                          onSubmit: () => FocusScope.of(context).nextFocus(),
                        ),
                        const SizedBox(height: 14),
                        PaperLabel('Mật khẩu'),
                        PaperField(
                          nhan: 'Mật khẩu',
                          controller: _pass,
                          enabled: !_busy,
                          obscure: _hidePass,
                          autofillHints: const [AutofillHints.password],
                          onSubmit: _submit,
                          suffix: IconButton(
                            icon: Icon(
                              _hidePass
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: Paper.ink2,
                              size: 20,
                            ),
                            onPressed: () =>
                                setState(() => _hidePass = !_hidePass),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Semantics(
                          checked: _remember,
                          child: InkWell(
                            onTap: () => setState(() => _remember = !_remember),
                            child: Padding(
                              // Hàng cao 22pt thì hụt ngưỡng chạm 44pt.
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              child: Row(
                                children: [
                                  _Check(on: _remember),
                                  const SizedBox(width: 10),
                                  const Text(
                                    'Nhớ tài khoản',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 14),
                          PaperBox(
                            color: Paper.rose,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        _busy
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(8),
                                  child: CircularProgressIndicator(
                                    color: Paper.accent,
                                    strokeWidth: 3,
                                  ),
                                ),
                              )
                            : Align(
                                alignment: Alignment.centerRight,
                                child: PaperButton(
                                  label: 'Đăng nhập',
                                  onPressed: _submit,
                                ),
                              ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _Check extends StatelessWidget {
  const _Check({required this.on});
  final bool on;

  @override
  Widget build(BuildContext context) => Container(
    width: 22,
    height: 22,
    decoration: BoxDecoration(
      color: on ? Paper.mint : Paper.card,
      border: Paper.border,
      borderRadius: BorderRadius.all(Paper.radius),
    ),
    child: on ? const Icon(Icons.check, size: 15, color: Paper.ink) : null,
  );
}
