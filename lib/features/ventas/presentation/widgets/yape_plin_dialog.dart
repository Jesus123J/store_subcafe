import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';

/// Diálogo que muestra el QR de Yape/Plin y pide el código de operación
/// para confirmar el pago manualmente (flujo realista para bodegas pequeñas).
class YapePlinDialog extends StatefulWidget {
  const YapePlinDialog({
    required this.formaPago,
    required this.total,
    super.key,
  });

  final String formaPago;       // "Yape" o "Plin"
  final double total;

  @override
  State<YapePlinDialog> createState() => _YapePlinDialogState();
}

class _YapePlinDialogState extends State<YapePlinDialog> {
  final _codigoCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _verificando = false;

  // Datos del comerciante (luego van a configuración)
  String get _numero => widget.formaPago == 'Yape' ? '987654321' : '912345678';
  String get _titular => 'BODEGA LA CONFIANZA';

  Color get _color => widget.formaPago == 'Yape'
      ? const Color(0xFF722F8E)
      : const Color(0xFF00A19A);

  /// Payload del QR. En producción este es el QR que te genera Yape/Plin
  /// al afiliarte. Aquí construimos un texto simulado.
  String get _qrPayload =>
      '${widget.formaPago.toUpperCase()}|$_numero|$_titular|${widget.total.toStringAsFixed(2)}';

  @override
  void dispose() {
    _codigoCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _verificando = true);

    // Simula verificación. En la versión PRO con API esto haría una
    // llamada al backend que consulta el webhook de Yape Negocios.
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    Navigator.of(context).pop(_codigoCtrl.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 720),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Encabezado ──
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _color,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.phone_android, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Cobrar con ${widget.formaPago}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      CurrencyFormatter.format(widget.total),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 420,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Panel izquierdo: QR ──
                    Expanded(
                      flex: 1,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: _color.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: _color.withValues(alpha: 0.3), width: 1.5),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Paso 1 - Escanea el QR',
                              style: TextStyle(
                                color: _color,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: QrImageView(
                                data: _qrPayload,
                                size: 180,
                                eyeStyle: QrEyeStyle(
                                  eyeShape: QrEyeShape.square,
                                  color: _color,
                                ),
                                dataModuleStyle: QrDataModuleStyle(
                                  dataModuleShape: QrDataModuleShape.square,
                                  color: _color,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _titular,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              '${widget.formaPago}: $_numero',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const Spacer(),
                            const Text(
                              'El cliente escanea, paga el monto exacto, y muestra el comprobante.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // ── Panel derecho: código ──
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.secondary.withValues(alpha: 0.4),
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Paso 2 - Verifica el pago',
                                  style: TextStyle(
                                    color: AppColors.secondary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  '1️⃣  Confirma en tu celular que el monto llegó.\n'
                                  '2️⃣  Pide al cliente el "código de operación" (6 dígitos).\n'
                                  '3️⃣  Ingrésalo abajo para registrar la venta.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.5,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Código de operación',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _codigoCtrl,
                            keyboardType: TextInputType.number,
                            autofocus: true,
                            maxLength: 8,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 4,
                              fontFamily: 'monospace',
                              color: AppColors.textPrimary,
                            ),
                            decoration: InputDecoration(
                              hintText: '000000',
                              hintStyle: TextStyle(
                                color: Colors.grey.shade300,
                                letterSpacing: 4,
                              ),
                              prefixIcon: Icon(Icons.confirmation_number,
                                  color: _color),
                              counterText: '',
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            validator: (v) {
                              if (v == null || v.length < 6) {
                                return 'Ingresa al menos 6 dígitos';
                              }
                              return null;
                            },
                            onFieldSubmitted: (_) => _confirmar(),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.info_outline,
                                  size: 12, color: AppColors.textSecondary),
                              const SizedBox(width: 4),
                              const Expanded(
                                child: Text(
                                  'En Yape: revisa "Movimientos" en tu app',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _verificando
                                      ? null
                                      : () => Navigator.of(context).pop(),
                                  child: const Text('Cancelar'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: FilledButton.icon(
                                  onPressed: _verificando ? null : _confirmar,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _color,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                  icon: _verificando
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2, color: Colors.white),
                                        )
                                      : const Icon(Icons.check_circle, size: 18),
                                  label: Text(
                                    _verificando ? 'Verificando...' : 'Confirmar pago',
                                  ),
                                ),
                              ),
                            ],
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
    );
  }
}
