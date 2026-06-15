import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../shared/widgets/app_async_value.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_page_header.dart';
import '../../data/models/caja_models.dart';
import '../providers/cajas_provider.dart';

class CajasPage extends ConsumerWidget {
  const CajasPage({super.key});

  String get _turnoActual =>
      AppDateUtils.isTurnoDia(DateTime.now()) ? 'DIA' : 'NOCHE';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cajaAsync = ref.watch(cajaAbiertaProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          AppPageHeader(
            title: 'Cajas y Turnos',
            subtitle: cajaAsync.maybeWhen(
              data: (c) => c != null
                  ? 'Turno ${c.caja.turno.name.toUpperCase()} activo desde '
                      '${AppDateUtils.formatTime(c.caja.fechaApertura)}'
                  : 'No hay caja abierta',
              orElse: () => 'Apertura, cierre y cuadre por turno',
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, color: AppColors.primary),
                onPressed: () => ref.invalidate(cajaAbiertaProvider),
              ),
              const SizedBox(width: 8),
              cajaAsync.maybeWhen(
                data: (c) => c == null
                    ? FilledButton.icon(
                        onPressed: () => _abrirCajaDialog(context, ref),
                        icon: const Icon(Icons.lock_open),
                        label: const Text('Abrir caja'),
                      )
                    : Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _avanceDialog(context, ref, c),
                            icon: const Icon(Icons.payments),
                            label: const Text('Registrar avance'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: () => _cerrarCajaDialog(context, ref, c),
                            icon: const Icon(Icons.lock),
                            label: const Text('Cerrar caja'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.error,
                            ),
                          ),
                        ],
                      ),
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
          Expanded(
            child: AppAsyncView<CajaDetalleDto?>(
              value: cajaAsync,
              onRetry: () => ref.invalidate(cajaAbiertaProvider),
              dataBuilder: (detalle) {
                if (detalle == null) {
                  return _SinCajaAbierta(
                    turno: _turnoActual,
                    onAbrir: () => _abrirCajaDialog(context, ref),
                  );
                }
                return _CajaAbiertaView(detalle: detalle);
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _abrirCajaDialog(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _AbrirCajaDialog(turnoSugerido: _turnoActual),
    );
    if (ok == true && context.mounted) {
      context.showSnack('Caja abierta correctamente');
    }
  }

  Future<void> _cerrarCajaDialog(
      BuildContext context, WidgetRef ref, CajaDetalleDto detalle) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _CerrarCajaDialog(detalle: detalle),
    );
    if (ok == true && context.mounted) {
      context.showSnack('Caja cerrada correctamente');
    }
  }

  Future<void> _avanceDialog(
      BuildContext context, WidgetRef ref, CajaDetalleDto detalle) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _AvanceDialog(cajaId: detalle.caja.id),
    );
    if (ok == true && context.mounted) {
      context.showSnack('Avance registrado');
    }
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//  ESTADO: SIN CAJA ABIERTA
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _SinCajaAbierta extends StatelessWidget {
  const _SinCajaAbierta({required this.turno, required this.onAbrir});
  final String turno;
  final VoidCallback onAbrir;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock, size: 56, color: AppColors.warning),
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
            Text(
              'Para empezar a registrar ventas, abra la caja del turno actual ($turno).',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAbrir,
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
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//  ESTADO: CAJA ABIERTA - DASHBOARD COMPLETO
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _CajaAbiertaView extends StatelessWidget {
  const _CajaAbiertaView({required this.detalle});
  final CajaDetalleDto detalle;

  @override
  Widget build(BuildContext context) {
    final c = detalle.caja;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header gradient
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
                    c.turno == TipoTurno.dia ? Icons.wb_sunny : Icons.nights_stay,
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
                        'Turno ${c.turno.name.toUpperCase()}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Vendedor: ${c.usuarioNombre}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                      Text(
                        'Abierta a las ${AppDateUtils.formatDateTime(c.fechaApertura)}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Total ventas',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    Text(
                      CurrencyFormatter.format(detalle.totalVentas),
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

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _VentasPorFormaPagoCard(detalle: detalle)),
              const SizedBox(width: 16),
              Expanded(child: _CuadreEfectivoCard(detalle: detalle)),
            ],
          ),
          const SizedBox(height: 16),
          _AvancesCard(detalle: detalle),
        ],
      ),
    );
  }
}

