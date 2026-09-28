import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/api/api_exception.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/services/report_export_service.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../cajas/data/models/caja_models.dart';
import '../../../cajas/presentation/providers/cajas_provider.dart';
import '../../../productos/data/models/producto_model.dart';
import '../../../productos/presentation/providers/productos_provider.dart';
import '../../data/models/venta_model.dart';
import '../providers/ventas_provider.dart';
import '../widgets/finalizar_venta_dialog.dart';
import '../widgets/multiple_pagos_dialog.dart';

/// Punto de venta conectado al backend.
///
/// - Catálogo: GET /productos (con precio vigente y stock).
/// - Requiere caja abierta del usuario (GET /cajas/abierta).
/// - Cobro: pago mixto. Un pago a CRÉDITO exige elegir al trabajador
///   (padrón de FinantialTracker) y genera su deuda (pestaña Deudores).
///   Un cliente externo paga con otra forma y solo se registra la venta.
/// - POST /ventas descuenta stock y guarda la venta; el historial del turno
///   viene de GET /ventas?cajaId=...
class VentasPage extends ConsumerStatefulWidget {
  const VentasPage({super.key});

  @override
  ConsumerState<VentasPage> createState() => _VentasPageState();
}

class _VentasPageState extends ConsumerState<VentasPage> {
  final _carrito = <_CarritoItem>[];
  final _busquedaCtrl = TextEditingController();
  String _categoriaFiltro = 'Todos';
  bool _mostrandoHistorial = false;
  bool _procesando = false;

  static const _categorias = ['Todos', 'Productos', 'Servicios', 'Bazar'];

  double get _total => _carrito.fold(0, (s, i) => s + i.subtotal);
  int get _cantidadItems => _carrito.fold(0, (s, i) => s + i.cantidad);

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  // ─── Carrito ───

  void _agregar(ProductoModel p) {
    if (p.precioVenta <= 0) {
      context.showSnack('${p.descripcion} no tiene precio de venta',
          isError: true);
      return;
    }
    final idx = _carrito.indexWhere((i) => i.producto.id == p.id);
    final actual = idx >= 0 ? _carrito[idx].cantidad : 0;
    if (!p.esServicio && actual + 1 > p.stock) {
      context.showSnack(
          'Stock insuficiente de ${p.descripcion} (hay ${_fmtCant(p.stock)})',
          isError: true);
      return;
    }
    setState(() {
      if (idx >= 0) {
        _carrito[idx].cantidad++;
      } else {
        _carrito.add(_CarritoItem(p, 1));
      }
    });
  }

  void _cambiarCantidad(int i, int delta) {
    final item = _carrito[i];
    if (delta > 0 &&
        !item.producto.esServicio &&
        item.cantidad + delta > item.producto.stock) {
      context.showSnack('Stock insuficiente de ${item.producto.descripcion}',
          isError: true);
      return;
    }
    setState(() {
      item.cantidad += delta;
      if (item.cantidad <= 0) _carrito.removeAt(i);
    });
  }

  void _vaciar() => setState(_carrito.clear);

  // ─── Cobro ───

  Future<void> _cobrar(CajaDetalleDto? caja) async {
    if (_carrito.isEmpty || _procesando) return;
    if (caja == null) {
      context.showSnack('Abre tu caja antes de vender', isError: true);
      return;
    }

    // 1) Distribuir el total entre formas de pago (crédito exige trabajador)
    final pagos = await showDialog<List<PagoParcial>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => MultiplePagosDialog(total: _total),
    );
    if (pagos == null || pagos.isEmpty || !mounted) return;

    // 2) Comprobante + datos del cliente (opcional)
    final datos = await showDialog<DatosComprobante>(
      context: context,
      barrierDismissible: false,
      builder: (_) => FinalizarVentaDialog(
        total: _total,
        formaPago: _resumenFormasPago(pagos),
        itemsCount: _cantidadItems,
      ),
    );
    if (datos == null || !mounted) return;

