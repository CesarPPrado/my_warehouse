import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'product_form_screen.dart';

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
                      // BOTÓN EDITAR
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blueAccent),
                        onPressed: () {
                          // Navegamos al formulario pasándole toda la información del producto
                          Navigator.push(context, MaterialPageRoute(
                            builder: (context) => ProductFormScreen(productoAEditar: producto)
                          ));
                        },
                      ),
                      // BOTÓN ELIMINAR
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: () => _confirmarEliminacion(producto['id'], producto['nombre']),
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
          // Aquí conectamos el botón con el formulario
          Navigator.push(context, MaterialPageRoute(builder: (context) => const ProductFormScreen()));
        },
        backgroundColor: Colors.greenAccent,
        icon: const Icon(Icons.add, color: Colors.black),
        label: const Text('Nuevo Producto', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
    );
  }

// NUEVA FUNCIÓN: Cuadro de diálogo y borrado en Supabase
  Future<void> _confirmarEliminacion(int id, String nombre) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('¿Eliminar Insumo?'),
        content: Text('Estás a punto de borrar "$nombre". Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), // Cierra y regresa falso
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true), // Cierra y regresa verdadero
            child: const Text('Eliminar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    // Si el usuario presionó "Eliminar" en el cuadro de diálogo
    if (confirmar == true) {
      try {
        // Ejecutamos la orden DELETE en la nube
        await Supabase.instance.client.from('productos').delete().eq('id', id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Producto eliminado'), backgroundColor: Colors.redAccent));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al eliminar: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }
}