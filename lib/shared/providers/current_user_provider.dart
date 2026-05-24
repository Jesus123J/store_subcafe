import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/domain/entities/usuario.dart';

/// Mantiene el usuario actualmente logueado. `null` = no hay sesión.
final currentUserProvider = StateProvider<Usuario?>((ref) => null);
