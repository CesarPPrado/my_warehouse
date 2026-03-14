import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _movimientosMapeados = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarHistorial();
  }

  @override
  void didUpdateWidget(HistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _cargarHistorial(); 
  }

  Future<void> _cargarHistorial() async {
    if (!mounted) return;
    
    // Forzamos la animación de carga para que el usuario sepa que está actualizando
    setState(() => _isLoading = true);

    try {
      final movs = await Supabase.instance.client.from('movimientos').select().order('fecha_movimiento', ascending: false);
      final prods = await Supabase.instance.client.from('productos').select('id, nombre');
      final provs = await Supabase.instance.client.from('proveedores').select('id, nombre');
      final sucs = await Supabase.instance.client.from('sucursales').select('id, nombre');

      List<Map<String, dynamic>> listaTemporal = [];

      for (var m in movs) {
        final pIndex = prods.indexWhere((p) => p['id'] == m['producto_id']);
        final nombreProd = pIndex != -1 ? prods[pIndex]['nombre'] : 'Producto Eliminado/Desconocido';

        String origen = 'Almacén Principal';
        String destino = 'Almacén Principal';

        if (m['tipo_movimiento'] == 'Entrada') {
          if (m['origen_id'] != null) {
            final provIndex = provs.indexWhere((p) => p['id'] == m['origen_id']);
            if (provIndex != -1) origen = provs[provIndex]['nombre'];
          }
        } else if (m['tipo_movimiento'] == 'Salida') {
          final destId = m['sucursal_id'] ?? m['destino_id']; 
          if (destId != null) {
            final sIndex = sucs.indexWhere((s) => s['id'] == destId);
            if (sIndex != -1) destino = sucs[sIndex]['nombre'];
          }
        }

        String fechaF = 'Fecha no disp.';
        if (m['fecha_movimiento'] != null) {
          final DateTime dt = DateTime.parse(m['fecha_movimiento']).toLocal();
          fechaF = "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} - ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
        }

        listaTemporal.add({
          'id': m['id'],
          'tipo': m['tipo_movimiento'],
          'producto': nombreProd,
          'cantidad': m['cantidad'],
          'origen': origen,
          'destino': destino,
          'fecha': fechaF,
        });
      }

      if (mounted) {
        setState(() {
          _movimientosMapeados = listaTemporal;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando historial: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Movimientos', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1A1A1A),
        actions: [
          // --- AQUÍ ESTÁ EL NUEVO BOTÓN DE RECARGA MANUAL ---
          IconButton(
            icon: const Icon(Icons.refresh, color: Color.fromARGB(255, 255, 255, 255)),
            tooltip: 'Actualizar historial',
            onPressed: _cargarHistorial,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        color: Colors.white,
        backgroundColor: Colors.purpleAccent,
        onRefresh: _cargarHistorial,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _movimientosMapeados.isEmpty
                ? Stack(
                    children: [
                      ListView(),
                      const Center(child: Text('Aún no hay movimientos registrados', style: TextStyle(color: Colors.grey))),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _movimientosMapeados.length,
                    itemBuilder: (context, index) {
                      final item = _movimientosMapeados[index];
                      final bool esEntrada = item['tipo'] == 'Entrada';

                      return Card(
                        color: const Color(0xFF1A1A1A),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: esEntrada ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      item['tipo'],
                                      style: TextStyle(color: esEntrada ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ),
                                  Text(item['fecha'], style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(item['producto'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 4),
                              Text('Cantidad: ${item['cantidad']}', style: const TextStyle(color: Colors.white70)),
                              const Divider(color: Colors.grey, height: 24),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Origen', style: TextStyle(color: Colors.grey, fontSize: 10)),
                                        Text(item['origen'], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        const Text('Destino', style: TextStyle(color: Colors.grey, fontSize: 10)),
                                        Text(item['destino'], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.right),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}