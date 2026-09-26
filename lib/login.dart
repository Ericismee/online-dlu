import 'package:flutter/material.dart';

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
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Paper.card,
                        border: Paper.border,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: Paper.shadow(4),
                      ),
                      child: Image.asset(
                        'assets/logo_icon.png',
                        width: 72,
                        height: 72,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Đại Học Đà Lạt',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Baloo',
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
                        _Label('Mã sinh viên'),
                        _Input(
                          controller: _user,
                          enabled: !_busy,
                          keyboardType: TextInputType.number,
                          autofillHints: const [AutofillHints.username],
                          onSubmit: _submit,
                        ),
                        const SizedBox(height: 14),
                        _Label('Mật khẩu'),
                        _Input(
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
                        InkWell(
                          onTap: () => setState(() => _remember = !_remember),
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
                  const SizedBox(height: 16),
                  const Text(
                    'Mật khẩu được lưu trong Keychain/Keystore của máy, '
                    'không gửi đi đâu ngoài portal DLU.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Paper.ink3),
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

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
    ),
  );
}

class _Input extends StatelessWidget {
  const _Input({
    required this.controller,
    required this.onSubmit,
    this.enabled = true,
    this.obscure = false,
    this.suffix,
    this.keyboardType,
    this.autofillHints,
  });

  final TextEditingController controller;
  final VoidCallback onSubmit;
  final bool enabled;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: c, width: 2),
    );
    return TextField(
      controller: controller,
      enabled: enabled,
      obscureText: obscure,
      keyboardType: keyboardType,
      autofillHints: autofillHints,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => onSubmit(),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: Paper.paper,
        suffixIcon: suffix,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: border(Paper.ink),
        enabledBorder: border(Paper.ink),
        disabledBorder: border(Paper.ink3),
        focusedBorder: border(Paper.accent),
      ),
    );
  }
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
      borderRadius: BorderRadius.circular(7),
    ),
    child: on ? const Icon(Icons.check, size: 15, color: Paper.ink) : null,
  );
}
