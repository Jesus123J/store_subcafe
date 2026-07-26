import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../shared/widgets/app_async_value.dart';
import '../../../../shared/widgets/app_data_table.dart';
import '../../../../shared/widgets/app_page_header.dart';
import '../../data/models/trabajador_dto.dart';
import '../providers/trabajadores_provider.dart';

/// Trabajadores del hospital. Vienen passthrough desde FinantialTracker.
/// La bodega NO administra trabajadores — solo los muestra. El alta/baja
/// de personal se hace desde el FinantialTracker.
class TrabajadoresPage extends ConsumerWidget {
  const TrabajadoresPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(trabajadoresProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          AppPageHeader(
            title: 'Trabajadores',
            subtitle:
                'Empleados del hospital (fuente: FinantialTracker · solo lectura)',
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, color: AppColors.primary),
                tooltip: 'Refrescar desde planilla',
                onPressed: () => ref.invalidate(trabajadoresProvider),
              ),
            ],
          ),
          Expanded(
            child: AppAsyncView<List<TrabajadorDto>>(
              value: async,
              onRetry: () => ref.invalidate(trabajadoresProvider),
              dataBuilder: (lista) => _Body(trabajadores: lista),
            ),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatefulWidget {
  const _Body({required this.trabajadores});
  final List<TrabajadorDto> trabajadores;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  final _busquedaCtrl = TextEditingController();

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.trabajadores.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.people_outline,
                  size: 64, color: AppColors.textSecondary),
              SizedBox(height: 12),
              Text(
                'No hay trabajadores registrados en la planilla.\n'
                'Regístralos primero en FinantialTracker.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    final q = _busquedaCtrl.text.toLowerCase();
    final filtrados = q.isEmpty
        ? widget.trabajadores
        : widget.trabajadores.where((t) {
            return t.dni.contains(q) ||
                t.nombreCompleto.toLowerCase().contains(q) ||
                (t.estadoEmpleo?.toLowerCase().contains(q) ?? false);
          }).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppColors.info.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.link, size: 20, color: AppColors.info),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${widget.trabajadores.length} trabajadores sincronizados en vivo desde FinantialTracker. '
                    'Los abonos, préstamos y altas/bajas se administran allá.',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: AppDataTable(
              searchController: _busquedaCtrl,
              onSearchChanged: () => setState(() {}),
              searchHint: 'Buscar por DNI, nombre o estado...',
              totalItems: widget.trabajadores.length,
              filteredItems: filtrados.length,
              emptyMessage:
                  'No hay trabajadores que coincidan con la búsqueda',
              columns: const [
                AppTableColumn(label: 'DNI', width: 120),
                AppTableColumn(label: 'Nombre completo', flex: 3),
                AppTableColumn(label: 'Estado', width: 140),
              ],
              rows: filtrados
                  .map((t) => AppTableRow(
                        cells: [
                          Text(
                            t.dni,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                          Text(
                            t.nombreCompleto,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          _EstadoBadge(estado: t.estadoEmpleo),
                        ],
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Badge visual para el estado de empleo (Nombrado / CAS / Cese / etc).
/// Colorea segun el texto — si es null pinta un placeholder neutro.
class _EstadoBadge extends StatelessWidget {
  const _EstadoBadge({required this.estado});
  final String? estado;

  @override
  Widget build(BuildContext context) {
    if (estado == null || estado!.trim().isEmpty) {
      return const Text(
        '—',
        style: TextStyle(color: AppColors.textHint, fontSize: 12),
      );
    }
    final e = estado!.toLowerCase();
    final Color color;
    if (e.contains('nombr')) {
      color = AppColors.secondary;
    } else if (e.contains('cas')) {
      color = AppColors.info;
    } else if (e.contains('cese') ||
        e.contains('baja') ||
        e.contains('retir')) {
      color = AppColors.error;
    } else {
      color = AppColors.textSecondary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        estado!,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
