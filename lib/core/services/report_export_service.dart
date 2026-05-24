import 'dart:io';

import 'package:excel/excel.dart' as xls;
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../constants/app_constants.dart';
import '../utils/logger.dart';

/// Servicio reutilizable para exportar reportes a PDF y Excel.
class ReportExportService {
  ReportExportService._();
  static final ReportExportService instance = ReportExportService._();

  static final _fechaFmt = DateFormat('dd/MM/yyyy HH:mm');
  static final _moneda = NumberFormat.currency(
    locale: 'es_PE',
    symbol: '${AppConstants.currencySymbol} ',
    decimalDigits: 2,
  );

  // ════════════════════════════════════════════════════════════
  // PDF
  // ════════════════════════════════════════════════════════════

  /// Genera un PDF con encabezado, tabla y totales.
  /// Permite al usuario imprimirlo o guardarlo desde el diálogo nativo.
  Future<void> exportarTablaPdf({
    required String titulo,
    String? subtitulo,
    required List<String> columnas,
    required List<List<String>> filas,
    List<MapEntry<String, String>>? totales,
    String? nombreArchivo,
  }) async {
    final doc = pw.Document();
    final ahora = _fechaFmt.format(DateTime.now());

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (ctx) => _pdfHeader(titulo, subtitulo, ahora),
        footer: (ctx) => _pdfFooter(ctx),
        build: (ctx) => [
          pw.SizedBox(height: 12),
          _pdfTabla(columnas, filas),
          if (totales != null && totales.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            _pdfTotales(totales),
          ],
        ],
      ),
    );

    final bytes = await doc.save();
    await _guardarOImprimirPdf(bytes, nombreArchivo ?? _slug(titulo));
  }

  /// Para previsualización + impresión directa (sin guardar).
  Future<void> imprimirPdf({
    required String titulo,
    String? subtitulo,
    required List<String> columnas,
    required List<List<String>> filas,
    List<MapEntry<String, String>>? totales,
  }) async {
    final doc = pw.Document();
    final ahora = _fechaFmt.format(DateTime.now());
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (ctx) => _pdfHeader(titulo, subtitulo, ahora),
        footer: (ctx) => _pdfFooter(ctx),
        build: (ctx) => [
          pw.SizedBox(height: 12),
          _pdfTabla(columnas, filas),
          if (totales != null && totales.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            _pdfTotales(totales),
          ],
        ],
      ),
    );
    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }

  pw.Widget _pdfHeader(String titulo, String? subtitulo, String ahora) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey400, width: 1),
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                AppConstants.appName,
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey600,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                titulo,
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('1A365D'),
                ),
              ),
              if (subtitulo != null)
                pw.Text(subtitulo,
                    style: const pw.TextStyle(
                        fontSize: 11, color: PdfColors.grey700)),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('Emitido',
                  style: const pw.TextStyle(
                      fontSize: 9, color: PdfColors.grey600)),
              pw.Text(ahora,
                  style: pw.TextStyle(
                      fontSize: 10, fontWeight: pw.FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _pdfFooter(pw.Context ctx) => pw.Container(
        alignment: pw.Alignment.centerRight,
        margin: const pw.EdgeInsets.only(top: 8),
        child: pw.Text(
          'Página ${ctx.pageNumber} de ${ctx.pagesCount}',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey),
        ),
      );

  pw.Widget _pdfTabla(List<String> columnas, List<List<String>> filas) {
    return pw.TableHelper.fromTextArray(
      headers: columnas,
      data: filas,
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
        fontSize: 10,
      ),
      headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('1A365D')),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellAlignment: pw.Alignment.centerLeft,
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      rowDecoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
        ),
      ),
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
    );
  }

  pw.Widget _pdfTotales(List<MapEntry<String, String>> totales) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        children: totales.map((t) {
          final esTotal = t.key.toUpperCase().contains('TOTAL');
          return pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 2),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(t.key,
                    style: pw.TextStyle(
                      fontSize: esTotal ? 12 : 10,
                      fontWeight: esTotal ? pw.FontWeight.bold : null,
                    )),
                pw.Text(t.value,
                    style: pw.TextStyle(
                      fontSize: esTotal ? 14 : 10,
                      fontWeight: pw.FontWeight.bold,
                      color: esTotal ? PdfColor.fromHex('1A365D') : null,
                    )),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // EXCEL
  // ════════════════════════════════════════════════════════════

  Future<void> exportarTablaExcel({
    required String titulo,
    required List<String> columnas,
    required List<List<String>> filas,
    List<MapEntry<String, String>>? totales,
    String? nombreArchivo,
  }) async {
    final excel = xls.Excel.createExcel();
    final hojaName = titulo.length > 28 ? titulo.substring(0, 28) : titulo;
    final hoja = excel[hojaName];
    excel.delete('Sheet1');

    // Título
    final tituloCell = hoja.cell(xls.CellIndex.indexByString('A1'));
    tituloCell.value = xls.TextCellValue(titulo);
    tituloCell.cellStyle = xls.CellStyle(
      bold: true,
      fontSize: 14,
      fontColorHex: xls.ExcelColor.fromHexString('#1A365D'),
    );
    hoja.merge(xls.CellIndex.indexByString('A1'),
        xls.CellIndex.indexByColumnRow(columnIndex: columnas.length - 1, rowIndex: 0));

    // Fecha
    hoja.cell(xls.CellIndex.indexByString('A2')).value =
        xls.TextCellValue('Emitido: ${_fechaFmt.format(DateTime.now())}');

    // Encabezados (fila 4)
    for (var i = 0; i < columnas.length; i++) {
      final c = hoja.cell(xls.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 3));
      c.value = xls.TextCellValue(columnas[i]);
      c.cellStyle = xls.CellStyle(
        bold: true,
        backgroundColorHex: xls.ExcelColor.fromHexString('#1A365D'),
        fontColorHex: xls.ExcelColor.fromHexString('#FFFFFF'),
        horizontalAlign: xls.HorizontalAlign.Center,
      );
    }

    // Filas
    for (var r = 0; r < filas.length; r++) {
      for (var c = 0; c < filas[r].length; c++) {
        hoja.cell(xls.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 4 + r)).value =
            xls.TextCellValue(filas[r][c]);
      }
    }

    // Totales
    if (totales != null && totales.isNotEmpty) {
      var fila = 5 + filas.length;
      for (final t in totales) {
        hoja.cell(xls.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: fila)).value =
            xls.TextCellValue(t.key);
        final valor = hoja.cell(xls.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: fila));
        valor.value = xls.TextCellValue(t.value);
        valor.cellStyle = xls.CellStyle(bold: true);
        fila++;
      }
    }

    final bytes = excel.save();
    if (bytes == null) {
      throw Exception('No se pudo generar el archivo Excel');
    }
    await _guardarExcel(bytes, nombreArchivo ?? _slug(titulo));
  }

  // ════════════════════════════════════════════════════════════
  // Guardado / apertura de archivos
  // ════════════════════════════════════════════════════════════

  Future<void> _guardarOImprimirPdf(List<int> bytes, String nombreArchivo) async {
    if (kIsWeb) {
      await Printing.sharePdf(bytes: Uint8List.fromList(bytes), filename: '$nombreArchivo.pdf');
      return;
    }
    final path = await getSaveLocation(
      suggestedName: '$nombreArchivo.pdf',
      acceptedTypeGroups: [
        const XTypeGroup(label: 'PDF', extensions: ['pdf']),
      ],
    );
    if (path == null) return;
    final file = File(path.path);
    await file.writeAsBytes(bytes);
    logger.i('PDF guardado en: ${file.path}');
    await OpenFile.open(file.path);
  }

  Future<void> _guardarExcel(List<int> bytes, String nombreArchivo) async {
    if (kIsWeb) {
      // En web descargar via printing como fallback
      logger.w('Excel en web no implementado todavía');
      return;
    }
    final path = await getSaveLocation(
      suggestedName: '$nombreArchivo.xlsx',
      acceptedTypeGroups: [
        const XTypeGroup(label: 'Excel', extensions: ['xlsx']),
      ],
    );
    if (path == null) return;
    final file = File(path.path);
    await file.writeAsBytes(bytes);
    logger.i('Excel guardado en: ${file.path}');
    await OpenFile.open(file.path);
  }

  // ════════════════════════════════════════════════════════════
  // Helpers
  // ════════════════════════════════════════════════════════════

  String _slug(String s) {
    final base = s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    final fecha = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    return '${base}_$fecha';
  }

  /// Default path donde se guardan los archivos si el usuario no elige.
  Future<String> getDefaultDownloadsPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }

  static String formatMoneda(num v) => _moneda.format(v);
}
