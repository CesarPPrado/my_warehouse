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
      .order('categoria', ascending: true) 
      .order('nombre', ascending: true);

  // --- CONTROLADORES DEL BUSCADOR ---
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestionar Productos', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green.shade800, 
      ),
      body: Column(
        children: [
          // --- NUESTRO NUEVO BUSCADOR VISUAL ---
          Container(
            color: const Color(0xFF1A1A1A),
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Buscar producto...',
                hintStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.search, color: Colors.greenAccent),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF2A2A2A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),

          // --- LISTA EN TIEMPO REAL FILTRADA ---
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _productosStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(child: Text('Error al cargar productos', style: TextStyle(color: Colors.red)));
                }

                final productos = snapshot.data ?? [];
                
                // Aplicamos el filtro mágico aquí mismo
                final productosFiltrados = _searchQuery.isEmpty 
                    ? productos 
                    : productos.where((p) => p['nombre'].toString().toLowerCase().contains(_searchQuery)).toList();

                if (productosFiltrados.isEmpty) {
                  return Center(
                    child: Text(
                      _searchQuery.isEmpty ? 'No hay productos registrados.' : 'No se encontraron resultados.',
                      style: const TextStyle(color: Colors.grey)
                    )
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: productosFiltrados.length,
                  itemBuilder: (context, index) {
                    final producto = productosFiltrados[index];
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
                                Navigator.push(context, MaterialPageRoute(
                                  builder: (context) => ProductFormScreen(productoAEditar: producto)
                                ));
                              },
                            ),
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
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const ProductFormScreen()));
        },
        backgroundColor: Colors.green,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

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
            onPressed: () => Navigator.pop(context, false), 
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Eliminar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
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