import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OutboundScreen extends StatefulWidget {
  const OutboundScreen({super.key});

  @override
  State<OutboundScreen> createState() => _OutboundScreenState();
}

class _OutboundScreenState extends State<OutboundScreen> {
  List<dynamic> _sucursales = [];
  List<dynamic> _productos = [];
  
  dynamic _sucursalSeleccionada;
  final _motivoController = TextEditingController();
  
  dynamic _productoSeleccionado;
  final _cajasController = TextEditingController();
  final _piezasController = TextEditingController();
  
  // --- CONTROLADORES DEL BUSCADOR ---
  final _buscadorSucursalController = TextEditingController();
  final _buscadorProductoController = TextEditingController();

  final List<Map<String, dynamic>> _productosAgregados = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      final sucData = await Supabase.instance.client.from('sucursales').select('id, nombre, tipo').order('nombre');
      final prodData = await Supabase.instance.client.from('productos').select('id, nombre, unidad_medida, piezas_por_caja, stock_actual').order('nombre');
      
      if (mounted) {
        setState(() {
          _sucursales = sucData;
          _productos = prodData;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _agregarALista() {
    if (_productoSeleccionado == null) return;

    final pIndex = _productos.indexWhere((p) => p['id'] == _productoSeleccionado);
    if (pIndex == -1) return;
    
    final pInfo = _productos[pIndex];
    
    final cajas = int.tryParse(_cajasController.text.trim()) ?? 0;
    final piezas = double.tryParse(_piezasController.text.trim()) ?? 0;
    
    if (cajas == 0 && piezas == 0) return;

    final pxc = (pInfo['piezas_por_caja'] ?? 1) as num;
    final totalASacar = (cajas * pxc) + piezas;
    final stockActual = (pInfo['stock_actual'] ?? 0) as num;

    // --- CANDADO DE SEGURIDAD (No sacar más de lo que hay) ---
    if (totalASacar > stockActual) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('⚠️ Stock Insuficiente\nIntentas sacar $totalASacar pero solo tienes $stockActual ${pInfo['unidad_medida']}.', style: const TextStyle(height: 1.5)), 
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 4),
      ));
      return;
    }

