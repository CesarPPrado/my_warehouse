import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ManageLocationsScreen extends StatefulWidget {
  // ¡Fíjate cómo aquí ya borramos el esProveedor y el titulo! Ya no los necesita.
  const ManageLocationsScreen({super.key});

  @override
  State<ManageLocationsScreen> createState() => _ManageLocationsScreenState();
}

class _ManageLocationsScreenState extends State<ManageLocationsScreen> {
  List<dynamic> _sucursales = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarSucursales();
  }

  Future<void> _cargarSucursales() async {
    setState(() => _isLoading = true);
    try {
      final data = await Supabase.instance.client
          .from('sucursales')
          .select()
          .order('nombre');
      
      if (mounted) {
        setState(() {
          _sucursales = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _eliminarSucursal(int id) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('Eliminar Registro', style: TextStyle(color: Colors.white)),
        content: const Text('¿Estás seguro de que deseas eliminar esta sucursal/área?', style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      await Supabase.instance.client.from('sucursales').delete().eq('id', id);
      _cargarSucursales();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registro eliminado'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  void _mostrarFormulario([Map<String, dynamic>? sucursalAEditar]) {
    final nombreController = TextEditingController(text: sucursalAEditar?['nombre'] ?? '');
    String tipoSeleccionado = sucursalAEditar?['tipo'] ?? 'Sucursal';
    final List<String> opcionesTipo = ['Sucursal', 'Bodega', 'Producción'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        // Usamos StatefulBuilder para que el Dropdown pueda actualizar la pantalla solo dentro del panel
        return StatefulBuilder( 
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 24, left: 24, right: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(sucursalAEditar == null ? 'Nueva Sucursal / Área' : 'Editar Sucursal / Área', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nombreController,
                    decoration: InputDecoration(labelText: 'Nombre *', filled: true, fillColor: const Color(0xFF2A2A2A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: tipoSeleccionado,
                    decoration: InputDecoration(labelText: 'Tipo *', filled: true, fillColor: const Color(0xFF2A2A2A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)),
                    items: opcionesTipo.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (val) {
                      if (val != null) setModalState(() => tipoSeleccionado = val);
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade600, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: () async {
                        if (nombreController.text.trim().isEmpty) return;
                        
                        try {
                          if (sucursalAEditar == null) {
                            await Supabase.instance.client.from('sucursales').insert({
                              'nombre': nombreController.text.trim(),
                              'tipo': tipoSeleccionado
                            });
                          } else {
                            await Supabase.instance.client.from('sucursales').update({
                              'nombre': nombreController.text.trim(),
                              'tipo': tipoSeleccionado,
                            }).eq('id', sucursalAEditar['id']);
                          }
                          if (!context.mounted) return; {
                            Navigator.pop(context);
                            _cargarSucursales();
                          }
                        } catch (e) {
                          debugPrint('Error guardando: $e');
                        }
                      },
                      child: Text(sucursalAEditar == null ? 'Guardar' : 'Actualizar', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sucursales y Areas', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.blue.shade800),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sucursales.isEmpty
              ? const Center(child: Text('No hay registros de áreas.', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _sucursales.length,
                  itemBuilder: (context, index) {
                    final suc = _sucursales[index];
                    return Card(
                      color: const Color(0xFF1A1A1A),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Icon(
                          suc['tipo'] == 'Bodega' ? Icons.warehouse : (suc['tipo'] == 'Producción' ? Icons.precision_manufacturing : Icons.storefront),
                          color: Colors.blueAccent
                        ),
                        title: Text(suc['nombre'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Tipo: ${suc['tipo'] ?? 'N/A'}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.edit, color: Colors.blueAccent), onPressed: () => _mostrarFormulario(suc)),
                            IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: () => _eliminarSucursal(suc['id'])),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blue.shade600,
        onPressed: () => _mostrarFormulario(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}