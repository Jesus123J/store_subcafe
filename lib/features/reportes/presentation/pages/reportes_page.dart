import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/services/report_export_service.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_page_header.dart';

class ReportesPage extends StatelessWidget {
  const ReportesPage({super.key});

  static const _topProductos = [
    _ProdReporte('Inca Kola 500ml', 42, 147.0),
    _ProdReporte('Galletas Soda Field', 38, 76.0),
    _ProdReporte('Pan Francés', 156, 46.8),
    _ProdReporte('Fotocopia A4', 220, 44.0),
    _ProdReporte('Chocolate Sublime', 22, 33.0),
  ];

  static const _stockBajo = [
    _StockBajoReporte('Galletas Soda Field', 8, 10),
    _StockBajoReporte('Chocolate Sublime', 3, 5),
    _StockBajoReporte('Atún Florida', 2, 6),
    _StockBajoReporte('Detergente Bolívar', 1, 4),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          AppPageHeader(
            title: 'Reportes y Análisis',
            subtitle: 'Visualización de ventas, stock y tendencias',
            actions: [
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.calendar_today, size: 16),
                label: const Text('Últimos 7 días'),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _imprimir(context),
                icon: const Icon(Icons.print, color: AppColors.primary),
                tooltip: 'Imprimir reporte',
              ),
              const SizedBox(width: 4),
              OutlinedButton.icon(
                onPressed: () => _exportarPdf(context),
                icon: const Icon(Icons.picture_as_pdf, size: 16),
                label: const Text('PDF'),
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => _exportarExcel(context),
                icon: const Icon(Icons.download, size: 16),
                label: const Text('Excel'),
                style: FilledButton.styleFrom(backgroundColor: AppColors.secondary),
              ),
            ],
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                          child: _MetricCard(
                              label: 'Ventas hoy',
                              value: CurrencyFormatter.format(580.50),
                              delta: '+12.4%',
                              positivo: true,
                              icon: Icons.point_of_sale,
                              color: AppColors.secondary)),
                      const SizedBox(width: 16),
                      Expanded(
                          child: _MetricCard(
                              label: 'Ventas del mes',
                              value: CurrencyFormatter.format(14820.30),
                              delta: '+8.1%',
                              positivo: true,
                              icon: Icons.calendar_month,
                              color: AppColors.primary)),
                      const SizedBox(width: 16),
                      Expanded(
                          child: _MetricCard(
                              label: 'Transacciones',
                              value: '127',
                              delta: '+5',
                              positivo: true,
                              icon: Icons.receipt,
                              color: AppColors.info)),
                      const SizedBox(width: 16),
                      Expanded(
                          child: _MetricCard(
                              label: 'Ticket promedio',
                              value: CurrencyFormatter.format(4.57),
                              delta: '-3.2%',
                              positivo: false,
                              icon: Icons.shopping_cart,
                              color: AppColors.warning)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: AppCard(
                          margin: EdgeInsets.zero,
                          child: SizedBox(
                            height: 320,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                _ChartTitle('📈 Ventas últimos 7 días'),
                                SizedBox(height: 16),
                                Expanded(child: _GraficoVentas()),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 1,
                        child: AppCard(
                          margin: EdgeInsets.zero,
                          child: SizedBox(
                            height: 320,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                _ChartTitle('💰 Por forma de pago'),
                                SizedBox(height: 16),
                                Expanded(child: _GraficoFormasPago()),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 1,
                        child: AppCard(
                          margin: EdgeInsets.zero,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _ChartTitle('🏆 Top productos vendidos'),
                              const SizedBox(height: 12),
                              ..._topProductos.asMap().entries.map((e) {
                                final i = e.key;
                                final p = e.value;
                                final medalla = [
                                  const Color(0xFFFFD700),
                                  const Color(0xFFC0C0C0),
                                  const Color(0xFFCD7F32),
                                ];
                                final bg = i < 3 ? medalla[i] : AppColors.background;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 26,
                                        height: 26,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: bg,
                                          borderRadius: BorderRadius.circular(13),
                                          border: Border.all(color: AppColors.border),
                                        ),
                                        child: Text(
                                          '${i + 1}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(p.nombre,
                                            style: const TextStyle(
                                                color: AppColors.textPrimary)),
                                      ),
                                      Text('${p.cantidad} und',
                                          style: const TextStyle(
                                              color: AppColors.textSecondary,
                                              fontSize: 12)),
                                      const SizedBox(width: 12),
                                      Text(CurrencyFormatter.format(p.total),
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.primary)),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 1,
                        child: AppCard(
                          margin: EdgeInsets.zero,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _ChartTitle('⚠️ Productos con stock bajo'),
                              const SizedBox(height: 12),
                              ..._stockBajo.map((p) => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 6),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.warning_amber,
                                            color: AppColors.warning, size: 18),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(p.nombre,
                                              style: const TextStyle(
                                                  color: AppColors.textPrimary)),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 3),
                                          decoration: BoxDecoration(
                                            color:
                                                AppColors.error.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            '${p.stock} / mín ${p.minimo}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.error,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Exportación ───────────────────────

  Future<void> _exportarPdf(BuildContext context) async {
    try {
      await ReportExportService.instance.exportarTablaPdf(
        titulo: 'Reporte de Ventas — Últimos 7 días',
        subtitulo: 'Detalle de ventas, top productos y stock crítico',
        columnas: const ['Posición', 'Producto', 'Cantidad', 'Total (S/.)'],
        filas: _topProductos
            .asMap()
            .entries
            .map((e) => [
                  '${e.key + 1}',
                  e.value.nombre,
                  '${e.value.cantidad} und',
                  ReportExportService.formatMoneda(e.value.total),
                ])
            .toList(),
        totales: [
          MapEntry('Ventas hoy', ReportExportService.formatMoneda(580.50)),
          MapEntry('Ventas del mes', ReportExportService.formatMoneda(14820.30)),
          MapEntry('Transacciones', '127'),
          MapEntry('Ticket promedio', ReportExportService.formatMoneda(4.57)),
          MapEntry('TOTAL VENTAS DEL MES', ReportExportService.formatMoneda(14820.30)),
        ],
        nombreArchivo: 'reporte_ventas',
      );
      if (context.mounted) context.showSnack('PDF generado correctamente');
    } catch (e) {
      if (context.mounted) context.showSnack('Error: $e', isError: true);
    }
  }

  Future<void> _imprimir(BuildContext context) async {
    try {
      await ReportExportService.instance.imprimirPdf(
        titulo: 'Reporte de Ventas — Últimos 7 días',
        columnas: const ['Posición', 'Producto', 'Cantidad', 'Total (S/.)'],
        filas: _topProductos
            .asMap()
            .entries
            .map((e) => [
                  '${e.key + 1}',
                  e.value.nombre,
                  '${e.value.cantidad} und',
                  ReportExportService.formatMoneda(e.value.total),
                ])
            .toList(),
      );
    } catch (e) {
      if (context.mounted) context.showSnack('Error al imprimir: $e', isError: true);
    }
  }

  Future<void> _exportarExcel(BuildContext context) async {
    try {
      await ReportExportService.instance.exportarTablaExcel(
        titulo: 'Reporte de Ventas',
        columnas: const ['Posición', 'Producto', 'Cantidad', 'Total (S/.)'],
        filas: _topProductos
            .asMap()
            .entries
            .map((e) => [
                  '${e.key + 1}',
                  e.value.nombre,
                  '${e.value.cantidad} und',
                  ReportExportService.formatMoneda(e.value.total),
                ])
            .toList(),
        totales: [
          MapEntry('Ventas hoy', ReportExportService.formatMoneda(580.50)),
          MapEntry('Ventas del mes', ReportExportService.formatMoneda(14820.30)),
          MapEntry('Transacciones', '127'),
          MapEntry('Ticket promedio', ReportExportService.formatMoneda(4.57)),
          MapEntry('TOTAL VENTAS', ReportExportService.formatMoneda(14820.30)),
        ],
        nombreArchivo: 'reporte_ventas',
      );
      if (context.mounted) context.showSnack('Excel generado correctamente');
    } catch (e) {
      if (context.mounted) context.showSnack('Error: $e', isError: true);
    }
  }
}

class _GraficoVentas extends StatelessWidget {
  const _GraficoVentas();
  static const _dias = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
  static const _ventas = [320.0, 410.0, 380.0, 470.0, 590.0, 720.0, 580.5];

  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        gridData: const FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 200,
        ),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              interval: 200,
              getTitlesWidget: (v, _) => Text(
                'S/. ${v.toInt()}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: 1,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= _dias.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(_dias[i],
                      style: const TextStyle(
                          color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: _ventas
                .asMap()
                .entries
                .map((e) => FlSpot(e.key.toDouble(), e.value))
                .toList(),
            isCurved: true,
            color: AppColors.primary,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.primary.withValues(alpha: 0.15),
            ),
          ),
        ],
      ),
    );
  }
}

