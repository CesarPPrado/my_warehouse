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
  List<Map<String, dynamic>> _recetasFiltradas = []; // <--- NUEVA LISTA
  
  final TextEditingController _searchController = TextEditingController(); // <--- CONTROLADOR
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarRecetas();
  }

  Future<void> _cargarRecetas() async {
    setState(() => _isLoading = true);
    try {
      final recetas = await Supabase.instance.client.from('recetas').select();
      final productos = await Supabase.instance.client.from('productos').select('id, nombre');

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

      // Ordenamos alfabéticamente para que se vea más limpio
      listaUnida.sort((a, b) => a['nombre_producto'].toString().compareTo(b['nombre_producto'].toString()));

      if (mounted) {
        setState(() {
          _recetasCompletas = listaUnida;
          _recetasFiltradas = listaUnida;
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- EL MOTOR DE BÚSQUEDA ---
  void _filtrarBusqueda(String query) {
    if (query.isEmpty) {
      setState(() => _recetasFiltradas = _recetasCompletas);
    } else {
      setState(() {
        _recetasFiltradas = _recetasCompletas.where((receta) {
          final nombre = receta['nombre_producto'].toString().toLowerCase();
          return nombre.contains(query.toLowerCase());
        }).toList();
      });
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
      await Supabase.instance.client.from('recetas').delete().eq('id', idReceta);
      await Supabase.instance.client.from('productos').delete().eq('id', idProducto);
      _cargarRecetas(); 
      _searchController.clear(); // Limpiamos buscador al borrar
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gestión de Fórmulas y Kits', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.orange.shade800),
      body: Column(
        children: [
          // --- BARRA DE BÚSQUEDA ---
          Container(
            color: const Color(0xFF1A1A1A),
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              onChanged: _filtrarBusqueda,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Buscar fórmula o kit...',
                hintStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.search, color: Colors.orangeAccent),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          _filtrarBusqueda('');
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

          // --- LISTA FILTRADA ---
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _recetasFiltradas.isEmpty
                    ? Center(
                        child: Text(
                          _searchController.text.isEmpty 
                            ? 'No hay fórmulas registradas' 
                            : 'No se encontraron resultados.', 
                          style: const TextStyle(color: Colors.grey)
                        )
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _recetasFiltradas.length,
                        itemBuilder: (context, index) {
                          final item = _recetasFiltradas[index];
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
                                    onPressed: () {
                                      Navigator.push(context, MaterialPageRoute(builder: (_) => RecipeFormScreen(recetaAEditar: item))).then((_) {
                                        _cargarRecetas();
                                        _searchController.clear();
                                      });
                                    } 
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
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.orange.shade800,
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const RecipeFormScreen())).then((_) {
            _cargarRecetas();
            _searchController.clear();
          });
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}