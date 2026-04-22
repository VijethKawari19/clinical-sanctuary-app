/// Password policy: 8+ chars, upper, lower, digit, special.
List<String> passwordRuleFailures(String password) {
  final failures = <String>[];
  if (password.length < 8) {
    failures.add('At least 8 characters');
  }
  if (!password.contains(RegExp(r'[A-Z]'))) {
    failures.add('One uppercase letter');
  }
  if (!password.contains(RegExp(r'[a-z]'))) {
    failures.add('One lowercase letter');
  }
  if (!password.contains(RegExp(r'[0-9]'))) {
    failures.add('One number');
  }
  if (!password.contains(RegExp(r'[!@#$%^&*()_+\-=\[\]{};\\|,.<>/?~`]'))) {
    failures.add('One special character');
  }
  return failures;
}

bool isPasswordCompliant(String password) =>
    passwordRuleFailures(password).isEmpty;

bool isValidEmail(String email) {
  final v = email.trim();
  if (v.isEmpty) return false;
  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v);
}