    setState(() {
      _productosAgregados.add({
        'producto_id': pInfo['id'],
        'nombre': pInfo['nombre'],
        'unidad': pInfo['unidad_medida'],
        'cantidad_total': totalASacar,
        'stock_despues': stockActual - totalASacar,
      });

      // Limpieza automática
      _productoSeleccionado = null;
      _cajasController.clear();
      _piezasController.clear();
      _buscadorProductoController.clear();
    });
  }

  void _eliminarDeLista(int index) {
    setState(() => _productosAgregados.removeAt(index));
  }

  Future<void> _confirmarSalida() async {
    if (_sucursalSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona el destino', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.orange));
      return;
    }
    if (_productosAgregados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Agrega al menos un producto', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.orange));
      return;
    }

    setState(() => _isSaving = true);

    try {
      final motivo = _motivoController.text.trim();
      
      for (var item in _productosAgregados) {
        // 1. Guardar en el historial de Movimientos
        await Supabase.instance.client.from('movimientos').insert({
          'tipo_movimiento': 'Salida',
          'producto_id': item['producto_id'],
          'cantidad': item['cantidad_total'], // Lo guardamos en positivo, el 'tipo' dice qué es
          'sucursal_id': _sucursalSeleccionada,
          'motivo': motivo.isEmpty ? 'Traspaso/Despacho' : motivo,
        });

        // 2. Restar del Stock
        final pIndex = _productos.indexWhere((p) => p['id'] == item['producto_id']);
        if (pIndex != -1) {
          final pInfo = _productos[pIndex];
          final nuevoStock = (pInfo['stock_actual'] ?? 0) - item['cantidad_total'];
          await Supabase.instance.client.from('productos').update({'stock_actual': nuevoStock}).eq('id', item['producto_id']);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Salida registrada con éxito!', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.green));
        Navigator.pop(context); 
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _motivoController.dispose();
    _cajasController.dispose();
    _piezasController.dispose();
    _buscadorSucursalController.dispose();
    _buscadorProductoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Cálculo en tiempo real
    double totalCalculado = 0;
    String unidadCalculada = '';
    if (_productoSeleccionado != null) {
      final pIndex = _productos.indexWhere((p) => p['id'] == _productoSeleccionado);
      if (pIndex != -1) {
        final pInfo = _productos[pIndex];
        final cajas = int.tryParse(_cajasController.text.trim()) ?? 0;
        final piezas = double.tryParse(_piezasController.text.trim()) ?? 0;
        final pxc = (pInfo['piezas_por_caja'] ?? 1) as num;
        totalCalculado = (cajas * pxc) + piezas;
        unidadCalculada = pInfo['unidad_medida'] ?? '';
      }
    }

    String totalStr = totalCalculado.toString();
    if (totalStr.endsWith('.0')) totalStr = totalStr.substring(0, totalStr.length - 2);

    return Scaffold(
      appBar: AppBar(title: const Text('Salida de Mercancía', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.red.shade800),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // --- PANEL SUPERIOR: FORMULARIO ---
                Container(
                  padding: const EdgeInsets.all(16),
                  color: const Color(0xFF1A1A1A),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Datos del Traspaso / Merma', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2, 
                            child: _buildSearchableDropdown('Destino (Sucursal/Área) *', 'Buscar...', _sucursales, _sucursalSeleccionada, _buscadorSucursalController, (v) => setState(() => _sucursalSeleccionada = v))
                          ),
                          const SizedBox(width: 12),
                          Expanded(flex: 1, child: _buildTextField('Motivo', 'Ej. Merma...', controller: _motivoController)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      _buildSearchableDropdown('Producto a sacar *', 'Escribe para buscar...', _productos, _productoSeleccionado, _buscadorProductoController, (v) => setState(() => _productoSeleccionado = v)),
                      
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildTextField('Costales/Bidones/Cajas', '0', controller: _cajasController, isNumber: true, onChanged: (_) => setState((){}))),
                          const SizedBox(width: 12),
                          Expanded(child: _buildTextField('KG/L/PZ/Latas', '0', controller: _piezasController, isNumber: true, onChanged: (_) => setState((){}))),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Text(
                              totalCalculado > 0 ? 'A restar: -$totalStr $unidadCalculada' : '',
                              style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _agregarALista, 
                            icon: const Icon(Icons.outbox, color: Colors.white, size: 18), 
                            label: const Text('Extraer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), 
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent.shade700, padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24))
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.grey, height: 1),

                // --- PANEL MEDIO: LISTA DE EXTRACCIÓN ---
                Expanded(
                  child: _productosAgregados.isEmpty
                      ? const Center(child: Text('Ningún producto seleccionado.\nUsa el buscador arriba.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                          itemCount: _productosAgregados.length,
                          itemBuilder: (context, index) {
                            final item = _productosAgregados[index];
                            return ListTile(
                              leading: const Icon(Icons.arrow_circle_up, color: Colors.redAccent),
                              title: Text(item['nombre'], style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('Quedarán en almacén: ${item['stock_despues']} ${item['unidad']}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('- ${item['cantidad_total']}', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 18)),
                                  IconButton(icon: const Icon(Icons.delete, color: Colors.grey), onPressed: () => _eliminarDeLista(index)),
                                ],
                              ),
                            );
                          },
                        ),
                ),

                // --- BOTÓN INFERIOR: CONFIRMAR ---
                Container(
                  padding: const EdgeInsets.all(16),
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (_isSaving || _productosAgregados.isEmpty) ? null : _confirmarSalida,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: _isSaving 
                      ? const CircularProgressIndicator(color: Colors.white) 
                      : Text('Confirmar Salida (${_productosAgregados.length} Insumos)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildTextField(String label, String hint, {TextEditingController? controller, bool isNumber = false, Function(String)? onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
          onChanged: onChanged,
          decoration: InputDecoration(hintText: hint, filled: true, fillColor: const Color(0xFF2A2A2A), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)),
        ),
      ],
    );
  }

  Widget _buildSearchableDropdown(String label, String hint, List<dynamic> items, dynamic selectedValue, TextEditingController controller, Function(dynamic) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        LayoutBuilder(
          builder: (context, constraints) {
            return DropdownMenu<dynamic>(
              controller: controller,
              width: constraints.maxWidth, 
              menuHeight: 250, 
              enableFilter: true, 
              hintText: hint,
              initialSelection: selectedValue,
              textStyle: const TextStyle(fontSize: 14),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: const Color(0xFF2A2A2A),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
              dropdownMenuEntries: items.map((item) {
                return DropdownMenuEntry<dynamic>(
                  value: item['id'],
                  label: item['nombre'],
                );
              }).toList(),
              onSelected: onChanged,
            );
          }
        ),
      ],
    );
  }
}