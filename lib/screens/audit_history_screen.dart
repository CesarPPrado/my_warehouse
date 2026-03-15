import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart';
import 'package:share_plus/share_plus.dart';

class AuditHistoryScreen extends StatefulWidget {
  const AuditHistoryScreen({super.key});

  @override
  State<AuditHistoryScreen> createState() => _AuditHistoryScreenState();
}

class _AuditHistoryScreenState extends State<AuditHistoryScreen> {
  List<Map<String, dynamic>> _auditorias = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarAuditorias();
  }

  Future<void> _cargarAuditorias() async {
    setState(() => _isLoading = true);
    try {
      final auds = await Supabase.instance.client.from('auditorias_cierre').select().order('fecha', ascending: false);
      final sucs = await Supabase.instance.client.from('sucursales').select('id, nombre');

      List<Map<String, dynamic>> listaTemporal = [];
      for (var a in auds) {
        final sIndex = sucs.indexWhere((s) => s['id'] == a['sucursal_id']);
        final nombreSucursal = sIndex != -1 ? sucs[sIndex]['nombre'] : 'Área Desconocida';
        
        String fechaF = 'Desconocida';
        if (a['fecha'] != null) {
          final DateTime dt = DateTime.parse(a['fecha']).toLocal();
          fechaF = "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} - ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
        }

        listaTemporal.add({
          'id': a['id'],
          'area': nombreSucursal,
          'fecha': fechaF,
          'produccion': a['produccion_reportada']?['texto'] ?? 'No reportada',
          'observaciones': a['observaciones'] ?? 'Ninguna',
        });
      }

      if (mounted) {
        setState(() {
          _auditorias = listaTemporal;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _obtenerDetallesBaseDatos(int id) async {
    final data = await Supabase.instance.client.from('auditoria_detalles').select().eq('auditoria_id', id);
    final prods = await Supabase.instance.client.from('productos').select('id, nombre');
    
    List<Map<String, dynamic>> res = [];
    for(var item in data) {
      final pIndex = prods.indexWhere((p) => p['id'] == item['producto_id']);
      res.add({
        'nombre_producto': pIndex != -1 ? prods[pIndex]['nombre'] : 'Desconocido',
        'stock_ideal': item['stock_ideal'] ?? 0,
        'existencia_fisica': item['existencia_fisica'],
        'cantidad_a_surtir': item['cantidad_a_surtir'],
      });
    }
    return res;
  }

  // --- MOTOR 1: GENERADOR DE PDF ---
  Future<void> _exportarPDF(String area, String fecha, String produccion, String observaciones, List<Map<String, dynamic>> detalles) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.letter,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Reporte de Cierre: $area', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Text('Fecha del reporte: $fecha', style: const pw.TextStyle(fontSize: 14)),
              pw.Text('Producción reportada: $produccion', style: const pw.TextStyle(fontSize: 14)),
              if (observaciones.isNotEmpty && observaciones != 'Ninguna') 
                pw.Text('Observaciones: $observaciones', style: const pw.TextStyle(fontSize: 14)),
              pw.SizedBox(height: 20),
              
              // Tabla estilo profesional
              pw.TableHelper.fromTextArray(
                headers: ['Descripción / Insumo', 'Stock (Meta)', 'Físico', 'A Surtir'],
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                cellAlignment: pw.Alignment.center,
                cellAlignments: {0: pw.Alignment.centerLeft}, // El nombre del producto a la izquierda
                data: detalles.map((d) => [
                  d['nombre_producto'],
                  d['stock_ideal'].toString(),
                  d['existencia_fisica'].toString(),
                  '+${d['cantidad_a_surtir']}'
                ]).toList(),
              ),
              pw.SizedBox(height: 40),
              pw.Divider(),
              pw.Center(child: pw.Text('Firma de Revisión', style: const pw.TextStyle(color: PdfColors.grey600))),
            ]
          );
        }
      )
    );

    final Uint8List bytes = await pdf.save();
    // Abrir el menú de compartir (WhatsApp, correo, etc.)
    await SharePlus.instance.share(
      ShareParams(
        text: 'Te comparto el reporte de cierre de $area.',
        files: [XFile.fromData(bytes, name: 'Cierre_${area}_$fecha.pdf', mimeType: 'application/pdf')],
      )
    );  }

  // --- MOTOR 2: GENERADOR DE EXCEL ---
  Future<void> _exportarExcel(String area, String fecha, String produccion, String observaciones, List<Map<String, dynamic>> detalles) async {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Reporte'];
    excel.setDefaultSheet('Reporte');

    // Encabezados del documento
    sheetObject.appendRow([TextCellValue('Reporte de Cierre: $area')]);
    sheetObject.appendRow([TextCellValue('Fecha: $fecha')]);
    sheetObject.appendRow([TextCellValue('Producción: $produccion')]);
    sheetObject.appendRow([TextCellValue('Observaciones: $observaciones')]);
    sheetObject.appendRow([TextCellValue('')]); // Fila en blanco

    // Encabezados de la tabla
    sheetObject.appendRow([
      TextCellValue('Descripción / Insumo'),
      TextCellValue('Stock (Meta)'),
      TextCellValue('Físico'),
      TextCellValue('A Surtir')
    ]);

    // Llenado de datos
    for (var d in detalles) {
      sheetObject.appendRow([
        TextCellValue(d['nombre_producto'].toString()),
        DoubleCellValue(double.tryParse(d['stock_ideal'].toString()) ?? 0.0),
        DoubleCellValue(double.tryParse(d['existencia_fisica'].toString()) ?? 0.0),
        DoubleCellValue(double.tryParse(d['cantidad_a_surtir'].toString()) ?? 0.0),
      ]);
    }

    // Usamos encode() en lugar de save() para evitar la descarga automática en web
    var fileBytes = excel.encode(); 
    if (fileBytes != null) {
      final Uint8List bytes = Uint8List.fromList(fileBytes);
      await SharePlus.instance.share(
        ShareParams(
          text: 'Te comparto el Excel de cierre de $area.',
          files: [XFile.fromData(bytes, name: 'Cierre_${area}_$fecha.xlsx', mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')],
        )
      );
    }
  }

  void _verDetalles(int auditoriaId, String area, String fecha, String produccion, String observaciones) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return FutureBuilder(
          future: _obtenerDetallesBaseDatos(auditoriaId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(height: 300, child: Center(child: CircularProgressIndicator()));
            }

            final detalles = snapshot.data ?? [];

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Detalles: $area', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
                            Text(fecha, style: const TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                      // BOTONES DE EXPORTACIÓN
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                            tooltip: 'Compartir como PDF',
                            onPressed: () => _exportarPDF(area, fecha, produccion, observaciones, detalles),
                          ),
                          IconButton(
                            icon: const Icon(Icons.table_chart, color: Colors.green),
                            tooltip: 'Compartir como Excel',
                            onPressed: () => _exportarExcel(area, fecha, produccion, observaciones, detalles),
                          ),
                        ],
                      )
                    ],
                  ),
                  const Divider(color: Colors.grey),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(flex: 3, child: Text('Producto', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                        Expanded(flex: 1, child: Text('Meta', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                        Expanded(flex: 1, child: Text('Físico', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                        Expanded(flex: 1, child: Text('Surtió', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: detalles.length,
                      itemBuilder: (context, index) {
                        final d = detalles[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Expanded(flex: 3, child: Text(d['nombre_producto'], style: const TextStyle(color: Colors.grey, fontSize: 12))),
                              Expanded(flex: 1, child: Text(d['stock_ideal'].toString(), textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 12))),
                              Expanded(flex: 1, child: Text(d['existencia_fisica'].toString(), textAlign: TextAlign.center, style: const TextStyle(color: Colors.yellowAccent, fontWeight: FontWeight.bold))),
                              Expanded(flex: 1, child: Text('+${d['cantidad_a_surtir']}', textAlign: TextAlign.right, style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold))),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historial de Cierres', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.cyan.shade900),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _auditorias.isEmpty
              ? const Center(child: Text('No hay cierres registrados', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _auditorias.length,
                  itemBuilder: (context, index) {
                    final aud = _auditorias[index];
                    return Card(
                      color: const Color(0xFF1A1A1A),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const Icon(Icons.assignment_turned_in, color: Colors.cyanAccent),
                        title: Text('Cierre: ${aud['area']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${aud['fecha']}\nProd: ${aud['produccion']}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        isThreeLine: true,
                        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                        onTap: () => _verDetalles(aud['id'], aud['area'], aud['fecha'], aud['produccion'], aud['observaciones']),
                      ),
                    );
                  },
                ),
    );
  }
}