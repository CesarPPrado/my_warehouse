import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InboundScreen extends StatefulWidget {
  const InboundScreen({super.key});

  @override
  State<InboundScreen> createState() => _InboundScreenState();
}

class _InboundScreenState extends State<InboundScreen> {
  List<dynamic> _proveedores = [];
  List<dynamic> _productos = [];
  
  dynamic _proveedorSeleccionado;
  final _facturaController = TextEditingController();
  
  dynamic _productoSeleccionado;
  final _cajasController = TextEditingController();
  final _piezasController = TextEditingController();
  final _loteController = TextEditingController();
  
  // --- LOS NUEVOS CONTROLADORES DE BÚSQUEDA ---
  final _buscadorProveedorController = TextEditingController();
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
    // 1. Descargamos los Productos (esto sabemos que funciona perfecto)
    try {
      final prodData = await Supabase.instance.client.from('productos').select('id, nombre, unidad_medida, piezas_por_caja, stock_actual').order('nombre');
      if (mounted) setState(() => _productos = prodData);
    } catch (e) {
      debugPrint('Error cargando productos: $e');
    }

    // 2. Descargamos los Proveedores (con red de seguridad)
    try {
      final provData = await Supabase.instance.client.from('proveedores').select('id, nombre').order('nombre');
      
      if (provData.isEmpty) throw 'Tabla vacía'; // Si existe pero no hay nada, forzamos el error
      
      if (mounted) setState(() => _proveedores = provData);
    } catch (e) {
      debugPrint('Error cargando proveedores: $e');
      // Si la tabla no existe o está vacía, metemos a "Guga" como salvavidas temporal
      if (mounted) {
        setState(() {
          _proveedores = [{'id': 0, 'nombre': 'Guga (Proveedor Temporal)'}];
        });
      }
    }

    // 3. Apagamos el ícono de carga
    if (mounted) setState(() => _isLoading = false);
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
    final totalAIngresar = (cajas * pxc) + piezas;

    setState(() {
      _productosAgregados.add({
        'producto_id': pInfo['id'],
        'nombre': pInfo['nombre'],
        'unidad': pInfo['unidad_medida'],
        'cantidad_total': totalAIngresar,
        'cajas_ingresadas': cajas,
        'piezas_sueltas': piezas,
        'lote': _loteController.text.trim(),
      });

      // --- LIMPIEZA AUTOMÁTICA ---
      _productoSeleccionado = null;
      _cajasController.clear();
      _piezasController.clear();
      _loteController.clear();
      _buscadorProductoController.clear(); // Limpiamos el texto del buscador
    });
  }

  void _eliminarDeLista(int index) {
    setState(() => _productosAgregados.removeAt(index));
  }

  Future<void> _confirmarEntrada() async {
    if (_proveedorSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona un proveedor', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.orange));
      return;
    }
    if (_productosAgregados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Agrega al menos un producto', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.orange));
      return;
    }

    setState(() => _isSaving = true);

    try {
      final factura = _facturaController.text.trim();
      
      for (var item in _productosAgregados) {
        // 1. Registrar movimiento
        await Supabase.instance.client.from('movimientos').insert({
          'tipo_movimiento': 'Entrada',
          'producto_id': item['producto_id'],
          'cantidad': item['cantidad_total'],
          'origen_id': _proveedorSeleccionado,
          'factura': factura.isEmpty ? null : factura,
          'lote': item['lote'].toString().isEmpty ? null : item['lote'],
        });

        // 2. Actualizar stock
        final pIndex = _productos.indexWhere((p) => p['id'] == item['producto_id']);
        if (pIndex != -1) {
          final pInfo = _productos[pIndex];
          final nuevoStock = (pInfo['stock_actual'] ?? 0) + item['cantidad_total'];
          await Supabase.instance.client.from('productos').update({'stock_actual': nuevoStock}).eq('id', item['producto_id']);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Entrada registrada con éxito!', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.green));
        Navigator.pop(context); // Regresa a inicio
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _facturaController.dispose();
    _cajasController.dispose();
    _piezasController.dispose();
    _loteController.dispose();
    _buscadorProveedorController.dispose();
    _buscadorProductoController.dispose();
    super.dispose(); // Siempre llamamos al dispose del padre al final
  }

  @override
  Widget build(BuildContext context) {
    // Cálculo en tiempo real para el texto verde
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

    // Formateamos para quitar ".0" si es entero
    String totalStr = totalCalculado.toString();
    if (totalStr.endsWith('.0')) totalStr = totalStr.substring(0, totalStr.length - 2);

    return Scaffold(
      appBar: AppBar(title: const Text('Recepción de Mercancía', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.green.shade700),
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
                      const Text('Datos de la nota del proveedor', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2, 
                            // BUSCADOR 1: PROVEEDOR
                            child: _buildSearchableDropdown('Proveedor *', 'Buscar...', _proveedores, _proveedorSeleccionado, _buscadorProveedorController, (v) => setState(() => _proveedorSeleccionado = v))
                          ),
                          const SizedBox(width: 12),
                          Expanded(flex: 1, child: _buildTextField('Factura *', 'Ej. F-20231', controller: _facturaController)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // BUSCADOR 2: PRODUCTO
                      _buildSearchableDropdown('Producto *', 'Escribe para buscar...', _productos, _productoSeleccionado, _buscadorProductoController, (v) => setState(() => _productoSeleccionado = v)),
                      
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildTextField('Costales/Bidones/Cajas/Etc.', '0', controller: _cajasController, isNumber: true, onChanged: (_) => setState((){}))),
                          const SizedBox(width: 12),
                          Expanded(child: _buildTextField('KG/L/PZ/Latas/Etc.', '0', controller: _piezasController, isNumber: true, onChanged: (_) => setState((){}))),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          totalCalculado > 0 ? 'Total a ingresar: $totalStr $unidadCalculada' : '',
                          style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(flex: 2, child: _buildTextField('Lote (Opcional)', 'Ej. L-2026', controller: _loteController)),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 1, 
                            child: ElevatedButton.icon(
                              onPressed: _agregarALista, 
                              icon: const Icon(Icons.add_shopping_cart, color: Colors.white, size: 18), 
                              label: const Text('Agregar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), 
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent.shade700, padding: const EdgeInsets.symmetric(vertical: 14))
                            )
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.grey, height: 1),

                // --- PANEL MEDIO: LISTA DE PRODUCTOS ---
                Expanded(
                  child: _productosAgregados.isEmpty
                      ? const Center(child: Text('La lista está vacía.\nAgrega productos arriba.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                          itemCount: _productosAgregados.length,
                          itemBuilder: (context, index) {
                            final item = _productosAgregados[index];
                            return ListTile(
                              leading: const Icon(Icons.check_circle, color: Colors.green),
                              title: Text(item['nombre'], style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('Lote: ${item['lote'].toString().isEmpty ? 'N/A' : item['lote']}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('+ ${item['cantidad_total']} ${item['unidad']}', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                                  IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: () => _eliminarDeLista(index)),
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
                    onPressed: (_isSaving || _productosAgregados.isEmpty) ? null : _confirmarEntrada,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: _isSaving 
                      ? const CircularProgressIndicator(color: Colors.white) 
                      : Text('Confirmar Entrada (${_productosAgregados.length} Insumos)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ],
            ),
    );
  }

  // --- WIDGETS REUTILIZABLES ---
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

  // --- EL BUSCADOR INTELIGENTE ---
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