import 'dart:async';

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
  final _idCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _newPwCtrl = TextEditingController();
  final _newPw2Ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  int _step = 0;
  bool _loading = false;
  String? _error;
  List<String> _pwHints = const [];
  bool _obscure1 = true;
  bool _obscure2 = true;
  String? _lockedIdentifier;
  String? _resolvedEmail;

  @override
  void dispose() {
    _idCtrl.dispose();
    _otpCtrl.dispose();
    _newPwCtrl.dispose();
    _newPw2Ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _requestOtp() async {
    setState(() {
      _error = null;
      _loading = true;
    });
    final repo = ref.read(localAuthRepositoryProvider);
    final identifier = (_lockedIdentifier ?? _idCtrl.text).trim();
    final res = await repo.requestPasswordOtpForIdentifier(identifier);
    if (!mounted) return;
    setState(() => _loading = false);
    if (res.error != null) {
      setState(() => _error = res.error);
      return;
    }
    _lockedIdentifier = identifier;
    _resolvedEmail = res.resolvedEmail;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'If an account exists, a reset code was sent.',
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
    final email = (_resolvedEmail ?? '').trim();
    if (email.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Please request a code again.';
      });
      return;
    }
    final err = await repo.verifyPasswordOtp(
      email: email,
      code: _otpCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (err != null) {
      setState(() => _error = err);
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
    final email = (_resolvedEmail ?? '').trim();
    if (email.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Please request a code again.';
      });
      return;
    }
    final err = await repo.resetPasswordWithOtp(
      email: email,
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
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Forgot Password'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Scrollbar(
          controller: _scrollCtrl,
          child: SingleChildScrollView(
            controller: _scrollCtrl,
            padding: const EdgeInsets.all(20),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 10),
                    Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.lock_reset_rounded,
                          color: scheme.primary,
                          size: 34,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      _step == 0
                          ? 'Forgot Password'
                          : _step == 1
                              ? 'Verify Your Account'
                              : 'Set New Password',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _step == 0
                          ? 'Enter your email or phone number to receive a verification code'
                          : _step == 1
                              ? "An OTP has been sent. Please enter your OTP to continue."
                              : 'Choose a strong password for your account.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 18),
                    AppCard(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_step == 0) ...[
                              TextField(
                                controller: _idCtrl,
                                enabled: !_loading && _lockedIdentifier == null,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(
                                  labelText: 'Email or Phone',
                                  prefixIcon: Icon(Icons.mail_outline),
                                  hintText: 'e.g. name@company.com',
                                ),
                              ),
                            ] else if (_step == 1) ...[
                              _OtpSixBoxes(controller: _otpCtrl),
                              const SizedBox(height: 10),
                              Center(
                                child: TextButton(
                                  onPressed: _loading
                                      ? null
                                      : () => unawaited(_requestOtp()),
                                  child: const Text('Resend Code'),
                                ),
                              ),
                            ] else ...[
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
                              const SizedBox(height: 10),
                              Text(
                                _error!,
                                style: const TextStyle(
                                  color: AppColors.danger,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
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
                                        color: scheme.onPrimary,
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          _step == 0
                                              ? 'Send Code'
                                              : _step == 1
                                                  ? 'Verify & Continue'
                                                  : 'Update Password',
                                        ),
                                        const SizedBox(width: 10),
                                        const Icon(
                                          Icons.arrow_forward_rounded,
                                          size: 18,
                                        ),
                                      ],
                                    ),
                            ),
                            const SizedBox(height: 8),
                            if (_step == 0)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Remember password?',
                                    style: TextStyle(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  TextButton(
                                    onPressed: _loading ? null : () => context.pop(),
                                    child: const Text('Log in'),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    AppCard(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: scheme.primaryContainer,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.info_outline_rounded,
                                color: scheme.primary,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _step == 1
                                        ? 'Secure Authentication'
                                        : 'Security Tip',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _step == 1
                                        ? 'Enter the 6-digit code sent for verification.'
                                        : "We'll send a 6-digit code to the account you entered.",
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
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
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.55),
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
              hintText: 'Enter 6-digit code',
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }
}
