import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../shared/widgets/app_page_header.dart';

/// Pantalla de reportes.
///
/// Estado actual: el backend tiene endpoints stub /api/reportes/* que
/// retornan datos vacíos. Los reportes reales (ventas por turno y forma
/// de pago, stock con costo y precio, top productos, etc.) requieren
/// implementar las queries agregadas en el backend Y tener ventas reales
/// registradas.
///
/// Por eso esta pantalla muestra un estado vacío honesto en vez de
/// gráficos con datos demo que confundirían al usuario.
class ReportesPage extends StatelessWidget {
  const ReportesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          AppPageHeader(
            title: 'Reportes y Análisis',
            subtitle: 'Ventas por turno, stock, créditos y exportación',
            actions: [
              OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.calendar_today, size: 16),
                label: const Text('Últimos 7 días'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.picture_as_pdf, size: 16),
                label: const Text('PDF'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: null,
                icon: const Icon(Icons.download, size: 16),
                label: const Text('Excel'),
              ),
            ],
          ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(40),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.bar_chart,
                          size: 64,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'No hay datos para mostrar reportes',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Los reportes se generan automáticamente a partir de las ventas, '
                        'compras y movimientos de caja registrados en el sistema.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Lista de reportes que estarán disponibles
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Reportes disponibles al completar el sistema:',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(height: 16),
                            _ReporteFuturo(
                              icon: Icons.point_of_sale,
                              titulo: 'Ventas diarias por turno y forma de pago',
                              detalle:
                                  'Detalle por turno día/noche con desglose Efectivo, Yape, Plin, Niubiz, Crédito',
                            ),
                            _ReporteFuturo(
                              icon: Icons.inventory_2,
                              titulo: 'Stock con costo y precio de venta',
                              detalle:
                                  'Inventario completo con valoración y alertas de stock mínimo',
                            ),
                            _ReporteFuturo(
                              icon: Icons.trending_up,
                              titulo: 'Top productos más vendidos',
                              detalle:
                                  'Ranking por cantidad y por total facturado',
                            ),
                            _ReporteFuturo(
                              icon: Icons.warning_amber,
                              titulo: 'Mermas y productos vencidos',
                              detalle:
                                  'Registro de pérdidas por vencimiento o deterioro',
                            ),
                            _ReporteFuturo(
                              icon: Icons.credit_card,
                              titulo: 'Crédito y deuda de trabajadores',
                              detalle:
                                  'Consumos, vales y puntos por trabajador',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Aviso backend
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
                              child: Text(
                                'Los endpoints de reportes (queries agregadas) están en desarrollo. '
                                'Esta pantalla se llenará automáticamente cuando: '
                                '(1) se implementen los endpoints, y '
                                '(2) haya ventas reales registradas en el sistema.',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 12,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
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

class _ReporteFuturo extends StatelessWidget {
  const _ReporteFuturo({
    required this.icon,
    required this.titulo,
    required this.detalle,
  });

  final IconData icon;
  final String titulo;
  final String detalle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    fontSize: 13,
                  ),
                ),
                Text(
                  detalle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