class _VentasPorFormaPagoCard extends StatelessWidget {
  const _VentasPorFormaPagoCard({required this.detalle});
  final CajaDetalleDto detalle;

  static const _orden = ['EFECTIVO', 'YAPE', 'PLIN', 'NIUBIZ', 'CREDITO'];
  static const _colores = {
    'EFECTIVO': AppColors.secondary,
    'YAPE': Color(0xFF722F8E),
    'PLIN': Color(0xFF00A19A),
    'NIUBIZ': Color(0xFFFF6F00),
    'CREDITO': AppColors.warning,
  };
  static const _labels = {
    'EFECTIVO': 'Efectivo',
    'YAPE': 'Yape',
    'PLIN': 'Plin',
    'NIUBIZ': 'Niubiz',
    'CREDITO': 'Crédito',
  };

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ventas por forma de pago',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          for (final k in _orden)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _colores[k]!,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _labels[k]!,
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                  ),
                  Text(
                    CurrencyFormatter.format(
                      detalle.ventasPorFormaPago[k] ?? 0,
                    ),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TOTAL',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                CurrencyFormatter.format(detalle.totalVentas),
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
    );
  }
}

class _CuadreEfectivoCard extends StatelessWidget {
  const _CuadreEfectivoCard({required this.detalle});
  final CajaDetalleDto detalle;

