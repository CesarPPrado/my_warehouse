import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ManageProductsScreen extends StatefulWidget {
  const ManageProductsScreen({super.key});

  @override
  State<ManageProductsScreen> createState() => _ManageProductsScreenState();
}

class _ManageProductsScreenState extends State<ManageProductsScreen> {
  final _productosStream = Supabase.instance.client
      .from('productos')
      .stream(primaryKey: ['id'])
      .order('categoria', ascending: true) // Los agrupamos por categoría
      .order('nombre', ascending: true);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestionar Productos', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green.shade800, // Color para identificar que es modo administrador
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _productosStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Error al cargar productos', style: TextStyle(color: Colors.red)));
          }

          final productos = snapshot.data ?? [];

          if (productos.isEmpty) {
            return const Center(child: Text('No hay productos registrados.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: productos.length,
            itemBuilder: (context, index) {
              final producto = productos[index];
              return Card(
                color: const Color(0xFF1A1A1A),
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  title: Text(producto['nombre'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Categoría: ${producto['categoria']} | Medida: ${producto['unidad_medida']}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blueAccent),
                        onPressed: () {
                          debugPrint('Abrir formulario para editar: ${producto['nombre']}');
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: () {
                          debugPrint('Confirmar eliminación de: ${producto['nombre']}');
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          debugPrint('Abrir formulario de nuevo producto');
        },
        backgroundColor: Colors.greenAccent,
        icon: const Icon(Icons.add, color: Colors.black),
        label: const Text('Nuevo Producto', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
    );
  }
}