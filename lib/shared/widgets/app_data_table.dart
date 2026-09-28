import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

export 'package:data_table_2/data_table_2.dart'
    show DataColumn2, DataRow2, ColumnSize;

/// Tabla estándar del sistema.
///
/// - Ocupa todo el ancho disponible y reparte columnas por tamaño (S/M/L).
/// - Si no cabe, aparece scroll horizontal en vez de "salirse" de la tarjeta.
/// - Scroll vertical propio: la página no crece con las filas.
/// - Cabecera fija, filas de 48 px, cebra suave.
class AppDataTable extends StatelessWidget {
  const AppDataTable({
    required this.columns,
    required this.rows,
    this.minWidth = 720,
    this.emptyMessage = 'Sin registros',
    super.key,
  });

  final List<DataColumn2> columns;
  final List<DataRow2> rows;

  /// Ancho mínimo antes de activar scroll horizontal.
  final double minWidth;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: DataTable2(
        columns: columns,
        rows: rows,
        minWidth: minWidth,
        columnSpacing: 16,
        horizontalMargin: 16,
        headingRowHeight: 44,
        dataRowHeight: 48,
        dividerThickness: 0.6,
        fixedTopRows: 1,
        isVerticalScrollBarVisible: true,
        isHorizontalScrollBarVisible: true,
        headingRowColor: const WidgetStatePropertyAll(AppColors.background),
        headingTextStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: AppColors.textSecondary,
        ),
        dataTextStyle:
            const TextStyle(fontSize: 13, color: AppColors.textPrimary),
        empty: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(emptyMessage,
                style: const TextStyle(color: AppColors.textSecondary)),
          ),
        ),
      ),
    );
  }
}

/// Etiqueta de estado ("Activo", "Pendiente", …) para celdas.
class AppEstadoChip extends StatelessWidget {
  const AppEstadoChip(this.texto, {required this.color, super.key});
  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          texto,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

/// Barra de paginación: "1–25 de 1046", tamaño de página y anterior/siguiente.
class AppPaginador extends StatelessWidget {
  const AppPaginador({
    required this.total,
    required this.pagina,
    required this.porPagina,
    required this.onPagina,
    required this.onPorPagina,
    this.opciones = const [25, 50, 100],
    super.key,
  });

  final int total;
  final int pagina; // base 0
  final int porPagina;
  final ValueChanged<int> onPagina;
  final ValueChanged<int> onPorPagina;
  final List<int> opciones;

  int get paginas => total == 0 ? 1 : ((total - 1) ~/ porPagina) + 1;

  @override
  Widget build(BuildContext context) {
    final desde = total == 0 ? 0 : pagina * porPagina + 1;
    final hasta = ((pagina + 1) * porPagina).clamp(0, total);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          const Text('Filas por página',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(width: 8),
          DropdownButton<int>(
            value: porPagina,
            isDense: true,
            underline: const SizedBox.shrink(),
            items: opciones
                .map((o) => DropdownMenuItem(value: o, child: Text('$o')))
                .toList(),
            onChanged: (v) => v == null ? null : onPorPagina(v),
          ),
          const Spacer(),
          Text(
            '$desde–$hasta de $total',
            style:
                const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          IconButton(
            tooltip: 'Anterior',
            icon: const Icon(Icons.chevron_left),
            onPressed: pagina > 0 ? () => onPagina(pagina - 1) : null,
          ),
          Text('${pagina + 1} / $paginas',
              style: const TextStyle(fontSize: 12)),
          IconButton(
            tooltip: 'Siguiente',
            icon: const Icon(Icons.chevron_right),
            onPressed: pagina < paginas - 1 ? () => onPagina(pagina + 1) : null,
          ),
        ],
      ),
    );
  }
}

/// Campo de búsqueda compacto para cabeceras de tabla.
class AppBuscador extends StatelessWidget {
  const AppBuscador({
    required this.controller,
    required this.onChanged,
    this.hint = 'Buscar…',
    this.width = 320,
    super.key,
  });
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hint;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search, size: 20),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
        ),
      ),
    );
  }
}
