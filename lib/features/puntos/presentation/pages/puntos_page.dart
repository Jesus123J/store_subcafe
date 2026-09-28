import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_endpoints.dart';
import '../../../../shared/widgets/app_async_value.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../core/api/api_exception.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/widgets/app_page_header.dart';
import '../../../productos/data/models/producto_model.dart';
import '../../../productos/presentation/providers/productos_provider.dart';

final saldosPuntosProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final list = await ApiClient.instance
      .getData<List<dynamic>>(ApiEndpoints.puntosSaldos);
  return list.cast<Map<String, dynamic>>();
});

final reglaActivaProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  return ApiClient.instance
      .getData<Map<String, dynamic>?>(ApiEndpoints.puntosReglaActiva);
});

final canjeablesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final list = await ApiClient.instance
      .getData<List<dynamic>>(ApiEndpoints.puntosCanjeables);
  return list.cast<Map<String, dynamic>>();
});

class PuntosPage extends ConsumerWidget {
  const PuntosPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saldosAsync = ref.watch(saldosPuntosProvider);
    final reglaAsync = ref.watch(reglaActivaProvider);
    final canjeablesAsync = ref.watch(canjeablesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          AppPageHeader(
            title: 'Puntos por consumo',
            subtitle:
                'Cada venta con trabajador identificado suma puntos según la regla activa; se canjean por productos del bazar',
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, color: AppColors.primary),
                onPressed: () => _refrescar(ref),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _cambiarRegla(context, ref),
                icon: const Icon(Icons.rule),
                label: const Text('Cambiar regla'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => _agregarCanjeable(context, ref),
                icon: const Icon(Icons.card_giftcard),
                label: const Text('Agregar canjeable'),
              ),
            ],
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Regla activa
                  reglaAsync.when(
                    loading: () => const SizedBox(
                      height: 80,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (e, _) => const SizedBox.shrink(),
                    data: (r) {
                      if (r == null) {
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'No hay regla de puntos activa',
                            style: TextStyle(color: AppColors.textPrimary),
                          ),
                        );
                      }
                      final soles =
                          (r['soles_por_punto'] as num?)?.toDouble() ?? 10.0;
                      return Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              AppColors.primary,
                              AppColors.primaryLight,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.star,
                                color: Colors.white,
                                size: 36,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Regla activa',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '1 punto por cada S/. ${soles.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (r['descripcion'] != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      r['descripcion'].toString(),
                                      style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.85),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Saldos de puntos por cliente
                  AppCard(
                    margin: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Text(
                            'Saldos de puntos por trabajador',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        AppAsyncView<List<Map<String, dynamic>>>(
                          value: saldosAsync,
                          onRetry: () => ref.invalidate(saldosPuntosProvider),
                          dataBuilder: (lista) {
                            if (lista.isEmpty) {
                              return const Padding(
                                padding: EdgeInsets.all(32),
                                child: Center(
                                  child: Text(
                                    'Aún no hay puntos acumulados.\nLos puntos se generarán al registrar ventas con cliente identificado.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              );
                            }
                            return Column(
                              children: lista
                                  .map(
                                    (s) => ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: CircleAvatar(
                                        backgroundColor: AppColors.primary,
                                        child: Text(
                                          (s['nombres'] as String?)
                                                  ?.substring(0, 1) ??
                                              '?',
                                          style: const TextStyle(
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      title: Text(
                                        '${s['nombres']} ${s['apellidos']}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      subtitle: Text(
                                        'DNI: ${s['dni']}',
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                      trailing: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '${(s['saldo_puntos'] as num).toStringAsFixed(0)} pts',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.primary,
                                              fontSize: 18,
                                            ),
                                          ),
                                          const Text(
                                            'disponibles',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                  .toList(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Catálogo canjeables
                  AppCard(
                    margin: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: Text(
                            'Catálogo de productos canjeables',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        AppAsyncView<List<Map<String, dynamic>>>(
                          value: canjeablesAsync,
                          onRetry: () => ref.invalidate(canjeablesProvider),
                          dataBuilder: (lista) {
                            if (lista.isEmpty) {
                              return AppEmptyState(
                                message:
                                    'Todavía no hay productos canjeables.\nElige productos del bazar y cuántos puntos cuestan.',
                                icon: Icons.card_giftcard,
                                actionLabel: 'Agregar canjeable',
                                onAction: () => _agregarCanjeable(context, ref),
                              );
                            }
                            return Column(
                              children: lista
                                  .map((c) => ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: AppColors.secondary
                                                .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: const Icon(
                                            Icons.card_giftcard,
                                            color: AppColors.secondary,
                                          ),
                                        ),
                                        title: Text(
                                          c['descripcion'] as String? ?? '—',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        subtitle: Text(
                                          '${c['codigo'] ?? ''}'
                                          '${c['precio_venta'] != null ? ' · precio ${CurrencyFormatter.format((c['precio_venta'] as num).toDouble())}' : ''}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 6,
                                              ),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary
                                                    .withValues(alpha: 0.1),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                '${(c['puntos_requeridos'] as num).toStringAsFixed(0)} pts',
                                                style: const TextStyle(
                                                  color: AppColors.primary,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                              tooltip: 'Cambiar puntos',
                                              icon: const Icon(
                                                  Icons.edit_outlined,
                                                  size: 18),
                                              onPressed: () =>
                                                  _agregarCanjeable(
                                                context,
                                                ref,
                                                productoId:
                                                    c['producto_id'] as String?,
                                                descripcion:
                                                    c['descripcion'] as String?,
                                                puntosActuales:
                                                    (c['puntos_requeridos']
                                                            as num?)
                                                        ?.toDouble(),
                                              ),
                                            ),
                                            IconButton(
                                              tooltip: 'Quitar del catálogo',
                                              icon: const Icon(
                                                  Icons.delete_outline,
                                                  size: 18,
                                                  color: AppColors.error),
                                              onPressed: () => _quitarCanjeable(
                                                  context,
                                                  ref,
                                                  c['id'] as String,
                                                  c['descripcion'] as String? ??
                                                      ''),
                                            ),
                                          ],
                                        ),
                                      ))
                                  .toList(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _refrescar(WidgetRef ref) {
    ref.invalidate(saldosPuntosProvider);
    ref.invalidate(reglaActivaProvider);
    ref.invalidate(canjeablesProvider);
  }

  String _msg(Object e) => e is ApiException ? e.message : '$e';

  Future<void> _cambiarRegla(BuildContext context, WidgetRef ref) async {
    final actual = ref.read(reglaActivaProvider).valueOrNull;
    final soles = TextEditingController(
        text: ((actual?['soles_por_punto'] as num?)?.toDouble() ?? 10)
            .toStringAsFixed(2));
    final desc = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Regla de puntos'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Cuántos soles de compra dan 1 punto. La regla anterior queda en el historial; '
                'los puntos ya acumulados no cambian.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: soles,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Soles por punto',
                  prefixText: 'S/. ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: desc,
                decoration: const InputDecoration(
                  labelText: 'Descripción (opcional)',
                  hintText: 'Ej: Campaña aniversario',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Guardar regla')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ApiClient.instance.putData<Map<String, dynamic>>(
        ApiEndpoints.puntosReglaActiva,
        body: {
          'solesPorPunto':
              double.tryParse(soles.text.replaceAll(',', '.')) ?? 0,
          'descripcion': desc.text.trim().isEmpty ? null : desc.text.trim(),
        },
      );
      if (!context.mounted) return;
      _refrescar(ref);
      context.showSnack('Regla de puntos actualizada');
    } catch (e) {
      if (context.mounted) context.showSnack(_msg(e), isError: true);
    }
  }

  Future<void> _agregarCanjeable(
    BuildContext context,
    WidgetRef ref, {
    String? productoId,
    String? descripcion,
    double? puntosActuales,
  }) async {
    final res = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _CanjeableDialog(
        productoId: productoId,
        descripcion: descripcion,
        puntosActuales: puntosActuales,
      ),
    );
    if (res == null || !context.mounted) return;
    try {
      await ApiClient.instance.postData<Map<String, dynamic>>(
        ApiEndpoints.puntosCanjeables,
        body: res,
      );
      if (!context.mounted) return;
      ref.invalidate(canjeablesProvider);
      context.showSnack('Producto canjeable guardado');
    } catch (e) {
      if (context.mounted) context.showSnack(_msg(e), isError: true);
    }
  }

  Future<void> _quitarCanjeable(BuildContext context, WidgetRef ref, String id,
      String descripcion) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Quitar del catálogo'),
        content:
            Text('$descripcion dejará de canjearse por puntos. ¿Continuar?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ApiClient.instance.deleteData(ApiEndpoints.puntosCanjeable(id));
      if (!context.mounted) return;
      ref.invalidate(canjeablesProvider);
      context.showSnack('Producto quitado del catálogo');
    } catch (e) {
      if (context.mounted) context.showSnack(_msg(e), isError: true);
    }
  }
}

/// Elegir un producto del bazar y cuántos puntos cuesta.
class _CanjeableDialog extends ConsumerStatefulWidget {
  const _CanjeableDialog(
      {this.productoId, this.descripcion, this.puntosActuales});
  final String? productoId;
  final String? descripcion;
  final double? puntosActuales;

  @override
  ConsumerState<_CanjeableDialog> createState() => _CanjeableDialogState();
}

class _CanjeableDialogState extends ConsumerState<_CanjeableDialog> {
  late final TextEditingController _puntos = TextEditingController(
      text: widget.puntosActuales?.toStringAsFixed(0) ?? '');
  final _busqueda = TextEditingController();
  String? _productoId;

  @override
  void initState() {
    super.initState();
    _productoId = widget.productoId;
  }

  @override
  void dispose() {
    _puntos.dispose();
    _busqueda.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productosAsync = ref.watch(productosListProvider);
    final fijo = widget.productoId != null;
    return AlertDialog(
      title: Text(fijo
          ? 'Puntos para ${widget.descripcion}'
          : 'Nuevo producto canjeable'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!fijo) ...[
              const Text(
                'Solo aparecen los productos marcados como "del bazar".',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _busqueda,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Buscar producto',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 6),
              productosAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) =>
                    Text('$e', style: const TextStyle(color: AppColors.error)),
                data: (lista) {
                  final q = _busqueda.text.toLowerCase();
                  final bazar = lista
                      .where((p) => p.esBazar && p.activo)
                      .where((p) =>
                          q.isEmpty ||
                          p.descripcion.toLowerCase().contains(q) ||
                          (p.codigo ?? '').toLowerCase().contains(q))
                      .take(8)
                      .toList();
                  if (bazar.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Ningún producto del bazar coincide. Marca "Es producto del bazar" en Productos.',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                    );
                  }
                  return Container(
                    constraints: const BoxConstraints(maxHeight: 220),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: ListView(
                      shrinkWrap: true,
                      children: bazar.map((ProductoModel p) {
                        final sel = p.id == _productoId;
                        return ListTile(
                          dense: true,
                          selected: sel,
                          selectedTileColor: AppColors.primarySoft,
                          leading: Icon(
                              sel ? Icons.check_circle : Icons.storefront,
                              color: sel
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                              size: 20),
                          title: Text(p.descripcion),
                          subtitle: Text(
                              '${p.codigo ?? ''} · ${CurrencyFormatter.format(p.precioVenta)}'),
                          onTap: () => setState(() => _productoId = p.id),
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _puntos,
              autofocus: fijo,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Puntos requeridos',
                suffixText: 'pts',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            final pts = double.tryParse(_puntos.text) ?? 0;
            if (_productoId == null) {
              context.showSnack('Elige un producto del bazar', isError: true);
              return;
            }
            if (pts <= 0) {
              context.showSnack('Indica los puntos requeridos', isError: true);
              return;
            }
            Navigator.pop(
                context, {'productoId': _productoId, 'puntosRequeridos': pts});
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
