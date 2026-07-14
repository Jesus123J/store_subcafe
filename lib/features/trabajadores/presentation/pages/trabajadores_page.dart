import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../shared/widgets/app_async_value.dart';
import '../../../../shared/widgets/app_card.dart';
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
                t.nombreCompleto.toLowerCase().contains(q);
          }).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: AppCard(
        margin: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: AppColors.info.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.link, size: 18, color: AppColors.info),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${widget.trabajadores.length} trabajadores en vivo desde FinantialTracker. '
                      'Los abonos, préstamos y altas/bajas se administran allá.',
                      style: const TextStyle(
                          color: AppColors.textPrimary, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            TextField(
              controller: _busquedaCtrl,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Buscar por DNI o nombre...',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: DataTable(
                  columnSpacing: 24,
                  headingRowColor:
                      WidgetStateProperty.all(AppColors.background),
                  columns: const [
                    DataColumn(label: Text('DNI')),
                    DataColumn(label: Text('Nombre completo')),
                  ],
                  rows: filtrados
                      .map((t) => DataRow(cells: [
                            DataCell(Text(
                              t.dni,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                color: AppColors.textPrimary,
                              ),
                            )),
                            DataCell(Text(
                              t.nombreCompleto,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            )),
                          ]))
                      .toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