    // 3) Registrar en el backend
    setState(() => _procesando = true);
    VentaModel venta;
    try {
      venta = await ref.read(ventasControllerProvider).crear(
            items: _carrito
                .map((i) => VentaItemInput(
                      productoId: i.producto.id,
                      cantidad: i.cantidad.toDouble(),
                    ))
                .toList(),
            pagos: pagos,
            observacion: _observacionComprobante(datos),
          );
    } catch (e) {
      if (mounted) {
        setState(() => _procesando = false);
        context.showSnack(_mensajeError(e), isError: true);
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _carrito.clear();
      _procesando = false;
    });
    ref.invalidate(productosListProvider); // stock actualizado
    ref.invalidate(cajaAbiertaProvider); // totales de la caja

    // 4) Confirmación
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        icon: const Icon(Icons.check_circle,
            color: AppColors.secondary, size: 48),
        title: Text(venta.tieneCredito
            ? '${datos.tipo.label} registrada · deuda anotada'
            : '${datos.tipo.label} registrada'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detalleConfirmacion('Código', venta.codigo),
            _detalleConfirmacion(
                'Total', CurrencyFormatter.format(venta.total)),
            const SizedBox(height: 4),
            const Text('Pagos:',
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            for (final p in venta.pagos)
              Padding(
                padding: const EdgeInsets.only(left: 12, top: 2),
                child: Text(
                  '${p.formaPagoLabel}: ${CurrencyFormatter.format(p.monto)}'
                  '${p.codigoOperacion != null ? "  #${p.codigoOperacion}" : ""}'
                  '${p.clienteNombre != null ? "  → deuda de ${p.clienteNombre}" : ""}',
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 12),
                ),
              ),
            if (venta.tieneCredito) ...[
              const SizedBox(height: 8),
              const Text(
                'La deuda ya aparece en la pestaña Deudores y entrará al próximo cierre mensual.',
                style: TextStyle(color: AppColors.warning, fontSize: 12),
              ),
            ],
            if (datos.razonSocialNombre != null)
              _detalleConfirmacion('Cliente', datos.razonSocialNombre!),
            if (datos.nroDocumento != null)
              _detalleConfirmacion(
                  datos.tipo == TipoComprobante.factura ? 'RUC' : 'DNI',
                  datos.nroDocumento!),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cerrar'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              _imprimirComprobante(venta, tipo: datos.tipo.label);
            },
            icon: const Icon(Icons.print, size: 16),
            label: const Text('Imprimir comprobante'),
          ),
        ],
      ),
    );
  }

  Future<void> _anular(VentaModel v) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Anular ${v.codigo}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Se devuelve el stock. ${v.tieneCredito ? "La deuda del trabajador se elimina (si aún no fue cerrada)." : ""}',
              style:
                  const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: const InputDecoration(
                  labelText: 'Motivo', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(c, ctrl.text.trim().isNotEmpty),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Anular'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(ventasControllerProvider).anular(v.id, ctrl.text.trim());
      if (!mounted) return;
      ref.invalidate(productosListProvider);
      ref.invalidate(cajaAbiertaProvider);
      context.showSnack('Venta ${v.codigo} anulada');
    } catch (e) {
      if (mounted) context.showSnack(_mensajeError(e), isError: true);
    }
  }

  String _mensajeError(Object e) => e is ApiException ? e.message : '$e';

  String _observacionComprobante(DatosComprobante d) {
    final partes = <String>[d.tipo.label];
    if (d.nroDocumento != null) {
      partes.add(
          '${d.tipo == TipoComprobante.factura ? "RUC" : "DNI"} ${d.nroDocumento}');
    }
    if (d.razonSocialNombre != null) partes.add(d.razonSocialNombre!);
    if (d.direccion != null) partes.add(d.direccion!);
    final s = partes.join(' · ');
    return s.length > 300 ? s.substring(0, 300) : s;
  }

  String _resumenFormasPago(List<PagoParcial> pagos) {
    if (pagos.length == 1) return pagos.first.formaPago.label;
    if (pagos.length == 2)
      return '${pagos[0].formaPago.label} + ${pagos[1].formaPago.label}';
    return 'Mixto (${pagos.map((p) => p.formaPago.label).join(' + ')})';
  }

  Widget _detalleConfirmacion(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(
              width: 110,
              child: Text(k,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
            ),
            Expanded(
              child: Text(v,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      );

  Future<void> _imprimirComprobante(VentaModel v,
      {String tipo = 'Ticket'}) async {
    final filas = v.items
        .map((i) => [
              _fmtCant(i.cantidad),
              i.descripcion,
              CurrencyFormatter.format(i.precioUnitario),
              CurrencyFormatter.format(i.subtotal),
            ])
        .toList();
    final sub = StringBuffer()
      ..writeln('Comprobante: ${v.codigo}')
      ..writeln('Fecha: ${AppDateUtils.formatDateTime(v.fecha)}')
      ..writeln('Atendió: ${v.usuarioNombre}');
    if (v.pagos.length == 1) {
      final p = v.pagos.first;
      sub.writeln('Forma de pago: ${p.formaPagoLabel}'
          '${p.clienteNombre != null ? " (deuda de ${p.clienteNombre})" : ""}');
      if (p.codigoOperacion != null)
        sub.writeln('Cód. operación: ${p.codigoOperacion}');
    } else {
      sub.writeln('Pagos:');
      for (final p in v.pagos) {
        sub.writeln(
            '  • ${p.formaPagoLabel}: ${CurrencyFormatter.format(p.monto)}'
            '${p.codigoOperacion != null ? "  (cód. ${p.codigoOperacion})" : ""}'
            '${p.clienteNombre != null ? "  (deuda de ${p.clienteNombre})" : ""}');
      }
    }
    if (v.observacion != null) sub.writeln(v.observacion);

    await ReportExportService.instance.imprimirPdf(
      titulo: '${tipo.toUpperCase()} DE VENTA',
      subtitulo: sub.toString().trim(),
      columnas: const ['Cant.', 'Producto', 'P. Unit.', 'Subtotal'],
      filas: filas,
      totales: [MapEntry('TOTAL', CurrencyFormatter.format(v.total))],
    );
  }

  static String _fmtCant(double c) =>
      c == c.roundToDouble() ? c.toInt().toString() : c.toStringAsFixed(2);

  static String _categoriaDe(ProductoModel p) {
    if (p.esServicio) return 'Servicios';
    if (p.esBazar) return 'Bazar';
    return 'Productos';
  }

  // ─── UI ───

  @override
  Widget build(BuildContext context) {
    final productosAsync = ref.watch(productosListProvider);
    final cajaAsync = ref.watch(cajaAbiertaProvider);
    final caja = cajaAsync.valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          // ━━━━━━━━ Panel izquierdo ━━━━━━━━
          Expanded(
            flex: 7,
            child: Column(
              children: [
                _buildHeader(caja),
                if (cajaAsync.hasValue && caja == null) _SinCajaBanner(),
                if (!_mostrandoHistorial) _buildChips(),
                Expanded(
                  child: _mostrandoHistorial
                      ? _HistorialVentas(
                          cajaId: caja?.caja.id,
                          filtro: _busquedaCtrl.text,
                          onReimprimir: _imprimirComprobante,
                          onAnular: _anular,
                        )
                      : productosAsync.when(
                          loading: () =>
                              const Center(child: CircularProgressIndicator()),
                          error: (e, _) => _ErrorCatalogo(
                            mensaje: _mensajeError(e),
                            onRetry: () =>
                                ref.invalidate(productosListProvider),
                          ),
                          data: (productos) => _buildGrid(productos),
                        ),
                ),
              ],
            ),
          ),
          // ━━━━━━━━ Carrito ━━━━━━━━
          _buildCarrito(caja),
        ],
      ),
    );
  }

  Widget _buildHeader(CajaDetalleDto? caja) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          const Icon(Icons.point_of_sale, color: AppColors.primary),
          const SizedBox(width: 12),
          const Text(
            'Punto de Venta',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.primary),
          ),
          const SizedBox(width: 16),
          Container(
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                _ToggleBtn(
                  label: 'Catálogo',
                  icon: Icons.grid_view,
                  activo: !_mostrandoHistorial,
                  onTap: () => setState(() => _mostrandoHistorial = false),
                ),
                _ToggleBtn(
                  label: 'Historial del turno',
                  icon: Icons.history,
                  activo: _mostrandoHistorial,
                  onTap: () => setState(() => _mostrandoHistorial = true),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: _busquedaCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: _mostrandoHistorial
                    ? 'Buscar por código o trabajador...'
                    : 'Buscar producto (nombre o código)...',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Refrescar catálogo y caja',
            icon: const Icon(Icons.refresh, color: AppColors.primary),
            onPressed: () {
              ref.invalidate(productosListProvider);
              ref.invalidate(cajaAbiertaProvider);
              ref.invalidate(ventasDeCajaProvider);
            },
          ),
          if (caja != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Caja ${caja.caja.turno == TipoTurno.dia ? "DÍA" : "NOCHE"} · '
                'ventas ${CurrencyFormatter.format(caja.totalVentas)}',
                style: const TextStyle(
                    color: AppColors.secondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: Row(
        children: _categorias.map((c) {
          final activo = c == _categoriaFiltro;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(c),
              selected: activo,
              onSelected: (_) => setState(() => _categoriaFiltro = c),
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                color: activo ? Colors.white : AppColors.textPrimary,
                fontWeight: activo ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildGrid(List<ProductoModel> productos) {
    final q = _busquedaCtrl.text.toLowerCase();
    final filtrados = productos.where((p) {
      final cat =
          _categoriaFiltro == 'Todos' || _categoriaDe(p) == _categoriaFiltro;
      final txt = q.isEmpty ||
          p.descripcion.toLowerCase().contains(q) ||
          (p.codigo ?? '').toLowerCase().contains(q);
      return cat && txt;
    }).toList();
    if (filtrados.isEmpty) {
      return const Center(
        child: Text('Sin productos para mostrar',
            style: TextStyle(color: AppColors.textSecondary)),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 190,
        childAspectRatio: 0.95,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: filtrados.length,
      itemBuilder: (_, i) => _ProductoCard(
        producto: filtrados[i],
        enCarrito: _carrito
            .where((c) => c.producto.id == filtrados[i].id)
            .fold<int>(0, (s, c) => s + c.cantidad),
        onTap: () => _agregar(filtrados[i]),
      ),
    );
  }

  Widget _buildCarrito(CajaDetalleDto? caja) {
    return Container(
      width: 380,
      color: Colors.white,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(color: AppColors.primary),
            child: Row(
              children: [
                const Icon(Icons.shopping_cart, color: Colors.white),
                const SizedBox(width: 12),
                const Text('Carrito',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('$_cantidadItems items',
                      style:
                          const TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ],
            ),
          ),
          Expanded(
            child: _carrito.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_cart_outlined,
                            size: 56, color: AppColors.textSecondary),
                        SizedBox(height: 12),
                        Text('Toca productos para agregarlos',
                            style: TextStyle(color: AppColors.textSecondary)),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _carrito.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final item = _carrito[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Icon(_iconoDe(item.producto),
                                color: AppColors.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.producto.descripcion,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.textPrimary)),
                                  Text(
                                      CurrencyFormatter.format(
                                          item.producto.precioVenta),
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary)),
                                ],
                              ),
                            ),
                            _CantidadStepper(
                              cantidad: item.cantidad,
                              onMinus: () => _cambiarCantidad(i, -1),
                              onPlus: () => _cambiarCantidad(i, 1),
                            ),
                            SizedBox(
                              width: 70,
                              child: Text(
                                CurrencyFormatter.format(item.subtotal),
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.background,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('TOTAL',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary)),
                    Text(
                      CurrencyFormatter.format(_total),
                      style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: (_carrito.isEmpty || caja == null || _procesando)
                        ? null
                        : () => _cobrar(caja),
                    icon: _procesando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.point_of_sale, size: 22),
                    label: Text(
                      caja == null ? 'Abre tu caja para vender' : 'Cobrar',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Pago mixto: Efectivo, Yape, Plin, Niubiz y Crédito (solo trabajadores)',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(fontSize: 10, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _carrito.isEmpty ? null : _vaciar,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Vaciar carrito'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static IconData _iconoDe(ProductoModel p) {
    if (p.esServicio) return Icons.print;
    if (p.esBazar) return Icons.storefront;
    return Icons.fastfood;
  }
}

// ─────────────── Historial del turno ───────────────

class _HistorialVentas extends ConsumerWidget {
  const _HistorialVentas({
    required this.cajaId,
    required this.filtro,
    required this.onReimprimir,
    required this.onAnular,
  });
  final String? cajaId;
  final String filtro;
  final Future<void> Function(VentaModel v, {String tipo}) onReimprimir;
  final Future<void> Function(VentaModel v) onAnular;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ventasDeCajaProvider(cajaId));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
          child: Text('$e', style: const TextStyle(color: AppColors.error))),
      data: (ventas) {
        final q = filtro.toLowerCase();
        final lista = q.isEmpty
            ? ventas
            : ventas
                .where((v) =>
                    v.codigo.toLowerCase().contains(q) ||
                    v.pagos.any((p) =>
                        (p.clienteNombre ?? '').toLowerCase().contains(q)))
                .toList();
        if (lista.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 56, color: AppColors.textSecondary),
                SizedBox(height: 12),
                Text('Aún no hay ventas registradas en este turno',
                    style: TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: lista.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) => _VentaTile(
            v: lista[i],
            onReimprimir: () => onReimprimir(lista[i]),
            onAnular: lista[i].anulada ? null : () => onAnular(lista[i]),
          ),
        );
      },
    );
  }
}

class _VentaTile extends StatelessWidget {
  const _VentaTile(
      {required this.v, required this.onReimprimir, this.onAnular});
  final VentaModel v;
  final VoidCallback onReimprimir;
  final VoidCallback? onAnular;

  @override
  Widget build(BuildContext context) {
    final color = v.anulada
        ? AppColors.textSecondary
        : v.tieneCredito
            ? AppColors.warning
            : AppColors.secondary;
    final trabajadores = v.pagos
        .where((p) => p.clienteNombre != null)
        .map((p) => '${p.clienteNombre} (${CurrencyFormatter.format(p.monto)})')
        .join(', ');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              v.anulada
                  ? Icons.block
                  : v.tieneCredito
                      ? Icons.account_circle
                      : Icons.receipt_long,
              color: color,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(v.codigo,
                        style: const TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                    const SizedBox(width: 8),
                    if (v.anulada) _Etiqueta('ANULADA', AppColors.error),
                    if (v.tieneCredito && !v.anulada)
                      _Etiqueta('CRÉDITO', AppColors.warning),
                    if (v.pagos.length > 1)
                      _Etiqueta('MIXTO', AppColors.primary),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  v.tieneCredito
                      ? 'Deuda de: $trabajadores'
                      : (v.observacion ?? 'Venta al contado'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  '${AppDateUtils.formatTime(v.fecha)} · ${v.formaPagoResumen} · '
                  '${v.cantidadItems} items · ${v.usuarioNombre}'
                  '${v.anulada && v.motivoAnulacion != null ? " · motivo: ${v.motivoAnulacion}" : ""}',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                CurrencyFormatter.format(v.total),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color:
                      v.anulada ? AppColors.textSecondary : AppColors.primary,
                  decoration: v.anulada ? TextDecoration.lineThrough : null,
                ),
              ),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: onReimprimir,
                    icon: const Icon(Icons.print, size: 14),
                    label: const Text('Reimprimir'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  if (onAnular != null)
                    TextButton.icon(
                      onPressed: onAnular,
                      icon: const Icon(Icons.block, size: 14),
                      label: const Text('Anular'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.error,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta(this.texto, this.color);
  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(texto,
          style: TextStyle(
              color: color, fontSize: 9, fontWeight: FontWeight.w700)),
    );
  }
}

// ─────────────── Banners ───────────────

class _SinCajaBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.warning),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, color: AppColors.warning),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'No tienes una caja abierta. Abre tu caja del turno para poder cobrar.',
              style: TextStyle(
                  color: AppColors.textPrimary, fontWeight: FontWeight.w600),
            ),
          ),
          FilledButton(
            onPressed: () => context.go(AppRoutes.cajas),
            style: FilledButton.styleFrom(backgroundColor: AppColors.warning),
            child: const Text('Ir a Cajas'),
          ),
        ],
      ),
    );
  }
}

