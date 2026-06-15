import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../shared/widgets/app_page_header.dart';

/// Pantalla de gestion de cajas y turnos.
///
/// Estado actual: el backend tiene solo el endpoint GET /api/cajas que lista
/// cajas. Faltan los endpoints de:
///   - POST /api/cajas/abrir (apertura)
///   - POST /api/cajas/{id}/cerrar (cierre)
///   - POST /api/cajas/{id}/avance (registrar avance de efectivo)
///   - GET /api/cajas/abierta (caja abierta del usuario actual)
///
/// Por eso la UI muestra el estado vacio honesto y bloquea las acciones
/// hasta que esos endpoints existan. Esto evita mostrar datos falsos al
/// usuario.
class CajasPage extends StatelessWidget {
  const CajasPage({super.key});

  String get _turnoActual =>
      AppDateUtils.isTurnoDia(DateTime.now()) ? 'DÍA' : 'NOCHE';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          AppPageHeader(
            title: 'Cajas y Turnos',
            subtitle:
                'Apertura, cierre y cuadre de caja por turno (día/noche)',
            actions: [
              FilledButton.icon(
                onPressed: () => _avisoBackendPendiente(context, 'abrir caja'),
                icon: const Icon(Icons.lock_open),
                label: const Text('Abrir caja'),
              ),
            ],
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Indicador del turno actual segun la hora del sistema
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            _turnoActual == 'DÍA'
                                ? Icons.wb_sunny
                                : Icons.nights_stay,
                            color: AppColors.primary,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Turno actual: $_turnoActual',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Horario día: 07:30 a 19:30   ·   Horario noche: 19:30 a 07:30',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Estado vacío honesto: NO hay caja abierta
                  Container(
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.lock,
                            size: 56,
                            color: AppColors.warning,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No hay caja abierta',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Para empezar a registrar ventas, abra la caja del turno actual.\n'
                          'Solo puede haber una caja abierta por vendedor a la vez.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: () =>
                              _avisoBackendPendiente(context, 'abrir caja'),
                          icon: const Icon(Icons.lock_open),
                          label: const Text('Abrir caja del turno'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Aviso backend pendiente
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.info.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: AppColors.info),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Funcionalidad en desarrollo',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                  fontSize: 13,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'El módulo de Cajas necesita endpoints adicionales en el backend '
                                '(apertura, cierre, avances, cuadre). Una vez implementados, '
                                'esta pantalla mostrará la caja real del vendedor en sesión.',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 12,
                                  height: 1.5,
                                ),
                              ),
                            ],
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
    );
  }

  void _avisoBackendPendiente(BuildContext context, String accion) {
    context.showSnack(
      'Pendiente: el endpoint para "$accion" aún no está implementado en el backend',
    );
  }
}
