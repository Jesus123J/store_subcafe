import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_endpoints.dart';
import '../../../cajas/presentation/providers/cajas_provider.dart';
import '../../../productos/presentation/providers/productos_provider.dart';

/// Pago parcial que se envia al backend.
class PagoRequest {
  PagoRequest({
    required this.formaPago,
    required this.monto,
    this.codigoOperacion,
    this.trabajadorCreditoId,
  });

  /// 'EFECTIVO' | 'YAPE' | 'PLIN' | 'NIUBIZ' | 'CREDITO'
  final String formaPago;
  final double monto;
  final String? codigoOperacion;
  final String? trabajadorCreditoId;

  Map<String, dynamic> toJson() => {
        'formaPago': formaPago,
        'monto': monto,
        if (codigoOperacion != null && codigoOperacion!.isNotEmpty)
          'codigoOperacion': codigoOperacion,
        if (trabajadorCreditoId != null) 'trabajadorCreditoId': trabajadorCreditoId,
      };
}

/// Linea de venta enviada al backend.
class ItemVentaRequest {
  ItemVentaRequest({
    required this.productoId,
    required this.cantidad,
    required this.precioUnitario,
  });

  final String productoId;
  final double cantidad;
  final double precioUnitario;

  Map<String, dynamic> toJson() => {
        'productoId': productoId,
        'cantidad': cantidad,
        'precioUnitario': precioUnitario,
      };
}

final ventasControllerProvider = Provider<VentasController>(
  (ref) => VentasController(ref),
);

class VentasController {
  VentasController(this._ref);
  final Ref _ref;

  /// POST /ventas. Despues invalida productos (stock cambio) y caja
  /// abierta (totales cambiaron) para que la UI refresque.
  Future<Map<String, dynamic>> registrarVenta({
    required List<ItemVentaRequest> items,
    required List<PagoRequest> pagos,
  }) async {
    final json = await ApiClient.instance.postData<Map<String, dynamic>>(
      ApiEndpoints.ventas,
      body: {
        'items': items.map((i) => i.toJson()).toList(),
        'pagos': pagos.map((p) => p.toJson()).toList(),
      },
    );
    _ref.invalidate(productosListProvider);
    _ref.invalidate(cajaAbiertaProvider);
    return json;
  }
}