  @override
  Widget build(BuildContext context) {
    final ventasEfectivo = detalle.ventasPorFormaPago['EFECTIVO'] ?? 0;
    return AppCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cuadre de efectivo',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _linea(
            'Monto apertura',
            detalle.caja.montoApertura,
            AppColors.textPrimary,
          ),
          _linea(
            '+ Ventas en efectivo',
            ventasEfectivo,
            AppColors.secondary,
          ),
          _linea(
            '- Avances de efectivo',
            detalle.totalAvances,
            AppColors.error,
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'EFECTIVO ESPERADO EN CAJA',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    fontSize: 13,
                  ),
                ),
              ),
              Text(
                CurrencyFormatter.format(detalle.efectivoEsperadoEnCaja),
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
    );
  }

  Widget _linea(String label, double monto, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textPrimary),
            ),
          ),
          Text(
            CurrencyFormatter.format(monto),
            style: TextStyle(fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

class _AvancesCard extends StatelessWidget {
  const _AvancesCard({required this.detalle});
  final CajaDetalleDto detalle;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Avances de efectivo del turno',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '${detalle.avances.length} registros',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (detalle.avances.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: Text(
                  'Sin avances registrados',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            ...detalle.avances.map(
              (a) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.payments, color: AppColors.warning),
                title: Text(
                  a.observacion ?? 'Avance',
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
                subtitle: Text(
                  AppDateUtils.formatDateTime(a.fecha),
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                trailing: Text(
                  CurrencyFormatter.format(a.monto),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.warning,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//  DIALOGS
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _AbrirCajaDialog extends ConsumerStatefulWidget {
  const _AbrirCajaDialog({required this.turnoSugerido});
  final String turnoSugerido;

  @override
  ConsumerState<_AbrirCajaDialog> createState() => _AbrirCajaDialogState();
}

class _AbrirCajaDialogState extends ConsumerState<_AbrirCajaDialog> {
  final _formKey = GlobalKey<FormState>();
  final _monto = TextEditingController(text: '0');
  final _contometro = TextEditingController();
  late String _turno = widget.turnoSugerido;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _monto.dispose();
    _contometro.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(cajasControllerProvider).abrir(
            turno: _turno,
            montoApertura: double.parse(_monto.text),
            contometroInicio: _contometro.text.isEmpty
                ? null
                : int.tryParse(_contometro.text),
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Abrir caja',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: ['DIA', 'NOCHE'].map((t) {
                  final activo = t == _turno;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: OutlinedButton.icon(
                        onPressed: () => setState(() => _turno = t),
                        icon: Icon(
                          t == 'DIA' ? Icons.wb_sunny : Icons.nights_stay,
                          size: 18,
                        ),
                        label: Text('Turno $t'),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: activo ? AppColors.primary : null,
                          foregroundColor:
                              activo ? Colors.white : AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _monto,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                decoration: const InputDecoration(
                  labelText: 'Monto de apertura',
                  prefixText: 'S/. ',
                ),
                validator: (v) {
                  final d = double.tryParse(v ?? '');
                  if (d == null || d < 0) return 'Ingrese un monto valido';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contometro,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Contómetro fotocopiadora (opcional)',
                  hintText: 'Lectura inicial del turno',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(color: AppColors.error, fontSize: 12),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        _loading ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _loading ? null : _confirmar,
                    child: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Abrir'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CerrarCajaDialog extends ConsumerStatefulWidget {
  const _CerrarCajaDialog({required this.detalle});
  final CajaDetalleDto detalle;

  @override
  ConsumerState<_CerrarCajaDialog> createState() => _CerrarCajaDialogState();
}

class _CerrarCajaDialogState extends ConsumerState<_CerrarCajaDialog> {
  late final TextEditingController _monto = TextEditingController(
    text: widget.detalle.efectivoEsperadoEnCaja.toStringAsFixed(2),
  );
  final _contometro = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _monto.dispose();
    _contometro.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    final monto = double.tryParse(_monto.text);
    if (monto == null || monto < 0) {
      setState(() => _error = 'Monto invalido');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(cajasControllerProvider).cerrar(
            cajaId: widget.detalle.caja.id,
            montoCierre: monto,
            contometroFin: _contometro.text.isEmpty
                ? null
                : int.tryParse(_contometro.text),
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final esperado = widget.detalle.efectivoEsperadoEnCaja;
    final ingresado = double.tryParse(_monto.text) ?? 0;
    final diferencia = ingresado - esperado;

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Cerrar caja',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total ventas',
                          style: TextStyle(color: AppColors.textSecondary)),
                      Text(
                        CurrencyFormatter.format(widget.detalle.totalVentas),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Efectivo esperado',
                          style: TextStyle(color: AppColors.textSecondary)),
                      Text(
                        CurrencyFormatter.format(esperado),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.secondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _monto,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              onChanged: (_) => setState(() {}),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              decoration: const InputDecoration(
                labelText: 'Monto real en caja',
                prefixText: 'S/. ',
              ),
            ),
            if (diferencia.abs() > 0.01) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (diferencia >= 0
                          ? AppColors.secondary
                          : AppColors.error)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  diferencia >= 0
                      ? 'Sobrante: ${CurrencyFormatter.format(diferencia)}'
                      : 'Faltante: ${CurrencyFormatter.format(diferencia.abs())}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: diferencia >= 0
                        ? AppColors.secondary
                        : AppColors.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _contometro,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Contómetro fotocopiadora (opcional)',
                hintText: 'Lectura final del turno',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.error, fontSize: 12),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed:
                      _loading ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _loading ? null : _confirmar,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.error,
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Cerrar caja'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AvanceDialog extends ConsumerStatefulWidget {
  const _AvanceDialog({required this.cajaId});
  final String cajaId;

  @override
  ConsumerState<_AvanceDialog> createState() => _AvanceDialogState();
}

class _AvanceDialogState extends ConsumerState<_AvanceDialog> {
  final _monto = TextEditingController();
  final _obs = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _monto.dispose();
    _obs.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    final monto = double.tryParse(_monto.text);
    if (monto == null || monto <= 0) {
      setState(() => _error = 'Ingrese un monto valido');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(cajasControllerProvider).registrarAvance(
            cajaId: widget.cajaId,
            monto: monto,
            observacion: _obs.text.trim().isEmpty ? null : _obs.text.trim(),
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Registrar avance de efectivo',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _monto,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              autofocus: true,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Monto (S/.)',
                prefixText: 'S/. ',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _obs,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Observación',
                hintText: 'Ej: Cambio para vendedor',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.error, fontSize: 12),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed:
                      _loading ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _loading ? null : _confirmar,
                  child: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Registrar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
