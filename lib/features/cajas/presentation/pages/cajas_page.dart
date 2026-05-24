import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/services/report_export_service.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_page_header.dart';

class CajasPage extends StatefulWidget {
  const CajasPage({super.key});

  @override
  State<CajasPage> createState() => _CajasPageState();
}

class _CajasPageState extends State<CajasPage> {
  bool _cajaAbierta = true;
  final _vendedor = 'Vendedor de Prueba';
  final DateTime _aperturaHora = DateTime.now().subtract(const Duration(hours: 5, minutes: 23));
  final double _montoApertura = 100;
  final int _contometroInicial = 12345;
  final double _ventasEfectivo = 287.50;
  final double _ventasYape = 156.00;
  final double _ventasPlin = 95.00;
  final double _ventasNiubiz = 0;
  final double _ventasCredito = 42.00;
  final _avances = <_AvanceDemo>[
    _AvanceDemo(120, 'Cambio para vendedor', DateTime.now().subtract(const Duration(hours: 2))),
    _AvanceDemo(80, 'Cambio adicional turno', DateTime.now().subtract(const Duration(hours: 4))),
  ];

  double get _totalVentas =>
      _ventasEfectivo + _ventasYape + _ventasPlin + _ventasNiubiz + _ventasCredito;
  double get _totalAvances => _avances.fold(0, (s, a) => s + a.monto);
  double get _efectivoEsperado => _montoApertura + _ventasEfectivo - _totalAvances;

