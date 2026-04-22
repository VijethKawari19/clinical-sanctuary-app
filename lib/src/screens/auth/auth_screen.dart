import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_providers.dart';
import '../../features/auth/local_auth_repository.dart';
import '../../features/auth/password_rules.dart';
import '../../features/session/session_controller.dart';
import '../../features/settings/settings_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/segmented_tabs.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool _isLogin = true;
  AppRole _role = AppRole.clinician;

  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _fullNameCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  final _licenseCtrl = TextEditingController();
  final _specializationCtrl = TextEditingController();
  final _workLocationCtrl = TextEditingController();

  final _workAddressCtrl = TextEditingController();
  final _clinicLocationCtrl = TextEditingController();

  String? _occupation;
  final List<String> _documentPaths = [];

  bool _rememberMe = true;
  bool _obscureLoginPassword = true;
  bool _obscureSignupPassword = true;
  bool _obscureSignupPassword2 = true;
  bool _submitting = false;

  String? _formError;
  List<String> _passwordHints = const [];

  static const _occupations = [
    'Nurse',
    'Lab Tech',
    'Community Health Worker',
    'Physician Assistant',
    'Dental Assistant',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRemembered());
  }

  Future<void> _loadRemembered() async {
    final repo = ref.read(localAuthRepositoryProvider);
    final r = await repo.loadRemembered();
    if (!mounted) return;
    if (r.email != null) {
      setState(() {
        _emailCtrl.text = r.email!;
        if (r.role != null) _role = r.role!;
      });
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _phoneCtrl.dispose();
    _fullNameCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _licenseCtrl.dispose();
    _specializationCtrl.dispose();
    _workLocationCtrl.dispose();
    _workAddressCtrl.dispose();
    _clinicLocationCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDocument() async {
    String? label;
    if (kIsWeb ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      final f = await openFile(
        acceptedTypeGroups: [
          const XTypeGroup(
            label: 'Documents',
            extensions: ['pdf', 'png', 'jpg', 'jpeg'],
          ),
        ],
      );
      if (f == null) return;
      label = f.path.isNotEmpty ? f.path : f.name;
    } else {
      // Mobile: skip or use image_picker — keep file_selector path only on desktop
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Document pick on this platform: use desktop build or add picker.',
            ),
          ),
        );
      }
      return;
    }
    if (!mounted) return;
    final docPath = label;
    setState(() {
      _documentPaths.add(docPath);
    });
  }

  Future<void> _submitLogin() async {
    setState(() {
      _formError = null;
      _submitting = true;
    });
    final repo = ref.read(localAuthRepositoryProvider);
    final email = _emailCtrl.text.trim();
    final pw = _passwordCtrl.text;
    if (!isValidEmail(email)) {
      setState(() {
        _formError = 'Enter a valid email address.';
        _submitting = false;
      });
      return;
    }
    if (pw.isEmpty) {
      setState(() {
        _formError = 'Password is required.';
        _submitting = false;
      });
      return;
    }
    final res = await repo.loginWithPassword(
      email: email,
      password: pw,
      selectedRole: _role,
    );
    if (!mounted) return;
    if (res.fail != null) {
      setState(() {
        _submitting = false;
        _formError = switch (res.fail!) {
          LoginFailure.notFound => 'No account found for this email.',
          LoginFailure.badPassword => 'Incorrect password.',
          LoginFailure.roleMismatch =>
            'This account is not registered as ${_role == AppRole.clinician ? 'a clinician' : 'a health worker'}. Select the correct role.',
        };
      });
      return;
    }
    final user = res.user!;
    if (_rememberMe) {
      await repo.saveRemembered(email: user.email, role: user.appRole);
    } else {
      await repo.clearRemembered();
    }
    ref
        .read(sessionControllerProvider.notifier)
        .startSession(
          email: user.email,
          role: user.appRole,
          loginHistory: user.loginHistory,
        );
    final settings = ref.read(settingsControllerProvider.notifier);
    unawaited(settings.setProfileName(user.displayName));
    unawaited(settings.setProfileEmail(user.email));
    unawaited(
      settings.setProfileRole(
        user.appRole == AppRole.healthWorker ? 'HEALTH WORKER' : 'CLINICIAN',
      ),
    );
    setState(() => _submitting = false);
    if (!mounted) return;
    if (user.appRole == AppRole.healthWorker) {
      context.go('/w/capture');
    } else {
      context.go('/c/dashboard');
    }
  }

  Future<void> _submitSignup() async {
    setState(() {
      _formError = null;
      _passwordHints = passwordRuleFailures(_passwordCtrl.text);
      _submitting = true;
    });
    if (_fullNameCtrl.text.trim().isEmpty) {
      setState(() {
        _formError = 'Full name is required.';
        _submitting = false;
      });
      return;
    }
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      setState(() {
        _formError = 'Phone number is required.';
        _submitting = false;
      });
      return;
    }
    if (phone.length != 10) {
      setState(() {
        _formError = 'Phone number must be exactly 10 digits.';
        _submitting = false;
      });
      return;
    }
    if (!isValidEmail(_emailCtrl.text.trim())) {
      setState(() {
        _formError = 'Enter a valid email address.';
        _submitting = false;
      });
      return;
    }
    if (_passwordHints.isNotEmpty) {
      setState(() => _submitting = false);
      return;
    }
    if (_passwordCtrl.text != _confirmPasswordCtrl.text) {
      setState(() {
        _formError = 'Passwords do not match.';
        _submitting = false;
      });
      return;
    }
    if (_role == AppRole.clinician) {
      if (_licenseCtrl.text.trim().isEmpty ||
          _specializationCtrl.text.trim().isEmpty ||
          _workLocationCtrl.text.trim().isEmpty) {
        setState(() {
          _formError =
              'Clinician license, specialization, and work location are required.';
          _submitting = false;
        });
        return;
      }
    } else {
      if (_occupation == null ||
          _workAddressCtrl.text.trim().isEmpty ||
          _clinicLocationCtrl.text.trim().isEmpty) {
        setState(() {
          _formError =
              'Occupation, work address, and clinic location are required.';
          _submitting = false;
        });
        return;
      }
    }

    final profile = <String, dynamic>{
      'fullName': _fullNameCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
    };
    if (_role == AppRole.clinician) {
      profile['license'] = _licenseCtrl.text.trim();
      profile['specialization'] = _specializationCtrl.text.trim();
      profile['workLocation'] = _workLocationCtrl.text.trim();
    } else {
      profile['occupation'] = _occupation;
      profile['workAddress'] = _workAddressCtrl.text.trim();
      profile['clinicLocation'] = _clinicLocationCtrl.text.trim();
    }

    final err = await ref
        .read(localAuthRepositoryProvider)
        .register(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
          role: _role,
          profile: profile,
          documentPaths: List<String>.from(_documentPaths),
        );
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _formError = err;
        _submitting = false;
      });
      return;
    }
    setState(() => _submitting = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account created. Please sign in.')),
      );
      setState(() {
        _isLogin = true;
        _passwordCtrl.clear();
        _confirmPasswordCtrl.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final maxWidth = width >= 1100
        ? 560.0
        : (width >= 520 ? 500.0 : width - 32);

    return Scaffold(
      body: SafeArea(
        child: Scrollbar(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Column(
                  children: [
                    const _BrandHeader(),
                    const SizedBox(height: 18),
                    Text(
                      _isLogin ? 'Welcome Back' : 'Create Account',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isLogin
                          ? 'Select your role, then sign in with your credentials.'
                          : 'Professional verification — fields vary by role.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 18),
                    SegmentedTabs(
                      leftLabel: 'Login',
                      rightLabel: 'Sign Up',
                      isLeftSelected: _isLogin,
                      onChanged: (isLogin) => setState(() {
                        _isLogin = isLogin;
                        _formError = null;
                      }),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: _RoleCard(
                            title: 'Health Worker',
                            icon: Icons.business_center_outlined,
                            selected: _role == AppRole.healthWorker,
                            onTap: () =>
                                setState(() => _role = AppRole.healthWorker),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _RoleCard(
                            title: 'Clinician',
                            icon: Icons.medical_information_outlined,
                            selected: _role == AppRole.clinician,
                            onTap: () =>
                                setState(() => _role = AppRole.clinician),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: _isLogin
                            ? _buildLoginFields()
                            : _buildSignupFields(),
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

  List<Widget> _buildLoginFields() {
    return [
      const _FieldLabel('EMAIL ADDRESS'),
      const SizedBox(height: 8),
      TextField(
        controller: _emailCtrl,
        keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.mail_outline),
          hintText: 'name@clinic.com',
        ),
      ),
      const SizedBox(height: 14),
      const _FieldLabel('PASSWORD'),
      const SizedBox(height: 8),
      TextField(
        controller: _passwordCtrl,
        obscureText: _obscureLoginPassword,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.lock_outline),
          suffixIcon: IconButton(
            onPressed: () =>
                setState(() => _obscureLoginPassword = !_obscureLoginPassword),
            icon: Icon(
              _obscureLoginPassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
          ),
          hintText: '••••••••',
        ),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Checkbox(
            value: _rememberMe,
            onChanged: (v) => setState(() => _rememberMe = v ?? false),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const Text('Remember me'),
          const Spacer(),
          TextButton(
            onPressed: _submitting
                ? null
                : () => context.push('/auth/forgot-password'),
            child: const Text('Forgot Password?'),
          ),
        ],
      ),
      if (_formError != null) ...[
        const SizedBox(height: 8),
        Text(
          _formError!,
          style: const TextStyle(
            color: AppColors.danger,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
      const SizedBox(height: 12),
      FilledButton(
        onPressed: _submitting ? null : () => unawaited(_submitLogin()),
        child: _submitting
            ? SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Login'),
                  SizedBox(width: 10),
                  Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
      ),
    ];
  }

  List<Widget> _buildSignupFields() {
    return [
      const _FieldLabel('FULL NAME'),
      const SizedBox(height: 8),
      TextField(
        controller: _fullNameCtrl,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.person_outline),
          hintText: 'Legal name',
        ),
      ),
      const SizedBox(height: 14),
      const _FieldLabel('PHONE NUMBER'),
      const SizedBox(height: 8),
      TextField(
        controller: _phoneCtrl,
        keyboardType: TextInputType.phone,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(10),
        ],
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.phone_outlined),
          hintText: '10-digit phone number',
        ),
      ),
      const SizedBox(height: 14),
      const _FieldLabel('EMAIL ADDRESS'),
      const SizedBox(height: 8),
      TextField(
        controller: _emailCtrl,
        keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.mail_outline),
          hintText: 'name@clinic.com',
        ),
      ),
      const SizedBox(height: 14),
      const _FieldLabel('PASSWORD'),
      const SizedBox(height: 8),
      TextField(
        controller: _passwordCtrl,
        obscureText: _obscureSignupPassword,
        onChanged: (_) => setState(
          () => _passwordHints = passwordRuleFailures(_passwordCtrl.text),
        ),
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.lock_outline),
          suffixIcon: IconButton(
            onPressed: () => setState(
              () => _obscureSignupPassword = !_obscureSignupPassword,
            ),
            icon: Icon(
              _obscureSignupPassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
          ),
          hintText: '8+ chars, upper, lower, number, special',
        ),
      ),
      if (_passwordHints.isNotEmpty) ...[
        const SizedBox(height: 6),
        ..._passwordHints.map(
          (h) => Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              '• Missing: $h',
              style: const TextStyle(color: AppColors.danger, fontSize: 12),
            ),
          ),
        ),
      ],
      const SizedBox(height: 14),
      const _FieldLabel('CONFIRM PASSWORD'),
      const SizedBox(height: 8),
      TextField(
        controller: _confirmPasswordCtrl,
        obscureText: _obscureSignupPassword2,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.lock_outline),
          suffixIcon: IconButton(
            onPressed: () => setState(
              () => _obscureSignupPassword2 = !_obscureSignupPassword2,
            ),
            icon: Icon(
              _obscureSignupPassword2
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
          ),
        ),
      ),
      if (_role == AppRole.clinician) ...[
        const SizedBox(height: 14),
        const _FieldLabel('LICENSE NUMBER'),
        const SizedBox(height: 8),
        TextField(
          controller: _licenseCtrl,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.badge_outlined),
            hintText: 'e.g. MED-12345678',
          ),
        ),
        const SizedBox(height: 14),
        const _FieldLabel('SPECIALIZATION'),
        const SizedBox(height: 8),
        TextField(
          controller: _specializationCtrl,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.science_outlined),
            hintText: 'e.g. Oral Oncology',
          ),
        ),
        const SizedBox(height: 14),
        const _FieldLabel('WORK LOCATION'),
        const SizedBox(height: 8),
        TextField(
          controller: _workLocationCtrl,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.local_hospital_outlined),
            hintText: 'Hospital / clinic name',
          ),
        ),
      ] else ...[
        const SizedBox(height: 14),
        const _FieldLabel('OCCUPATION'),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _occupation,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.work_outline),
          ),
          hint: const Text('Select occupation'),
          items: _occupations
              .map((o) => DropdownMenuItem(value: o, child: Text(o)))
              .toList(),
          onChanged: (v) => setState(() => _occupation = v),
        ),
        const SizedBox(height: 14),
        const _FieldLabel('WORK ADDRESS'),
        const SizedBox(height: 8),
        TextField(
          controller: _workAddressCtrl,
          maxLines: 2,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.location_on_outlined),
            hintText: 'Street, city, region',
          ),
        ),
        const SizedBox(height: 14),
        const _FieldLabel('SPECIFIC CLINIC LOCATION'),
        const SizedBox(height: 8),
        TextField(
          controller: _clinicLocationCtrl,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.maps_home_work_outlined),
            hintText: 'Building, ward, or site name',
          ),
        ),
      ],
      const SizedBox(height: 14),
      const _FieldLabel('VERIFICATION DOCUMENTS (OPTIONAL)'),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: _pickDocument,
        icon: const Icon(Icons.upload_file_outlined),
        label: const Text('Upload PDF or image'),
      ),
      if (_documentPaths.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _documentPaths
                .map(
                  (p) => Text(
                    '• ${p.split(RegExp(r'[\\\\/]+')).last}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      if (_formError != null) ...[
        const SizedBox(height: 10),
        Text(
          _formError!,
          style: const TextStyle(
            color: AppColors.danger,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
      const SizedBox(height: 14),
      FilledButton(
        onPressed: _submitting ? null : () => unawaited(_submitSignup()),
        child: _submitting
            ? SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Create account'),
                  SizedBox(width: 10),
                  Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
      ),
    ];
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: scheme.outline.withValues(alpha: 0.65)),
          ),
          child: const Icon(Icons.shield_outlined, color: AppColors.primary),
        ),
        const SizedBox(height: 10),
        Text(
          'Clinical Curator',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(
          'AI-ASSISTED ORAL SCREENING',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            letterSpacing: 1.4,
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.title,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : scheme.outline.withValues(alpha: 0.65),
            width: selected ? 1.6 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).shadowColor.withValues(alpha: 0.12),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: scheme.outline.withValues(alpha: 0.65),
                ),
              ),
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        letterSpacing: 1.3,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
