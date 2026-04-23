import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_providers.dart';
import '../../features/auth/password_rules.dart';
import '../../features/session/session_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';

/// Forgot password: request OTP → verify 6-digit code → auto-login (session bypass).
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _newPwCtrl = TextEditingController();
  final _newPw2Ctrl = TextEditingController();
  int _step = 0;
  bool _loading = false;
  String? _error;
  List<String> _pwHints = const [];
  bool _obscure1 = true;
  bool _obscure2 = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    _newPwCtrl.dispose();
    _newPw2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _requestOtp() async {
    setState(() {
      _error = null;
      _loading = true;
    });
    final repo = ref.read(localAuthRepositoryProvider);
    final err = await repo.requestPasswordOtp(_emailCtrl.text.trim());
    if (!mounted) return;
    setState(() => _loading = false);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    if (kDebugMode) {
      final peek = await repo.peekPendingOtpForDev();
      if (peek != null && mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Development OTP'),
            content: Text('SMTP is not configured. Use this code:\n\n$peek'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'If an account exists for that email, a reset code was sent.',
          ),
        ),
      );
    }
    setState(() => _step = 1);
  }

  Future<void> _verifyCode() async {
    setState(() {
      _error = null;
      _loading = true;
    });
    final repo = ref.read(localAuthRepositoryProvider);
    final res = await repo.completeOtpLogin(
      _emailCtrl.text.trim(),
      _otpCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (res.error != null) {
      setState(() => _error = res.error);
      return;
    }
    // Code is valid. Next: set a new password.
    setState(() => _step = 2);
  }

  Future<void> _resetPassword() async {
    setState(() {
      _error = null;
      _pwHints = passwordRuleFailures(_newPwCtrl.text);
      _loading = true;
    });

    if (_pwHints.isNotEmpty) {
      setState(() => _loading = false);
      return;
    }
    if (_newPwCtrl.text != _newPw2Ctrl.text) {
      setState(() {
        _loading = false;
        _error = 'Passwords do not match.';
      });
      return;
    }

    final repo = ref.read(localAuthRepositoryProvider);
    final err = await repo.resetPasswordWithOtp(
      email: _emailCtrl.text.trim(),
      code: _otpCtrl.text.trim(),
      newPassword: _newPwCtrl.text,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (err != null) {
      setState(() => _error = err);
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Password updated. Please sign in.')),
    );

    // Clear any active session state just in case.
    ref.read(sessionControllerProvider.notifier).endSession();
    // Go back to login screen.
    context.go('/auth');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Forgot password'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Scrollbar(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: AppCard(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _step == 0
                              ? 'Enter your account email. We will send a 6-digit code.'
                              : _step == 1
                                  ? 'Enter the 6-digit code.'
                                  : 'Set a new password for your account.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 18),
                        if (_step == 0)
                          TextField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.mail_outline),
                            ),
                          )
                        else if (_step == 1)
                          _OtpSixBoxes(controller: _otpCtrl),
                        if (_step == 2) ...[
                          TextField(
                            controller: _newPwCtrl,
                            obscureText: _obscure1,
                            onChanged: (_) => setState(
                              () => _pwHints =
                                  passwordRuleFailures(_newPwCtrl.text),
                            ),
                            decoration: InputDecoration(
                              labelText: 'New password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                onPressed: () =>
                                    setState(() => _obscure1 = !_obscure1),
                                icon: Icon(
                                  _obscure1
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _newPw2Ctrl,
                            obscureText: _obscure2,
                            decoration: InputDecoration(
                              labelText: 'Confirm new password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                onPressed: () =>
                                    setState(() => _obscure2 = !_obscure2),
                                icon: Icon(
                                  _obscure2
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                          ),
                          if (_pwHints.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            ..._pwHints.map(
                              (h) => Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Text(
                                  '• Missing: $h',
                                  style: const TextStyle(
                                    color: AppColors.danger,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            style: const TextStyle(
                              color: AppColors.danger,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: _loading
                              ? null
                              : () {
                                  if (_step == 0) {
                                    unawaited(_requestOtp());
                                  } else if (_step == 1) {
                                    unawaited(_verifyCode());
                                  } else {
                                    unawaited(_resetPassword());
                                  }
                                },
                          child: _loading
                              ? SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onPrimary,
                                  ),
                                )
                              : Text(
                                  _step == 0
                                      ? 'Send code'
                                      : _step == 1
                                          ? 'Verify code'
                                          : 'Update password',
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OtpSixBoxes extends StatefulWidget {
  const _OtpSixBoxes({required this.controller});

  final TextEditingController controller;

  @override
  State<_OtpSixBoxes> createState() => _OtpSixBoxesState();
}

class _OtpSixBoxesState extends State<_OtpSixBoxes> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onText);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onText);
    _focus.dispose();
    super.dispose();
  }

  void _onText() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: () => FocusScope.of(context).requestFocus(_focus),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (i) {
              final has = i < widget.controller.text.length;
              final ch = has ? widget.controller.text[i] : '';
              return Container(
                width: 44,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: i == widget.controller.text.length
                        ? AppColors.primary
                        : Theme.of(
                            context,
                          ).colorScheme.outline.withValues(alpha: 0.75),
                    width: i == widget.controller.text.length ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  ch,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 36,
          child: TextField(
            controller: widget.controller,
            focusNode: _focus,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, letterSpacing: 8),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            decoration: const InputDecoration(
              hintText: 'Tap boxes above, then type 6 digits',
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }
}
