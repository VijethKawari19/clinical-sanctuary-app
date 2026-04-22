import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'local_auth_repository.dart';

final localAuthRepositoryProvider = Provider<LocalAuthRepository>((ref) {
  return LocalAuthRepository();
});