  String get _turnoActual => AppDateUtils.isTurnoDia(DateTime.now()) ? 'DÍA' : 'NOCHE';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          AppPageHeader(
            title: 'Cajas y Turnos',
            subtitle: _cajaAbierta
                ? 'Turno $_turnoActual activo desde ${AppDateUtils.formatTime(_aperturaHora)}'
                : 'No hay caja abierta',
            actions: [
              if (_cajaAbierta) ...[
                IconButton(
                  onPressed: _imprimirCuadre,
                  icon: const Icon(Icons.print, color: AppColors.primary),
                  tooltip: 'Imprimir cuadre actual',
                ),
                const SizedBox(width: 4),
                OutlinedButton.icon(
                  onPressed: _exportarCuadrePdf,
                  icon: const Icon(Icons.picture_as_pdf, size: 16),
                  label: const Text('PDF'),
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _registrarAvance,
                  icon: const Icon(Icons.payments),
                  label: const Text('Registrar avance'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _cerrarCaja,
                  icon: const Icon(Icons.lock),
                  label: const Text('Cerrar caja'),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                ),
              ] else
                FilledButton.icon(
                  onPressed: _abrirCaja,
                  icon: const Icon(Icons.lock_open),
                  label: const Text('Abrir caja'),
                ),
            ],
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _cajaAbierta ? _buildCajaAbierta() : _buildCajaCerrada(),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Estados ───────────────────────────

  Widget _buildCajaAbierta() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header card destacado
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.primaryLight],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _turnoActual == 'DÍA' ? Icons.wb_sunny : Icons.nights_stay,
                  color: Colors.white,
                  size: 36,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Turno $_turnoActual',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Vendedor: $_vendedor',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
                    ),
                    Text(
                      'Abierta a las ${AppDateUtils.formatDateTime(_aperturaHora)}',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Total ventas',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                  Text(
                    CurrencyFormatter.format(_totalVentas),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Cuadro de ventas por forma de pago
        Row(
          children: [
            Expanded(
              child: AppCard(
                margin: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionTitle('💰 Ventas por forma de pago'),
                    const SizedBox(height: 12),
                    _LineaPago('Efectivo', _ventasEfectivo, AppColors.secondary),
                    _LineaPago('Yape', _ventasYape, const Color(0xFF722F8E)),
                    _LineaPago('Plin', _ventasPlin, const Color(0xFF00A19A)),
                    _LineaPago('Niubiz', _ventasNiubiz, const Color(0xFFFF6F00)),
                    _LineaPago('Crédito', _ventasCredito, AppColors.warning),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('TOTAL',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            )),
                        Text(
                          CurrencyFormatter.format(_totalVentas),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: AppCard(
                margin: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionTitle('💵 Cuadre de efectivo'),
                    const SizedBox(height: 12),
                    _LineaDato('Monto apertura', _montoApertura, AppColors.textPrimary),
                    _LineaDato('+ Ventas en efectivo', _ventasEfectivo, AppColors.secondary),
                    _LineaDato('- Avances de efectivo', _totalAvances, AppColors.error),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('EFECTIVO ESPERADO EN CAJA',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              fontSize: 13,
                            )),
                        Text(
                          CurrencyFormatter.format(_efectivoEsperado),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.secondary,
                            fontSize: 18,
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
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: AppCard(
                margin: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionTitle('📋 Avances de efectivo del turno'),
                    const SizedBox(height: 8),
                    if (_avances.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                            child: Text('Sin avances registrados',
                                style: TextStyle(color: AppColors.textSecondary))),
                      )
                    else
                      ..._avances.map((a) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.payments, color: AppColors.warning),
                            title: Text(a.observacion,
                                style: const TextStyle(color: AppColors.textPrimary)),
                            subtitle: Text(AppDateUtils.formatDateTime(a.fecha),
                                style: const TextStyle(color: AppColors.textSecondary)),
                            trailing: Text(
                              CurrencyFormatter.format(a.monto),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.warning,
                                fontSize: 16,
                              ),
                            ),
                          )),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: AppCard(
                margin: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionTitle('🖨️ Contómetro fotocopiadora'),
                    const SizedBox(height: 16),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          children: [
                            const Text('Lectura inicial del turno',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                )),
                            const SizedBox(height: 4),
                            Text(
                              '$_contometroInicial',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Center(
                      child: Text(
                        'La lectura final se ingresa al cerrar el turno',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCajaCerrada() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock, size: 64, color: AppColors.warning),
            ),
            const SizedBox(height: 20),
            const Text(
              'No hay caja abierta',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Para empezar a registrar ventas, abre la caja del turno actual.',
              style: TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _abrirCaja,
              icon: const Icon(Icons.lock_open),
              label: const Text('Abrir caja ahora'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Acciones ───────────────────────────

  void _abrirCaja() {
    setState(() => _cajaAbierta = true);
    context.showSnack('Caja abierta — Turno $_turnoActual');
  }

  void _cerrarCaja() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        icon: const Icon(Icons.warning_amber, color: AppColors.warning, size: 48),
        title: const Text('Cerrar caja'),
        content: Text(
          'Total ventas del turno: ${CurrencyFormatter.format(_totalVentas)}\n'
          'Efectivo esperado en caja: ${CurrencyFormatter.format(_efectivoEsperado)}\n\n'
          '¿Confirmas el cierre del turno?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Cerrar caja'),
          ),
        ],
      ),
    );
    if (confirmar == true) {
      setState(() => _cajaAbierta = false);
      if (mounted) context.showSnack('Caja cerrada correctamente');
    }
  }

  /// Genera y abre el PDF del cuadre de caja del turno actual.
  Future<void> _exportarCuadrePdf() async {
    try {
      await ReportExportService.instance.exportarTablaPdf(
        titulo: 'Cuadre de Caja - Turno $_turnoActual',
        subtitulo: 'Vendedor: $_vendedor\nApertura: ${AppDateUtils.formatDateTime(_aperturaHora)}',
        columnas: const ['Concepto', 'Monto (S/.)'],
        filas: [
          ['Monto apertura', ReportExportService.formatMoneda(_montoApertura)],
          ['Ventas en efectivo', ReportExportService.formatMoneda(_ventasEfectivo)],
          ['Ventas Yape', ReportExportService.formatMoneda(_ventasYape)],
          ['Ventas Plin', ReportExportService.formatMoneda(_ventasPlin)],
          ['Ventas Niubiz', ReportExportService.formatMoneda(_ventasNiubiz)],
          ['Ventas a crédito', ReportExportService.formatMoneda(_ventasCredito)],
          ['Avances de efectivo', '- ${ReportExportService.formatMoneda(_totalAvances)}'],
        ],
        totales: [
          MapEntry('Total ventas del turno', ReportExportService.formatMoneda(_totalVentas)),
          MapEntry('EFECTIVO ESPERADO EN CAJA',
              ReportExportService.formatMoneda(_efectivoEsperado)),
        ],
        nombreArchivo: 'cuadre_caja_turno_${_turnoActual.toLowerCase()}',
      );
      if (mounted) context.showSnack('PDF generado correctamente');
    } catch (e) {
      if (mounted) context.showSnack('Error: $e', isError: true);
    }
  }

  /// Imprime directamente sin guardar.
  Future<void> _imprimirCuadre() async {
    try {
      await ReportExportService.instance.imprimirPdf(
        titulo: 'Cuadre de Caja - Turno $_turnoActual',
        subtitulo: 'Vendedor: $_vendedor',
        columnas: const ['Concepto', 'Monto (S/.)'],
        filas: [
          ['Monto apertura', ReportExportService.formatMoneda(_montoApertura)],
          ['Ventas en efectivo', ReportExportService.formatMoneda(_ventasEfectivo)],
          ['Ventas Yape', ReportExportService.formatMoneda(_ventasYape)],
          ['Ventas Plin', ReportExportService.formatMoneda(_ventasPlin)],
          ['Ventas Niubiz', ReportExportService.formatMoneda(_ventasNiubiz)],
          ['Ventas a crédito', ReportExportService.formatMoneda(_ventasCredito)],
          ['Avances de efectivo', '- ${ReportExportService.formatMoneda(_totalAvances)}'],
        ],
        totales: [
          MapEntry('Total ventas del turno', ReportExportService.formatMoneda(_totalVentas)),
          MapEntry('EFECTIVO ESPERADO EN CAJA',
              ReportExportService.formatMoneda(_efectivoEsperado)),
        ],
      );
    } catch (e) {
      if (mounted) context.showSnack('Error al imprimir: $e', isError: true);
    }
  }

  void _registrarAvance() async {
    final ctrl = TextEditingController();
    final obsCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Registrar avance de efectivo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Monto (S/.)',
                prefixText: 'S/. ',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: obsCtrl,
              decoration: const InputDecoration(
                labelText: 'Observación',
                hintText: 'Ej: Cambio para vendedor',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              child: const Text('Registrar')),
        ],
      ),
    );
    if (ok == true && ctrl.text.isNotEmpty) {
      setState(() {
        _avances.add(_AvanceDemo(
          double.tryParse(ctrl.text) ?? 0,
          obsCtrl.text.isEmpty ? 'Avance' : obsCtrl.text,
          DateTime.now(),
        ));
      });
    }
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      );
}

class _LineaPago extends StatelessWidget {
  const _LineaPago(this.label, this.monto, this.color);
  final String label;
  final double monto;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label, style: const TextStyle(color: AppColors.textPrimary)),
            ),
            Text(
              CurrencyFormatter.format(monto),
              style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
          ],
        ),
      );
}

class _LineaDato extends StatelessWidget {
  const _LineaDato(this.label, this.monto, this.color);
  final String label;
  final double monto;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(color: AppColors.textPrimary))),
            Text(
              CurrencyFormatter.format(monto),
              style: TextStyle(fontWeight: FontWeight.w600, color: color),
            ),
          ],
        ),
      );
}

class _AvanceDemo {
  _AvanceDemo(this.monto, this.observacion, this.fecha);
  final double monto;
  final String observacion;
  final DateTime fecha;
}
