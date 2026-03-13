import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'recipe_form_screen.dart';

class ManageRecipesScreen extends StatefulWidget {
  const ManageRecipesScreen({super.key});

  @override
  State<ManageRecipesScreen> createState() => _ManageRecipesScreenState();
}

class _ManageRecipesScreenState extends State<ManageRecipesScreen> {
  List<Map<String, dynamic>> _recetasCompletas = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarRecetas();
  }

  Future<void> _cargarRecetas() async {
    setState(() => _isLoading = true);
    try {
      // 1. Descargamos las recetas
      final recetas = await Supabase.instance.client.from('recetas').select();
      // 2. Descargamos los productos para saber el nombre del Kit
      final productos = await Supabase.instance.client.from('productos').select('id, nombre');

      // 3. Unimos los datos para la pantalla
      List<Map<String, dynamic>> listaUnida = [];
      for (var r in recetas) {
        final prodInfo = productos.firstWhere((p) => p['id'] == r['producto_resultante_id'], orElse: () => {'nombre': 'Producto Eliminado'});
        listaUnida.add({
          'id': r['id'],
          'tipo_receta': r['tipo_receta'],
          'producto_resultante_id': r['producto_resultante_id'],
          'nombre_producto': prodInfo['nombre'],
        });
      }

      if (mounted) setState(() => _recetasCompletas = listaUnida);
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _eliminarReceta(int idReceta, int idProducto) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('¿Eliminar Fórmula?', style: TextStyle(color: Colors.white)),
        content: const Text('Esto eliminará la receta y el producto del catálogo. ¿Estás seguro?', style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // Al borrar la receta, la base de datos borra los ingredientes automáticamente por el "ON DELETE CASCADE" que configuramos
      await Supabase.instance.client.from('recetas').delete().eq('id', idReceta);
      // También borramos el producto (Kit) del catálogo
      await Supabase.instance.client.from('productos').delete().eq('id', idProducto);
      _cargarRecetas(); // Recargamos la lista
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gestión de Fórmulas y Kits', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.orange.shade800),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _recetasCompletas.isEmpty
              ? const Center(child: Text('No hay fórmulas registradas', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _recetasCompletas.length,
                  itemBuilder: (context, index) {
                    final item = _recetasCompletas[index];
                    return Card(
                      color: const Color(0xFF1A1A1A),
                      child: ListTile(
                        leading: CircleAvatar(backgroundColor: Colors.orange.withValues(alpha: 0.2), child: const Icon(Icons.science, color: Colors.orangeAccent)),
                        title: Text(item['nombre_producto'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Tipo: ${item['tipo_receta']}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blueAccent),
                              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RecipeFormScreen(recetaAEditar: item))).then((_) => _cargarRecetas()),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.redAccent),
                              onPressed: () => _eliminarReceta(item['id'], item['producto_resultante_id']),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.orange.shade800,
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RecipeFormScreen())).then((_) => _cargarRecetas()),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}