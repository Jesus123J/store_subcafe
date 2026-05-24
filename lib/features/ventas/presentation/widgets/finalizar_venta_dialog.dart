import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/validators.dart';

/// Tipo de comprobante de pago (régimen peruano).
enum TipoComprobante {
  ticket('Ticket', 'Sin valor tributario, solo control interno', Icons.receipt_long),
  boleta('Boleta', 'Para consumidor final (DNI opcional)', Icons.receipt),
  factura('Factura', 'Para empresas (requiere RUC)', Icons.description);

  const TipoComprobante(this.label, this.descripcion, this.icon);
  final String label;
  final String descripcion;
  final IconData icon;
}

/// Resultado del diálogo de finalización de venta.
class DatosComprobante {
  DatosComprobante({
    required this.tipo,
    this.nroDocumento,
    this.razonSocialNombre,
    this.direccion,
  });

  final TipoComprobante tipo;
  final String? nroDocumento;        // DNI (boleta) o RUC (factura)
  final String? razonSocialNombre;
  final String? direccion;

  bool get esTicket => tipo == TipoComprobante.ticket;
}

class FinalizarVentaDialog extends StatefulWidget {
  const FinalizarVentaDialog({
    required this.total,
    required this.formaPago,
    required this.itemsCount,
    super.key,
  });

  final double total;
  final String formaPago;
  final int itemsCount;

  @override
  State<FinalizarVentaDialog> createState() => _FinalizarVentaDialogState();
}

class _FinalizarVentaDialogState extends State<FinalizarVentaDialog> {
  final _formKey = GlobalKey<FormState>();
  final _docCtrl = TextEditingController();
  final _nombreCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();
  TipoComprobante _tipo = TipoComprobante.ticket;

  @override
  void dispose() {
    _docCtrl.dispose();
    _nombreCtrl.dispose();
    _direccionCtrl.dispose();
    super.dispose();
  }

  void _confirmar() {
    if (_tipo != TipoComprobante.ticket && !_formKey.currentState!.validate()) {
      return;
    }
    Navigator.of(context).pop(
      DatosComprobante(
        tipo: _tipo,
        nroDocumento: _docCtrl.text.trim().isEmpty ? null : _docCtrl.text.trim(),
        razonSocialNombre: _nombreCtrl.text.trim().isEmpty ? null : _nombreCtrl.text.trim(),
        direccion: _direccionCtrl.text.trim().isEmpty ? null : _direccionCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final esBoleta = _tipo == TipoComprobante.boleta;
    final esFactura = _tipo == TipoComprobante.factura;
    final requiereDatos = esBoleta || esFactura;

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Resumen de la venta ──
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryLight],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shopping_cart, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${widget.itemsCount} ${widget.itemsCount == 1 ? "item" : "items"}  ·  ${widget.formaPago}',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                          Text(
                            CurrencyFormatter.format(widget.total),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // ── Selector de tipo de comprobante ──
              const Text(
                'Tipo de comprobante',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: TipoComprobante.values.map((t) {
                  final activo = t == _tipo;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        onTap: () => setState(() {
                          _tipo = t;
                          _docCtrl.clear();
                          _nombreCtrl.clear();
                          _direccionCtrl.clear();
                        }),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: activo ? AppColors.primary : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: activo ? AppColors.primary : AppColors.border,
                              width: activo ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                t.icon,
                                color: activo ? Colors.white : AppColors.primary,
                                size: 24,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                t.label,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: activo ? Colors.white : AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                t.descripcion,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: activo
                                      ? Colors.white.withValues(alpha: 0.85)
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              // ── Campos según tipo ──
              if (requiereDatos) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        esFactura ? 'Datos del cliente (empresa)' : 'Datos del cliente',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _docCtrl,
                        style: const TextStyle(color: AppColors.textPrimary),
                        keyboardType: TextInputType.number,
                        maxLength: esFactura ? 11 : 8,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          labelText: esFactura ? 'RUC *' : 'DNI (opcional)',
                          hintText: esFactura ? '11 dígitos' : '8 dígitos',
                          prefixIcon: const Icon(Icons.badge_outlined),
                          counterText: '',
                          isDense: true,
                        ),
                        validator: esFactura ? Validators.ruc : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _nombreCtrl,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          labelText: esFactura
                              ? 'Razón Social *'
                              : 'Nombre del cliente (opcional)',
                          hintText: esFactura
                              ? 'Ej: Empresa SAC'
                              : 'Ej: Juan Pérez',
                          prefixIcon: const Icon(Icons.person_outline),
                          isDense: true,
                        ),
                        validator: esFactura
                            ? (v) => Validators.required(v, fieldName: 'Razón Social')
                            : null,
                      ),
                      if (esFactura) ...[
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _direccionCtrl,
                          style: const TextStyle(color: AppColors.textPrimary),
                          decoration: const InputDecoration(
                            labelText: 'Dirección (opcional)',
                            prefixIcon: Icon(Icons.location_on_outlined),
                            isDense: true,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ] else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.info, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Ticket simple: se registra la venta sin datos del cliente. '
                          'Solo para control interno.',
                          style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              // ── Acciones ──
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _confirmar,
                    icon: const Icon(Icons.check_circle, size: 18),
                    label: Text('Confirmar venta · ${CurrencyFormatter.format(widget.total)}'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
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
