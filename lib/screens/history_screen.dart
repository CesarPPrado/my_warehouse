import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  // Conexión en tiempo real a la tabla de movimientos, ordenados por ID descendente (los más nuevos arriba)
  final _movimientosStream = Supabase.instance.client
      .from('movimientos')
      .stream(primaryKey: ['id'])
      .order('id', ascending: false);

  // Diccionarios locales para traducir IDs a Nombres reales
  Map<int, String> _productosMap = {};
  Map<int, String> _unidadesMap = {};
  Map<int, String> _sucursalesMap = {};
  bool _isLoadingCatalogs = true;

  @override
  void initState() {
    super.initState();
    _cargarCatalogos();
  }

  // Descargamos las referencias para no mostrar solo números
  Future<void> _cargarCatalogos() async {
    try {
      final prods = await Supabase.instance.client.from('productos').select('id, nombre, unidad_medida');
      final sucs = await Supabase.instance.client.from('sucursales').select('id, nombre');

      final Map<int, String> pMap = {};
      final Map<int, String> uMap = {};
      final Map<int, String> sMap = {};

      for (var p in prods) {
        pMap[p['id'] as int] = p['nombre'].toString();
        uMap[p['id'] as int] = p['unidad_medida'].toString();
      }
      for (var s in sucs) {
        sMap[s['id'] as int] = s['nombre'].toString();
      }

      if (mounted) {
        setState(() {
          _productosMap = pMap;
          _unidadesMap = uMap;
          _sucursalesMap = sMap;
          _isLoadingCatalogs = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando catálogos: $e');
      if (mounted) setState(() => _isLoadingCatalogs = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Movimientos', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.grey.shade900,
        centerTitle: true,
      ),
      body: _isLoadingCatalogs
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<Map<String, dynamic>>>(
              stream: _movimientosStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(child: Text('Error al cargar historial', style: TextStyle(color: Colors.red)));
                }

                final movimientos = snapshot.data ?? [];

                if (movimientos.isEmpty) {
                  return const Center(child: Text('No hay movimientos registrados.', style: TextStyle(color: Colors.grey)));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: movimientos.length,
                  itemBuilder: (context, index) {
                    final mov = movimientos[index];
                    final isEntrada = mov['tipo_movimiento'] == 'Entrada';
                    
                    // Traducción segura: Si el producto fue borrado, mostramos "Desconocido"
                    final productoNombre = _productosMap[mov['producto_id']] ?? 'Producto Eliminado';
                    final unidad = _unidadesMap[mov['producto_id']] ?? 'unidades';
                    final origen = _sucursalesMap[mov['origen_id']] ?? 'N/A';
                    final destino = _sucursalesMap[mov['destino_id']] ?? 'N/A';
                    
                    // Formatear la fecha de Postgresql (cortar los decimales del tiempo)
                    String fecha = 'Fecha no disp.';
                    if (mov['created_at'] != null) {
                       fecha = mov['created_at'].toString().replaceAll('T', ' ').substring(0, 16);
                    }

                    return Card(
                      color: const Color(0xFF1A1A1A),
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isEntrada ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    mov['tipo_movimiento'],
                                    style: TextStyle(
                                      color: isEntrada ? Colors.greenAccent : Colors.redAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12
                                    ),
                                  ),
                                ),
                                Text(fecha, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              productoNombre,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Cantidad: ${mov['cantidad']} $unidad',
                              style: const TextStyle(fontSize: 14),
                            ),
                            const Divider(color: Colors.grey, height: 24),
                            Row(
                              children: [
                                const Icon(Icons.arrow_circle_up, color: Colors.grey, size: 16),
                                const SizedBox(width: 4),
                                Expanded(child: Text('Origen: $origen', style: const TextStyle(color: Colors.grey, fontSize: 12))),
                                const Icon(Icons.arrow_circle_down, color: Colors.grey, size: 16),
                                const SizedBox(width: 4),
                                Expanded(child: Text('Destino: $destino', style: const TextStyle(color: Colors.grey, fontSize: 12))),
                              ],
                            ),
                            // Mostrar factura y lote solo si existen
                            if (mov['factura'] != null || mov['lote'] != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Factura: ${mov['factura'] ?? 'N/A'} | Lote: ${mov['lote'] ?? 'N/A'}',
                                style: const TextStyle(color: Colors.blueGrey, fontSize: 12, fontStyle: FontStyle.italic),
                              ),
                            ]
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}