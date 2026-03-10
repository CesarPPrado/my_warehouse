import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'location_form_screen.dart';

class ManageLocationsScreen extends StatefulWidget {
  final String titulo;
  final bool esProveedor; // Esta variable decidirá qué datos mostrar

  const ManageLocationsScreen({super.key, required this.titulo, required this.esProveedor});

  @override
  State<ManageLocationsScreen> createState() => _ManageLocationsScreenState();
}

class _ManageLocationsScreenState extends State<ManageLocationsScreen> {
  late final Stream<List<Map<String, dynamic>>> _sucursalesStream;

  @override
  void initState() {
    super.initState();
    // Filtramos la consulta a Supabase dependiendo del botón que presionaste
    if (widget.esProveedor) {
      _sucursalesStream = Supabase.instance.client.from('sucursales').stream(primaryKey: ['id']).eq('tipo', 'Proveedor').order('nombre');
    } else {
      _sucursalesStream = Supabase.instance.client.from('sucursales').stream(primaryKey: ['id']).inFilter('tipo', ['Bodega', 'Sucursal', 'Producción']).order('nombre');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Usamos el color morado si es proveedor, o azul si es sucursal
    final colorTema = widget.esProveedor ? Colors.purple : Colors.blue;

    return Scaffold(
      appBar: AppBar(title: Text(widget.titulo, style: const TextStyle(fontWeight: FontWeight.bold)), backgroundColor: colorTema.shade800),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _sucursalesStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: colorTema));
          final sucursales = snapshot.data ?? [];
          
          if (sucursales.isEmpty) return const Center(child: Text('No hay registros.', style: TextStyle(color: Colors.grey)));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sucursales.length,
            itemBuilder: (context, index) {
              final suc = sucursales[index];
              return Card(
                color: const Color(0xFF1A1A1A),
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  title: Text(suc['nombre'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Tipo: ${suc['tipo']}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit, color: colorTema), 
                        onPressed: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => LocationFormScreen(
                            sucursalAEditar: suc, 
                            esProveedor: widget.esProveedor
                          )
                        ))
                      ),
                      IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: () async { await Supabase.instance.client.from('sucursales').delete().eq('id', suc['id']); }),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: colorTema, 
        onPressed: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => LocationFormScreen(
            esProveedor: widget.esProveedor
          )
        )), 
        child: const Icon(Icons.add, color: Colors.white)
      ),
    );
  }
}