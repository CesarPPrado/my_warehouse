import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
        
        // Formatear fecha
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

  void _verDetalles(int auditoriaId, String area, String fecha) async {
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
              height: MediaQuery.of(context).size.height * 0.8,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Detalles: $area', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
                  Text(fecha, style: const TextStyle(color: Colors.grey)),
                  const Divider(color: Colors.grey),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(flex: 2, child: Text('Producto', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                        Expanded(flex: 1, child: Text('Físico', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
                        Expanded(flex: 1, child: Text('Se surtió', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
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
                              Expanded(flex: 2, child: Text(d['nombre_producto'], style: const TextStyle(color: Colors.grey, fontSize: 12))),
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

  Future<List<Map<String, dynamic>>> _obtenerDetallesBaseDatos(int id) async {
    final data = await Supabase.instance.client.from('auditoria_detalles').select().eq('auditoria_id', id);
    final prods = await Supabase.instance.client.from('productos').select('id, nombre');
    
    List<Map<String, dynamic>> res = [];
    for(var item in data) {
      final pIndex = prods.indexWhere((p) => p['id'] == item['producto_id']);
      res.add({
        'nombre_producto': pIndex != -1 ? prods[pIndex]['nombre'] : 'Desconocido',
        'existencia_fisica': item['existencia_fisica'],
        'cantidad_a_surtir': item['cantidad_a_surtir'],
      });
    }
    return res;
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
                        onTap: () => _verDetalles(aud['id'], aud['area'], aud['fecha']),
                      ),
                    );
                  },
                ),
    );
  }
}