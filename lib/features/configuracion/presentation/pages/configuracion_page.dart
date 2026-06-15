import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_endpoints.dart';
import '../../../../shared/widgets/app_async_value.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_page_header.dart';

final configuracionProvider = FutureProvider.autoDispose<Map<String, String>>(
  (ref) async {
    final json = await ApiClient.instance.getData<Map<String, dynamic>>(
      ApiEndpoints.configuracion,
    );
    return json.map((k, v) => MapEntry(k, v?.toString() ?? ''));
  },
);

class ConfiguracionPage extends ConsumerStatefulWidget {
  const ConfiguracionPage({super.key});

  @override
  ConsumerState<ConfiguracionPage> createState() => _ConfiguracionPageState();
}

class _ConfiguracionPageState extends ConsumerState<ConfiguracionPage> {
  final _controllers = <String, TextEditingController>{};
  bool _loading = false;
  String? _msg;

  TextEditingController _ctrl(String key, String initial) =>
      _controllers.putIfAbsent(key, () => TextEditingController(text: initial));

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    setState(() {
      _loading = true;
      _msg = null;
    });
    try {
      final payload = <String, String>{
        for (final e in _controllers.entries) e.key: e.value.text.trim(),
      };
      await ApiClient.instance.putData<Map<String, dynamic>>(
        ApiEndpoints.configuracion,
        body: payload,
      );
      ref.invalidate(configuracionProvider);
      setState(() => _msg = 'Configuración guardada');
    } catch (e) {
      setState(() => _msg = 'Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(configuracionProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          AppPageHeader(
            title: 'Configuración',
            subtitle: 'Datos del negocio, pagos digitales e impresora',
            actions: [
              FilledButton.icon(
                onPressed: _loading ? null : _guardar,
                icon: _loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save, size: 18),
                label: Text(_loading ? 'Guardando...' : 'Guardar cambios'),
              ),
            ],
          ),
          Expanded(
            child: AppAsyncView<Map<String, String>>(
              value: async,
              onRetry: () => ref.invalidate(configuracionProvider),
              dataBuilder: (cfg) => SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_msg != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _msg!,
                            style: const TextStyle(color: AppColors.textPrimary),
                          ),
                        ),
                      _Seccion(
                        titulo: 'Datos del negocio',
                        icon: Icons.business,
                        campos: [
                          _Campo('Razón Social', 'negocio.razon_social', cfg),
                          _Campo('RUC', 'negocio.ruc', cfg, keyboard: TextInputType.number),
                          _Campo('Dirección', 'negocio.direccion', cfg),
                          _Campo('Teléfono', 'negocio.telefono', cfg, keyboard: TextInputType.phone),
                        ],
                        ctrlBuilder: _ctrl,
                      ),
                      const SizedBox(height: 16),
                      _Seccion(
                        titulo: 'Pagos digitales',
                        icon: Icons.phone_android,
                        campos: [
                          _Campo('Número Yape', 'pagos.yape_numero', cfg, keyboard: TextInputType.phone),
                          _Campo('Número Plin', 'pagos.plin_numero', cfg, keyboard: TextInputType.phone),
                        ],
                        ctrlBuilder: _ctrl,
                      ),
                      const SizedBox(height: 16),
                      _Seccion(
                        titulo: 'Impresora térmica',
                        icon: Icons.print,
                        campos: [
                          _Campo('IP de impresora', 'impresora.ip', cfg, hint: 'Ej: 192.168.1.50'),
                          _Campo('Modo (red/usb)', 'impresora.modo', cfg, hint: 'red o usb'),
                        ],
                        ctrlBuilder: _ctrl,
                      ),
                    ],
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

class _Campo {
  _Campo(this.label, this.key, this.cfg, {this.keyboard, this.hint});
  final String label;
  final String key;
  final Map<String, String> cfg;
  final TextInputType? keyboard;
  final String? hint;
}

class _Seccion extends StatelessWidget {
  const _Seccion({
    required this.titulo,
    required this.icon,
    required this.campos,
    required this.ctrlBuilder,
  });

  final String titulo;
  final IconData icon;
  final List<_Campo> campos;
  final TextEditingController Function(String key, String initial) ctrlBuilder;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                titulo,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...campos.map((c) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                controller: ctrlBuilder(c.key, c.cfg[c.key] ?? ''),
                keyboardType: c.keyboard,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: c.label,
                  hintText: c.hint,
                  isDense: true,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
