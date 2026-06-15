import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/services/report_export_service.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_utils.dart';
import '../widgets/finalizar_venta_dialog.dart';
import '../widgets/multiple_pagos_dialog.dart';

class VentasPage extends StatefulWidget {
  const VentasPage({super.key});

  @override
  State<VentasPage> createState() => _VentasPageState();
}

class _VentasPageState extends State<VentasPage> {
  final _productosCatalogo = const [
    _ProductoDemo('Inca Kola 500ml', 3.50, '🥤', 'Bebidas'),
    _ProductoDemo('Coca Cola 500ml', 3.50, '🥤', 'Bebidas'),
    _ProductoDemo('Agua San Luis 625ml', 1.50, '💧', 'Bebidas'),
    _ProductoDemo('Galletas Soda Field', 2.00, '🍪', 'Snacks'),
    _ProductoDemo('Chocolate Sublime', 1.50, '🍫', 'Snacks'),
    _ProductoDemo('Papitas Lays 35g', 2.50, '🥔', 'Snacks'),
    _ProductoDemo('Fotocopia A4 B/N', 0.20, '📄', 'Servicios'),
    _ProductoDemo('Fotocopia A3 B/N', 0.50, '📄', 'Servicios'),
    _ProductoDemo('Impresión Color A4', 1.00, '🖨️', 'Servicios'),
    _ProductoDemo('Foto DNI', 5.00, '📷', 'Servicios'),
    _ProductoDemo('Pan Francés (unid)', 0.30, '🥖', 'Panadería'),
    _ProductoDemo('Pan Integral (unid)', 0.50, '🥖', 'Panadería'),
  ];

  final _carrito = <_CarritoItem>[];
  final _ventasDelTurno = <_VentaRegistrada>[];
  String _categoriaFiltro = 'Todos';
  final _busquedaCtrl = TextEditingController();
  bool _mostrandoHistorial = false;

  // Correlativos por tipo de comprobante (mock)
  int _correlativoBoleta = 1;
  int _correlativoFactura = 1;
  int _correlativoTicket = 1;

  double get _total => _carrito.fold(0, (s, i) => s + i.subtotal);

  void _agregar(_ProductoDemo p) {
    setState(() {
      final idx = _carrito.indexWhere((i) => i.producto.nombre == p.nombre);
      if (idx >= 0) {
        _carrito[idx].cantidad++;
      } else {
        _carrito.add(_CarritoItem(p, 1));
      }
    });
  }

  void _cambiarCantidad(int i, int delta) {
    setState(() {
      _carrito[i].cantidad += delta;
      if (_carrito[i].cantidad <= 0) _carrito.removeAt(i);
    });
  }

  void _vaciar() => setState(_carrito.clear);

  Future<void> _cobrar() async {
    if (_carrito.isEmpty) return;

    // 1) Distribuir el total entre N formas de pago (pago mixto)
    final pagos = await showDialog<List<PagoParcial>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => MultiplePagosDialog(total: _total),
    );
    if (pagos == null || pagos.isEmpty || !mounted) return;

    // 2) Diálogo para tipo de comprobante + datos del cliente
    final datos = await showDialog<DatosComprobante>(
      context: context,
      barrierDismissible: false,
      builder: (_) => FinalizarVentaDialog(
        total: _total,
        formaPago: _resumenFormasPago(pagos),
        itemsCount: _carrito.fold(0, (s, i) => s + i.cantidad),
      ),
    );

    if (datos == null || !mounted) return;

    // 3) Asignar correlativo + snapshot de la venta
    final nroComprobante = _siguienteCorrelativo(datos.tipo);
    final venta = _VentaRegistrada(
      nroComprobante: nroComprobante,
      tipoComprobante: datos.tipo,
      pagos: pagos,
      total: _total,
      fecha: DateTime.now(),
      items: List.of(_carrito),
      cliente: datos.razonSocialNombre,
      docCliente: datos.nroDocumento,
      direccionCliente: datos.direccion,
    );

    // 4) Guardar en historial del turno + vaciar carrito
    setState(() {
      _ventasDelTurno.insert(0, venta);
      _carrito.clear();
    });