class _ErrorCatalogo extends StatelessWidget {
  const _ErrorCatalogo({required this.mensaje, required this.onRetry});
  final String mensaje;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off, size: 48, color: AppColors.error),
          const SizedBox(height: 8),
          Text(mensaje, style: const TextStyle(color: AppColors.error)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar')),
        ],
      ),
    );
  }
}

// ─────────────── Widgets auxiliares ───────────────

class _ToggleBtn extends StatelessWidget {
  const _ToggleBtn({
    required this.label,
    required this.icon,
    required this.activo,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: activo ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 14, color: activo ? Colors.white : AppColors.textPrimary),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: activo ? Colors.white : AppColors.textPrimary,
                )),
          ],
        ),
      ),
    );
  }
}

class _ProductoCard extends StatelessWidget {
  const _ProductoCard(
      {required this.producto, required this.enCarrito, required this.onTap});
  final ProductoModel producto;
  final int enCarrito;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = producto;
    final agotado = !p.esServicio && p.stock <= 0;
    final icono = p.esServicio
        ? Icons.print
        : p.esBazar
            ? Icons.storefront
            : Icons.fastfood;
    return InkWell(
      onTap: agotado ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: agotado ? AppColors.background : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: enCarrito > 0 ? AppColors.primary : AppColors.border,
              width: enCarrito > 0 ? 2 : 1),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(icono,
                    size: 30,
                    color:
                        agotado ? AppColors.textSecondary : AppColors.primary),
                const Spacer(),
                if (enCarrito > 0)
                  CircleAvatar(
                    radius: 11,
                    backgroundColor: AppColors.primary,
                    child: Text('$enCarrito',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 11)),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Text(
                p.descripcion,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500),
              ),
            ),
            Text(
              CurrencyFormatter.format(p.precioVenta),
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary),
            ),
            Text(
              p.esServicio
                  ? 'servicio'
                  : agotado
                      ? 'AGOTADO'
                      : 'stock ${_VentasPageState._fmtCant(p.stock)}',
              style: TextStyle(
                fontSize: 10,
                color: agotado
                    ? AppColors.error
                    : p.stockBajo && !p.esServicio
                        ? AppColors.warning
                        : AppColors.textSecondary,
                fontWeight: agotado ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CantidadStepper extends StatelessWidget {
  const _CantidadStepper({
    required this.cantidad,
    required this.onMinus,
    required this.onPlus,
  });
  final int cantidad;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: onMinus,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Icon(Icons.remove, size: 14),
            ),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 26),
            child: Text('$cantidad',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          InkWell(
            onTap: onPlus,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Icon(Icons.add, size: 14),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────── Modelos locales ───────────────

class _CarritoItem {
  _CarritoItem(this.producto, this.cantidad);
  final ProductoModel producto;
  int cantidad;
  double get subtotal => producto.precioVenta * cantidad;
}