class _GraficoFormasPago extends StatelessWidget {
  const _GraficoFormasPago();
  static const _datos = [
    (label: 'Efectivo', valor: 45.0, color: AppColors.secondary),
    (label: 'Yape', valor: 25.0, color: Color(0xFF722F8E)),
    (label: 'Plin', valor: 18.0, color: Color(0xFF00A19A)),
    (label: 'Niubiz', valor: 8.0, color: Color(0xFFFF6F00)),
    (label: 'Crédito', valor: 4.0, color: AppColors.warning),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: _datos.map((d) {
                return PieChartSectionData(
                  value: d.valor,
                  color: d.color,
                  title: '${d.valor.toInt()}%',
                  titleStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  radius: 60,
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: _datos
              .map((d) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                          width: 10,
                          height: 10,
                          decoration:
                              BoxDecoration(color: d.color, shape: BoxShape.circle)),
                      const SizedBox(width: 4),
                      Text(d.label,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textPrimary)),
                    ],
                  ))
              .toList(),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.delta,
    required this.positivo,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final String delta;
  final bool positivo;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: (positivo ? AppColors.secondary : AppColors.error)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      positivo ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 10,
                      color: positivo ? AppColors.secondary : AppColors.error,
                    ),
                    const SizedBox(width: 2),
                    Text(delta,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: positivo ? AppColors.secondary : AppColors.error,
                        )),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              )),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _ChartTitle extends StatelessWidget {
  const _ChartTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      );
}

class _ProdReporte {
  const _ProdReporte(this.nombre, this.cantidad, this.total);
  final String nombre;
  final int cantidad;
  final double total;
}

class _StockBajoReporte {
  const _StockBajoReporte(this.nombre, this.stock, this.minimo);
  final String nombre;
  final int stock;
  final int minimo;
}