    // 5) Confirmación + opción de imprimir
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: AppColors.secondary, size: 48),
        title: Text('${datos.tipo.label} registrada'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detalleConfirmacion('N° comprobante', nroComprobante),
            _detalleConfirmacion('Total', CurrencyFormatter.format(venta.total)),
            const SizedBox(height: 4),
            const Text(
              'Pagos:',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            for (final p in pagos)
              Padding(
                padding: const EdgeInsets.only(left: 12, top: 2),
                child: Text(
                  '${p.formaPago.label}: ${CurrencyFormatter.format(p.monto)}'
                  '${p.codigoOperacion != null ? "  #${p.codigoOperacion}" : ""}',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                  ),
                ),
              ),
            const SizedBox(height: 6),
            if (venta.cliente != null)
              _detalleConfirmacion('Cliente', venta.cliente!),
            if (venta.docCliente != null)
              _detalleConfirmacion(
                  datos.tipo == TipoComprobante.factura ? 'RUC' : 'DNI',
                  venta.docCliente!),
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
              _imprimirComprobante(venta);
            },
            icon: const Icon(Icons.print, size: 16),
            label: const Text('Imprimir comprobante'),
          ),
        ],
      ),
    );
  }

  /// Resumen de formas de pago para mostrar en encabezado del comprobante.
  /// "Efectivo" / "Yape + Plin" / "Mixto (Efectivo + Yape + Crédito)"
  String _resumenFormasPago(List<PagoParcial> pagos) {
    if (pagos.length == 1) return pagos.first.formaPago.label;
    if (pagos.length == 2) {
      return '${pagos[0].formaPago.label} + ${pagos[1].formaPago.label}';
    }
    return 'Mixto (${pagos.map((p) => p.formaPago.label).join(' + ')})';
  }

  Widget _detalleConfirmacion(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(
              width: 110,
              child: Text(k,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ),
            Expanded(
              child: Text(v,
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      );

  String _siguienteCorrelativo(TipoComprobante t) {
    final n = switch (t) {
      TipoComprobante.boleta => _correlativoBoleta++,
      TipoComprobante.factura => _correlativoFactura++,
      TipoComprobante.ticket => _correlativoTicket++,
    };
    final prefijo = switch (t) {
      TipoComprobante.boleta => 'B001',
      TipoComprobante.factura => 'F001',
      TipoComprobante.ticket => 'T001',
    };
    return '$prefijo-${n.toString().padLeft(6, '0')}';
  }

  Future<void> _imprimirComprobante(_VentaRegistrada v) async {
    final filas = v.items
        .map((i) => [
              '${i.cantidad}',
              i.producto.nombre,
              CurrencyFormatter.format(i.producto.precio),
              CurrencyFormatter.format(i.subtotal),
            ])
        .toList();

    final subtitulo = StringBuffer()
      ..writeln('Comprobante: ${v.nroComprobante}')
      ..writeln('Fecha: ${AppDateUtils.formatDateTime(v.fecha)}');
    // Detalle de pagos (pago mixto)
    if (v.pagos.length == 1) {
      final p = v.pagos.first;
      subtitulo.writeln('Forma de pago: ${p.formaPago.label}');
      if (p.codigoOperacion != null) {
        subtitulo.writeln('Cód. operación: ${p.codigoOperacion}');
      }
    } else {
      subtitulo.writeln('Pagos:');
      for (final p in v.pagos) {
        final codigo = p.codigoOperacion != null ? '  (cód. ${p.codigoOperacion})' : '';
        subtitulo.writeln('  • ${p.formaPago.label}: '
            '${CurrencyFormatter.format(p.monto)}$codigo');
      }
    }
    if (v.cliente != null) subtitulo.writeln('Cliente: ${v.cliente}');
    if (v.docCliente != null) {
      subtitulo.writeln(v.tipoComprobante == TipoComprobante.factura
          ? 'RUC: ${v.docCliente}'
          : 'DNI: ${v.docCliente}');
    }
    if (v.direccionCliente != null) {
      subtitulo.writeln('Dirección: ${v.direccionCliente}');
    }

    await ReportExportService.instance.imprimirPdf(
      titulo: '${v.tipoComprobante.label.toUpperCase()} DE VENTA',
      subtitulo: subtitulo.toString().trim(),
      columnas: const ['Cant.', 'Producto', 'P. Unit.', 'Subtotal'],
      filas: filas,
      totales: [MapEntry('TOTAL', CurrencyFormatter.format(v.total))],
    );
  }

  @override
  Widget build(BuildContext context) {
    final categorias = ['Todos', ...{for (final p in _productosCatalogo) p.categoria}];
    final filtrados = _productosCatalogo.where((p) {
      final coincideCategoria = _categoriaFiltro == 'Todos' || p.categoria == _categoriaFiltro;
      final coincideBusqueda = _busquedaCtrl.text.isEmpty ||
          p.nombre.toLowerCase().contains(_busquedaCtrl.text.toLowerCase());
      return coincideCategoria && coincideBusqueda;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          // ━━━━━━━━ Panel izquierdo ━━━━━━━━
          Expanded(
            flex: 7,
            child: Column(
              children: [
                Container(
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
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Toggle catálogo / historial
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
                              label: 'Historial (${_ventasDelTurno.length})',
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
                                ? 'Buscar por nro de comprobante...'
                                : 'Buscar producto...',
                            prefixIcon: const Icon(Icons.search),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_mostrandoHistorial)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: Colors.white,
                    child: Row(
                      children: categorias.map((c) {
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
                  ),
                Expanded(
                  child: _mostrandoHistorial
                      ? _buildHistorial()
                      : GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 180,
                            childAspectRatio: 0.95,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: filtrados.length,
                          itemBuilder: (_, i) => _ProductoCard(
                            producto: filtrados[i],
                            onTap: () => _agregar(filtrados[i]),
                          ),
                        ),
                ),
              ],
            ),
          ),
          // ━━━━━━━━ Carrito ━━━━━━━━
          Container(
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
                      const Text(
                        'Carrito',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_carrito.fold(0, (s, i) => s + i.cantidad)} items',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
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
                                  Text(item.producto.emoji,
                                      style: const TextStyle(fontSize: 24)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.producto.nombre,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        Text(
                                          CurrencyFormatter.format(item.producto.precio),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
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
                                        color: AppColors.textPrimary,
                                      ),
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
                          const Text(
                            'TOTAL',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            CurrencyFormatter.format(_total),
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Botón único que abre el diálogo de pago mixto.
                      // Soporta Efectivo, Yape, Plin, Niubiz, Crédito en una sola venta.
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _carrito.isEmpty ? null : _cobrar,
                          icon: const Icon(Icons.point_of_sale, size: 22),
                          label: const Text(
                            'Cobrar',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.secondary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Soporta pago mixto: Efectivo, Yape, Plin, Niubiz y Crédito',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
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
          ),
        ],
      ),
    );
  }

  // ━━━━━━━━ Historial ━━━━━━━━

  Widget _buildHistorial() {
    final filtradas = _busquedaCtrl.text.isEmpty
        ? _ventasDelTurno
        : _ventasDelTurno
            .where((v) =>
                v.nroComprobante.toLowerCase().contains(_busquedaCtrl.text.toLowerCase()))
            .toList();

    if (filtradas.isEmpty) {
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
      itemCount: filtradas.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final v = filtradas[i];
        final color = switch (v.tipoComprobante) {
          TipoComprobante.factura => AppColors.primary,
          TipoComprobante.boleta => AppColors.secondary,
          TipoComprobante.ticket => AppColors.textSecondary,
        };
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
                child: Icon(v.tipoComprobante.icon, color: color, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            v.tipoComprobante.label.toUpperCase(),
                            style: TextStyle(
                              color: color,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          v.nroComprobante,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      v.cliente ?? 'Cliente no registrado',
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.access_time,
                            size: 12, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(AppDateUtils.formatTime(v.fecha),
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 11)),
                        const SizedBox(width: 10),
                        const Icon(Icons.payment, size: 12, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          v.formaPagoResumen,
                          style: TextStyle(
                            color: v.pagos.length > 1
                                ? AppColors.primary
                                : AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: v.pagos.length > 1 ? FontWeight.w700 : null,
                          ),
                        ),
                        if (v.pagos.length > 1) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              'MIXTO',
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(width: 10),
                        const Icon(Icons.inventory_2,
                            size: 12, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text('${v.items.fold(0, (s, i) => s + i.cantidad)} items',
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyFormatter.format(v.total),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextButton.icon(
                    onPressed: () => _imprimirComprobante(v),
                    icon: const Icon(Icons.print, size: 14),
                    label: const Text('Reimprimir'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
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
  const _ProductoCard({required this.producto, required this.onTap});
  final _ProductoDemo producto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Text(producto.emoji, style: const TextStyle(fontSize: 36)),
            const SizedBox(height: 6),
            Expanded(
              child: Text(
                producto.nombre,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              CurrencyFormatter.format(producto.precio),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
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

// _PagoBtn eliminado: ahora el flujo de pago lo maneja MultiplePagosDialog,
// que soporta pago mixto (varias formas de pago en una sola venta).

// ─────────────── Modelos ───────────────

class _ProductoDemo {
  const _ProductoDemo(this.nombre, this.precio, this.emoji, this.categoria);
  final String nombre;
  final double precio;
  final String emoji;
  final String categoria;
}

class _CarritoItem {
  _CarritoItem(this.producto, this.cantidad);
  final _ProductoDemo producto;
  int cantidad;
  double get subtotal => producto.precio * cantidad;
}

class _VentaRegistrada {
  _VentaRegistrada({
    required this.nroComprobante,
    required this.tipoComprobante,
    required this.pagos,
    required this.total,
    required this.fecha,
    required this.items,
    this.cliente,
    this.docCliente,
    this.direccionCliente,
  });

  final String nroComprobante;
  final TipoComprobante tipoComprobante;
  final double total;
  final DateTime fecha;
  final List<_CarritoItem> items;
  final String? cliente;
  final String? docCliente;
  final String? direccionCliente;

  /// Lista de pagos parciales. Una venta puede tener varias formas de pago
  /// (pago mixto). La suma de pagos[].monto == total.
  final List<PagoParcial> pagos;

  /// Resumen legible: "Efectivo", "Yape + Plin", "Mixto (...)"
  String get formaPagoResumen {
    if (pagos.length == 1) return pagos.first.formaPago.label;
    if (pagos.length == 2) {
      return '${pagos[0].formaPago.label} + ${pagos[1].formaPago.label}';
    }
    return 'Mixto';
  }
}
