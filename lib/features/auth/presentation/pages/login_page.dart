import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/providers/current_user_provider.dart';
import '../../domain/entities/usuario.dart';
import '../../domain/usecases/login_usecase.dart';
import '../providers/auth_provider.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _userCtrl = TextEditingController(text: 'admin');       // pre-llenado para demo
  final _passCtrl = TextEditingController(text: 'admin123');
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final useCase = ref.read(loginUseCaseProvider);
    final result = await useCase(LoginParams(
      username: _userCtrl.text.trim(),
      password: _passCtrl.text,
    ));

    if (!mounted) return;
    setState(() => _loading = false);

    result.fold(
      (failure) => setState(() => _error = failure.message),
      (user) {
        ref.read(currentUserProvider.notifier).state = user;
        context.go(AppRoutes.ventas);
      },
    );
  }

  void _entrarDemo() {
    const usuarioDemo = Usuario(
      id: 'demo-user-id',
      username: 'demo',
      nombreCompleto: 'Usuario Demo (Administrador)',
      rol: RolUsuario.administrador,
      activo: true,
    );
    ref.read(currentUserProvider.notifier).state = usuarioDemo;
    context.go(AppRoutes.ventas);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Panel izquierdo decorativo
          Expanded(
            flex: 5,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primary, AppColors.primaryLight],
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.store, size: 80, color: Colors.white),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Gestión Bodega',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w300,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sistema integral de ventas e inventario',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Panel derecho - login
          Expanded(
            flex: 4,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Bienvenido',
                          style: context.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Ingresa tus credenciales para continuar',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 32),
                        TextFormField(
                          controller: _userCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Usuario',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (v) => Validators.required(v, fieldName: 'Usuario'),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passCtrl,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Contraseña',
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                          validator: (v) => Validators.required(v, fieldName: 'Contraseña'),
                          onFieldSubmitted: (_) => _login(),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline,
                                    color: AppColors.error, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: const TextStyle(color: AppColors.error, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: _loading ? null : _login,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: _loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2),
                                )
                              : const Text('Ingresar'),
                        ),
                        const SizedBox(height: 16),
                        const Row(children: [
                          Expanded(child: Divider()),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text('o', style: TextStyle(color: AppColors.textSecondary)),
                          ),
                          Expanded(child: Divider()),
                        ]),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _loading ? null : _entrarDemo,
                          icon: const Icon(Icons.play_circle_outline),
                          label: const Text('Entrar en modo Demo (sin backend)'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Modo Demo: navega la app sin conectar al backend',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
