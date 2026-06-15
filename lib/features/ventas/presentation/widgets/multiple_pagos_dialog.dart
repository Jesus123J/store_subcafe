import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';

/// Forma de pago aceptada en el POS.
enum FormaPago {
  efectivo('Efectivo', Icons.payments, AppColors.secondary),
  yape('Yape', Icons.phone_android, Color(0xFF722F8E)),
  plin('Plin', Icons.phone_android, Color(0xFF00A19A)),
  niubiz('Niubiz', Icons.credit_card, Color(0xFFFF6F00)),
  credito('Crédito a trabajador', Icons.account_circle, AppColors.warning);

  const FormaPago(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;

  bool get requiereCodigo => this == FormaPago.yape || this == FormaPago.plin;
}

/// Un pago parcial: forma de pago + monto + (opcional) código de operación.
class PagoParcial {
  PagoParcial({
    required this.formaPago,
    required this.monto,
    this.codigoOperacion,
  });

  final FormaPago formaPago;
  final double monto;
  final String? codigoOperacion;
}

/// Diálogo que permite al vendedor distribuir el total entre N formas de pago.
/// La suma debe ser EXACTAMENTE igual al total.
class MultiplePagosDialog extends StatefulWidget {
  const MultiplePagosDialog({required this.total, super.key});

  final double total;

  @override
  State<MultiplePagosDialog> createState() => _MultiplePagosDialogState();
}

class _MultiplePagosDialogState extends State<MultiplePagosDialog> {
  final _pagos = <PagoParcial>[];

  double get _totalPagado => _pagos.fold(0, (s, p) => s + p.monto);
  double get _faltaCobrar => widget.total - _totalPagado;
  bool get _completo => _faltaCobrar.abs() < 0.01;
  bool get _excede => _totalPagado > widget.total + 0.01;

  Future<void> _agregarPago() async {
    final pago = await showDialog<PagoParcial>(
      context: context,
      builder: (_) => _AgregarPagoSheet(montoSugerido: _faltaCobrar),
    );
    if (pago != null) {
      setState(() => _pagos.add(pago));
    }
  }

  void _quitar(int i) => setState(() => _pagos.removeAt(i));

  void _confirmar() {
    if (!_completo) return;
    Navigator.of(context).pop(List.of(_pagos));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.payments, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text(
                  'Distribuir el pago',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Total: ${CurrencyFormatter.format(widget.total)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Puede combinar varias formas de pago en una sola venta',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 20),

            // Resumen actual
            _ResumenPanel(
              total: widget.total,
              pagado: _totalPagado,
              falta: _faltaCobrar,
              excede: _excede,
              completo: _completo,
            ),
            const SizedBox(height: 16),

            // Lista de pagos agregados
            if (_pagos.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border, style: BorderStyle.solid),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.add_card, color: AppColors.textSecondary, size: 36),
                    SizedBox(height: 8),
                    Text(
                      'Aún no hay pagos agregados.\nUse el botón de abajo para agregar el primero.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: _pagos.asMap().entries.map((e) {
                  final i = e.key;
                  final p = e.value;
                  return _PagoTile(
                    pago: p,
                    onDelete: () => _quitar(i),
                  );
                }).toList(),
              ),
            const SizedBox(height: 12),

            // Botón agregar pago
            OutlinedButton.icon(
              onPressed: _excede || _completo ? null : _agregarPago,
              icon: const Icon(Icons.add),
              label: Text(_completo
                  ? 'Total completo'
                  : _excede
                      ? 'Excede el total'
                      : 'Agregar pago (${CurrencyFormatter.format(_faltaCobrar)})'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 20),

            // Acciones
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _completo ? _confirmar : null,
                  icon: const Icon(Icons.check_circle, size: 18),
                  label: const Text('Confirmar venta'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ResumenPanel extends StatelessWidget {
  const _ResumenPanel({
    required this.total,
    required this.pagado,
    required this.falta,
    required this.excede,
    required this.completo,
  });

  final double total;
  final double pagado;
  final double falta;
  final bool excede;
  final bool completo;

  @override
  Widget build(BuildContext context) {
    final estadoColor = completo
        ? AppColors.secondary
        : excede
            ? AppColors.error
            : AppColors.warning;
    final estadoLabel = completo
        ? 'COMPLETO'
        : excede
            ? 'EXCEDE'
            : 'FALTA';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: estadoColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: estadoColor.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Pagado',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                Text(
                  CurrencyFormatter.format(pagado),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(excede ? 'Sobra' : 'Falta',
                    style:
                        const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                Text(
                  CurrencyFormatter.format(falta.abs()),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: estadoColor,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: estadoColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              estadoLabel,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PagoTile extends StatelessWidget {
  const _PagoTile({required this.pago, required this.onDelete});

  final PagoParcial pago;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: pago.formaPago.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(pago.formaPago.icon, color: pago.formaPago.color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pago.formaPago.label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (pago.codigoOperacion != null)
                  Text(
                    'Cód. operación: ${pago.codigoOperacion}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
              ],
            ),
          ),
          Text(
            CurrencyFormatter.format(pago.monto),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: AppColors.error),
            onPressed: onDelete,
            tooltip: 'Quitar',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}

/// Sheet/diálogo para agregar un pago parcial.
class _AgregarPagoSheet extends StatefulWidget {
  const _AgregarPagoSheet({required this.montoSugerido});
  final double montoSugerido;

  @override
  State<_AgregarPagoSheet> createState() => _AgregarPagoSheetState();
}

class _AgregarPagoSheetState extends State<_AgregarPagoSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _montoCtrl;
  final _codigoCtrl = TextEditingController();
  FormaPago _forma = FormaPago.efectivo;

  @override
  void initState() {
    super.initState();
    _montoCtrl = TextEditingController(text: widget.montoSugerido.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _montoCtrl.dispose();
    _codigoCtrl.dispose();
    super.dispose();
  }

  void _confirmar() {
    if (!_formKey.currentState!.validate()) return;
    final monto = double.tryParse(_montoCtrl.text) ?? 0;
    if (monto <= 0) return;
    Navigator.of(context).pop(PagoParcial(
      formaPago: _forma,
      monto: monto,
      codigoOperacion: _forma.requiereCodigo && _codigoCtrl.text.isNotEmpty
          ? _codigoCtrl.text.trim()
          : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Agregar pago',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Forma de pago',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: FormaPago.values.map((f) {
                  final activo = f == _forma;
                  return InkWell(
                    onTap: () => setState(() => _forma = f),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: activo ? f.color : Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: f.color, width: activo ? 0 : 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(f.icon,
                              size: 14,
                              color: activo ? Colors.white : f.color),
                          const SizedBox(width: 4),
                          Text(
                            f.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: activo ? Colors.white : f.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _montoCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Monto',
                  prefixText: 'S/. ',
                  isDense: true,
                ),
                validator: (v) {
                  final d = double.tryParse(v ?? '');
                  if (d == null || d <= 0) return 'Ingrese un monto válido';
                  return null;
                },
              ),
              if (_forma.requiereCodigo) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _codigoCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 8,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 16,
                    letterSpacing: 2,
                    color: AppColors.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Código de operación',
                    hintText: '000000',
                    counterText: '',
                    isDense: true,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 4),
                  FilledButton(
                    onPressed: _confirmar,
                    child: const Text('Agregar'),
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
