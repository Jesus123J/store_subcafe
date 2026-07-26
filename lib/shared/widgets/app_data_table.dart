import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// Wrapper moderno para listar filas en formato tabla. Reemplaza al
/// DataTable de Material (que no ocupa el ancho completo) con un layout
/// custom basado en Row + Divider que si lo hace y luce mas limpio.
///
/// Uso:
/// ```dart
/// AppDataTable(
///   searchController: _busqueda,
///   onSearchChanged: () => setState(() {}),
///   totalItems: productos.length,
///   filteredItems: filtrados.length,
///   columns: const [
///     AppTableColumn(label: 'Codigo', width: 100),
///     AppTableColumn(label: 'Descripcion', flex: 3),
///     AppTableColumn(label: 'Stock', width: 90, align: TextAlign.right),
///   ],
///   rows: filtrados.map((p) => AppTableRow(
///     cells: [
///       Text(p.codigo),
///       Text(p.descripcion),
///       Text('${p.stock}'),
///     ],
///   )).toList(),
/// )
/// ```
class AppDataTable extends StatelessWidget {
  const AppDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.searchController,
    this.onSearchChanged,
    this.searchHint,
    this.totalItems,
    this.filteredItems,
    this.emptyMessage = 'No hay resultados',
  });

  final List<AppTableColumn> columns;
  final List<AppTableRow> rows;
  final TextEditingController? searchController;
  final VoidCallback? onSearchChanged;
  final String? searchHint;
  final int? totalItems;
  final int? filteredItems;
  final String emptyMessage;

  bool get _hasSearch => searchController != null;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_hasSearch) _buildSearchHeader(),
          if (_hasSearch)
            const Divider(height: 1, color: AppColors.border),
          _buildTableHeader(),
          Expanded(
            child: rows.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        emptyMessage,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const Divider(
                      height: 1,
                      color: AppColors.border,
                    ),
                    itemBuilder: (_, i) => _buildRow(rows[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: searchController,
              onChanged: (_) => onSearchChanged?.call(),
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: searchHint ?? 'Buscar...',
                prefixIcon:
                    const Icon(Icons.search, color: AppColors.textSecondary),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
          ),
          if (totalItems != null && filteredItems != null) ...[
            const SizedBox(width: 16),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$filteredItems de $totalItems',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      color: AppColors.background,
      child: Row(
        children: columns.map(_wrapColumn).toList(),
      ),
    );
  }

  Widget _buildRow(AppTableRow row) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      color: Colors.white,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(columns.length, (i) {
          final col = columns[i];
          final cell = i < row.cells.length
              ? row.cells[i]
              : const SizedBox.shrink();
          return _wrapChildToColumn(col, cell);
        }),
      ),
    );
  }

  Widget _wrapColumn(AppTableColumn col) {
    final headerText = Text(
      col.label,
      textAlign: col.align,
      style: const TextStyle(
        color: AppColors.primary,
        fontWeight: FontWeight.w700,
        fontSize: 12,
        letterSpacing: 0.4,
      ),
    );
    if (col.flex != null) {
      return Expanded(flex: col.flex!, child: headerText);
    }
    return SizedBox(width: col.width, child: headerText);
  }

  Widget _wrapChildToColumn(AppTableColumn col, Widget child) {
    Widget aligned = child;
    if (col.align == TextAlign.right) {
      aligned = Align(alignment: Alignment.centerRight, child: child);
    } else if (col.align == TextAlign.center) {
      aligned = Align(alignment: Alignment.center, child: child);
    }
    if (col.flex != null) {
      return Expanded(flex: col.flex!, child: aligned);
    }
    return SizedBox(width: col.width, child: aligned);
  }
}

class AppTableColumn {
  const AppTableColumn({
    required this.label,
    this.width,
    this.flex,
    this.align = TextAlign.left,
  }) : assert(width != null || flex != null,
            'AppTableColumn requiere width o flex');

  final String label;
  final double? width;
  final int? flex;
  final TextAlign align;
}

class AppTableRow {
  const AppTableRow({required this.cells});
  final List<Widget> cells;
}

/// Badge de estado consistente en todo el sistema.
/// Uso: `AppBadge(label: 'Activo', color: AppColors.secondary)`
class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// Card compacto de estadistica para el header del listado.
class AppStatTile extends StatelessWidget {
  const AppStatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
