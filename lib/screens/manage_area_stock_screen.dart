import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ManageAreaStockScreen extends StatefulWidget {
  const ManageAreaStockScreen({super.key});

  @override
  State<ManageAreaStockScreen> createState() => _ManageAreaStockScreenState();
}

class _ManageAreaStockScreenState extends State<ManageAreaStockScreen> {
  List<dynamic> _sucursales = [];
  List<dynamic> _productos = [];
  List<Map<String, dynamic>> _stockIdealList = [];
  
  dynamic _sucursalSeleccionada;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarDatosBase();
  }

  Future<void> _cargarDatosBase() async {
    try {
      // Descargamos las sucursales (filtrando preferentemente las de Producción, pero traemos todas por si acaso)
      final sucs = await Supabase.instance.client.from('sucursales').select('id, nombre, tipo').order('nombre');
      // Descargamos los productos para el buscador
      final prods = await Supabase.instance.client.from('productos').select('id, nombre, unidad_medida').order('nombre');
      
      if (mounted) {
        setState(() {
          _sucursales = sucs;
          _productos = prods;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando catálogos: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cargarStockDeSucursal(dynamic sucursalId) async {
    if (sucursalId == null) return;
    setState(() => _isLoading = true);

    try {
      final stockData = await Supabase.instance.client
          .from('stock_ideal_areas')
          .select()
          .eq('sucursal_id', sucursalId);

      List<Map<String, dynamic>> listaMapeada = [];
      for (var item in stockData) {
        final pIndex = _productos.indexWhere((p) => p['id'] == item['producto_id']);
        if (pIndex != -1) {
          listaMapeada.add({
            'id': item['id'],
            'producto_id': item['producto_id'],
            'nombre_producto': _productos[pIndex]['nombre'],
            'unidad': _productos[pIndex]['unidad_medida'],
            'cantidad_ideal': item['cantidad_ideal'],
          });
        }
      }

      // Ordenar alfabéticamente
      listaMapeada.sort((a, b) => a['nombre_producto'].toString().compareTo(b['nombre_producto'].toString()));

      if (mounted) {
        setState(() {
          _stockIdealList = listaMapeada;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando stock ideal: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _mostrarFormulario([Map<String, dynamic>? itemAEditar]) {
    dynamic productoSeleccionado = itemAEditar?['producto_id'];
    final cantidadController = TextEditingController(text: itemAEditar != null ? itemAEditar['cantidad_ideal'].toString() : '');
    final buscadorProductoController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 24, left: 24, right: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(itemAEditar == null ? 'Agregar al Stock Base' : 'Editar Cantidad Ideal', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.tealAccent)),
                  const SizedBox(height: 16),
                  
                  // Si estamos editando, bloqueamos el cambio de producto. Si es nuevo, mostramos el buscador.
                  itemAEditar != null 
                    ? Text('Producto: ${itemAEditar['nombre_producto']}', style: const TextStyle(color: Colors.white, fontSize: 16))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Producto *', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          const SizedBox(height: 4),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              return DropdownMenu<dynamic>(
                                controller: buscadorProductoController,
                                width: constraints.maxWidth, 
                                menuHeight: 250, 
                                enableFilter: true, 
                                hintText: 'Escribe para buscar...',
                                textStyle: const TextStyle(fontSize: 14),
                                inputDecorationTheme: InputDecorationTheme(
                                  filled: true,
                                  fillColor: const Color(0xFF2A2A2A),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                ),
                                dropdownMenuEntries: _productos.map((p) => DropdownMenuEntry<dynamic>(value: p['id'], label: p['nombre'])).toList(),
                                onSelected: (v) => setModalState(() => productoSeleccionado = v),
                              );
                            }
                          ),
                        ],
                      ),
                  
                  const SizedBox(height: 16),
                  TextField(
                    controller: cantidadController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: 'Cantidad Ideal (Meta) *', filled: true, fillColor: const Color(0xFF2A2A2A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade600, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: () async {
                        final cantidad = double.tryParse(cantidadController.text.trim());
                        if (productoSeleccionado == null || cantidad == null) return;
                        
                        try {
                          if (itemAEditar == null) {
                            await Supabase.instance.client.from('stock_ideal_areas').insert({
                              'sucursal_id': _sucursalSeleccionada,
                              'producto_id': productoSeleccionado,
                              'cantidad_ideal': cantidad
                            });
                          } else {
                            await Supabase.instance.client.from('stock_ideal_areas').update({
                              'cantidad_ideal': cantidad
                            }).eq('id', itemAEditar['id']);
                          }
                          if (!context.mounted) return; {
                            Navigator.pop(context);
                            _cargarStockDeSucursal(_sucursalSeleccionada);
                          }
                        } catch (e) {
                          if (!context.mounted) return; {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: El producto ya está en la lista o hubo un fallo de red.'), backgroundColor: Colors.red));
                          }
                        }
                      },
                      child: Text(itemAEditar == null ? 'Guardar' : 'Actualizar', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
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

  Future<void> _eliminarItem(int id) async {
    try {
      await Supabase.instance.client.from('stock_ideal_areas').delete().eq('id', id);
      _cargarStockDeSucursal(_sucursalSeleccionada);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Plantillas de Stock Base', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.teal.shade800),
      body: _isLoading && _sucursales.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // PANEL SUPERIOR: SELECCIÓN DE ÁREA
                Container(
                  padding: const EdgeInsets.all(16),
                  color: const Color(0xFF1A1A1A),
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('1. Selecciona el Área a configurar', style: TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<dynamic>(
                        initialValue: _sucursalSeleccionada,
                        decoration: InputDecoration(filled: true, fillColor: const Color(0xFF2A2A2A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)),
                        hint: const Text('Ej. Batida, Panadería...', style: TextStyle(color: Colors.grey)),
                        items: _sucursales.map((s) => DropdownMenuItem(value: s['id'], child: Text('${s['nombre']} (${s['tipo']})'))).toList(),
                        onChanged: (val) {
                          setState(() => _sucursalSeleccionada = val);
                          _cargarStockDeSucursal(val);
                        },
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Colors.grey),
                
                // PANEL INFERIOR: LA LISTA DE PRODUCTOS
                Expanded(
                  child: _sucursalSeleccionada == null
                      ? const Center(child: Text('Selecciona un área arriba para ver su Stock Base', style: TextStyle(color: Colors.grey)))
                      : _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _stockIdealList.isEmpty
                              ? const Center(child: Text('Esta área aún no tiene productos asignados.', style: TextStyle(color: Colors.grey)))
                              : ListView.builder(
                                  padding: const EdgeInsets.all(12),
                                  itemCount: _stockIdealList.length,
                                  itemBuilder: (context, index) {
                                    final item = _stockIdealList[index];
                                    return Card(
                                      color: const Color(0xFF1A1A1A),
                                      margin: const EdgeInsets.only(bottom: 8),
                                      child: ListTile(
                                        title: Text(item['nombre_producto'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                        subtitle: Text('Meta: ${item['cantidad_ideal']} ${item['unidad']}', style: const TextStyle(color: Colors.tealAccent)),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(icon: const Icon(Icons.edit, color: Colors.teal), onPressed: () => _mostrarFormulario(item)),
                                            IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: () => _eliminarItem(item['id'])),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                ),
              ],
            ),
      floatingActionButton: _sucursalSeleccionada == null
          ? null
          : FloatingActionButton.extended(
              backgroundColor: Colors.teal.shade600,
              onPressed: () => _mostrarFormulario(),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Agregar Insumo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
    );
  }
}