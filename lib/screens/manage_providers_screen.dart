import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ManageProvidersScreen extends StatefulWidget {
  const ManageProvidersScreen({super.key});

  @override
  State<ManageProvidersScreen> createState() => _ManageProvidersScreenState();
}

class _ManageProvidersScreenState extends State<ManageProvidersScreen> {
  List<dynamic> _proveedores = [];
  List<dynamic> _proveedoresFiltrados = []; // <--- NUEVA LISTA PARA EL BUSCADOR
  
  final TextEditingController _searchController = TextEditingController(); // <--- CONTROLADOR DEL BUSCADOR
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarProveedores();
  }

  Future<void> _cargarProveedores() async {
    setState(() => _isLoading = true);
    try {
      final data = await Supabase.instance.client
          .from('proveedores')
          .select()
          .order('nombre');
      
      if (mounted) {
        setState(() {
          _proveedores = data;
          _proveedoresFiltrados = data; // Al inicio, mostramos todos
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- NUEVA FUNCIÓN QUE FILTRA EN TIEMPO REAL ---
  void _filtrarBusqueda(String query) {
    if (query.isEmpty) {
      setState(() => _proveedoresFiltrados = _proveedores);
    } else {
      setState(() {
        _proveedoresFiltrados = _proveedores.where((prov) {
          final nombre = prov['nombre'].toString().toLowerCase();
          final busqueda = query.toLowerCase();
          return nombre.contains(busqueda);
        }).toList();
      });
    }
  }

  Future<void> _eliminarProveedor(int id) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('Eliminar Proveedor', style: TextStyle(color: Colors.white)),
        content: const Text('¿Estás seguro de que deseas eliminar este proveedor?', style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      await Supabase.instance.client.from('proveedores').delete().eq('id', id);
      _cargarProveedores();
      _searchController.clear(); // Limpiamos el buscador al borrar
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Proveedor eliminado'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  void _mostrarFormulario([Map<String, dynamic>? proveedorAEditar]) {
    final nombreController = TextEditingController(text: proveedorAEditar?['nombre'] ?? '');
    final telefonoController = TextEditingController(text: proveedorAEditar?['telefono'] ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 24, left: 24, right: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(proveedorAEditar == null ? 'Nuevo Proveedor' : 'Editar Proveedor', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.purpleAccent)),
              const SizedBox(height: 16),
              TextField(
                controller: nombreController,
                decoration: InputDecoration(labelText: 'Nombre del Proveedor *', filled: true, fillColor: const Color(0xFF2A2A2A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: telefonoController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(labelText: 'Teléfono (Opcional)', filled: true, fillColor: const Color(0xFF2A2A2A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade600, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () async {
                    if (nombreController.text.trim().isEmpty) return;
                    
                    try {
                      if (proveedorAEditar == null) {
                        await Supabase.instance.client.from('proveedores').insert({
                          'nombre': nombreController.text.trim(),
                          'telefono': telefonoController.text.trim(),
                          'tipo': 'Proveedor'
                        });
                      } else {
                        await Supabase.instance.client.from('proveedores').update({
                          'nombre': nombreController.text.trim(),
                          'telefono': telefonoController.text.trim(),
                        }).eq('id', proveedorAEditar['id']);
                      }
                      if (!context.mounted) return; {
                        Navigator.pop(context);
                        _cargarProveedores();
                        _searchController.clear(); // Limpiamos buscador al guardar
                      }
                    } catch (e) {
                      debugPrint('Error guardando: $e');
                    }
                  },
                  child: Text(proveedorAEditar == null ? 'Guardar' : 'Actualizar', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Proveedores Externos', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.purple.shade800),
      body: Column(
        children: [
          // --- NUESTRO NUEVO BUSCADOR VISUAL ---
          Container(
            color: const Color(0xFF1A1A1A),
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              onChanged: _filtrarBusqueda,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Buscar proveedor...',
                hintStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.search, color: Colors.purpleAccent),
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
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          
          // --- LA LISTA QUE AHORA DEPENDE DE _proveedoresFiltrados ---
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _proveedoresFiltrados.isEmpty
                    ? Center(
                        child: Text(
                          _searchController.text.isEmpty 
                            ? 'No hay proveedores registrados.' 
                            : 'No se encontraron resultados.', 
                          style: const TextStyle(color: Colors.grey)
                        )
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _proveedoresFiltrados.length,
                        itemBuilder: (context, index) {
                          final prov = _proveedoresFiltrados[index];
                          return Card(
                            color: const Color(0xFF1A1A1A),
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(prov['nombre'], style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(prov['telefono']?.toString().isNotEmpty == true ? 'Tel: ${prov['telefono']}' : 'Sin teléfono', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(icon: const Icon(Icons.edit, color: Colors.purpleAccent), onPressed: () => _mostrarFormulario(prov)),
                                  IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: () => _eliminarProveedor(prov['id'])),
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
        backgroundColor: Colors.purple.shade600,
        onPressed: () => _mostrarFormulario(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}