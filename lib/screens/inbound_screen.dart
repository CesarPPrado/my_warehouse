import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InboundScreen extends StatefulWidget {
  const InboundScreen({super.key});

  @override
  State<InboundScreen> createState() => _InboundScreenState();
}

class _InboundScreenState extends State<InboundScreen> {
  // --- VARIABLES DE ENCABEZADO (Aplica para toda la entrada) ---
  int? _proveedorSeleccionado;
  final _facturaController = TextEditingController();
  int? _idAlmacenProduccion; // Guardaremos el ID del destino automático

  // --- VARIABLES DE LÍNEA (Para el producto individual) ---
  final _lineaFormKey = GlobalKey<FormState>();
  int? _productoActual;
  final _cantidadController = TextEditingController();
  final _loteController = TextEditingController();

  // --- EL "CARRITO" DE ENTRADAS ---
  final List<Map<String, dynamic>> _listaEntradas = [];

  // Catálogos
  List<dynamic> _productos = [];
  List<dynamic> _proveedores = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _cargarCatalogos();
  }

  Future<void> _cargarCatalogos() async {
    try {
      final prods = await Supabase.instance.client.from('productos').select('id, nombre, stock_actual, unidad_medida').order('nombre');
      // Solo traemos a los que son tipo Proveedor
      final provs = await Supabase.instance.client.from('sucursales').select('id, nombre').eq('tipo', 'Proveedor').order('nombre');
      // Buscamos automáticamente el ID del Almacén para inyectarlo sin preguntar
      final destino = await Supabase.instance.client.from('sucursales').select('id').eq('nombre', 'Almacen Produccion').maybeSingle();

      if (mounted) {
        setState(() {
          _productos = prods;
          _proveedores = provs;
          // Si no existe uno llamado "Producción", buscamos cualquier bodega, si no, null.
          _idAlmacenProduccion = destino != null ? destino['id'] : null; 
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  // Función para agregar un producto a la lista temporal (Carrito)
  void _agregarALaLista() {
    if (!_lineaFormKey.currentState!.validate()) return;
    if (_productoActual == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona un producto'), backgroundColor: Colors.orange));
      return;
    }

    final prodInfo = _productos.firstWhere((p) => p['id'] == _productoActual);
    
    setState(() {
      _listaEntradas.add({
        'producto_id': _productoActual,
        'nombre_producto': prodInfo['nombre'],
        'unidad': prodInfo['unidad_medida'],
        'stock_previo': prodInfo['stock_actual'],
        'cantidad': num.parse(_cantidadController.text.trim()),
        'lote': _loteController.text.trim().isEmpty ? null : _loteController.text.trim(),
      });
      // Limpiamos los campos de la línea para el siguiente producto
      _productoActual = null;
      _cantidadController.clear();
      _loteController.clear();
    });
  }

  void _eliminarDeLaLista(int index) {
    setState(() {
      _listaEntradas.removeAt(index);
    });
  }

  // Guarda todo en la base de datos
  Future<void> _guardarEntradaMasiva() async {
    if (_proveedorSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Falta seleccionar el Proveedor'), backgroundColor: Colors.red));
      return;
    }
    if (_listaEntradas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Agrega al menos un producto a la lista'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Preparamos la lista de movimientos para insertarlos todos de golpe (Bulk Insert)
      final factura = _facturaController.text.trim().isEmpty ? null : _facturaController.text.trim();
      
      List<Map<String, dynamic>> movimientosAInsertar = _listaEntradas.map((item) {
        return {
          'tipo_movimiento': 'Entrada',
          'producto_id': item['producto_id'],
          'cantidad': item['cantidad'],
          'factura': factura,
          'lote': item['lote'],
          'origen_id': _proveedorSeleccionado,
          'destino_id': _idAlmacenProduccion, // Destino automático
        };
      }).toList();

      await Supabase.instance.client.from('movimientos').insert(movimientosAInsertar);

      // Actualizamos el stock de cada producto matemáticamente
      for (var item in _listaEntradas) {
        final nuevoStock = item['stock_previo'] + item['cantidad'];
        await Supabase.instance.client.from('productos').update({'stock_actual': nuevoStock}).eq('id', item['producto_id']);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Entrada masiva registrada con éxito!'), backgroundColor: Colors.green));
      Navigator.pop(context);

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _facturaController.dispose();
    _cantidadController.dispose();
    _loteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recepción de Mercancía', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.green.shade800),
      body: _productos.isEmpty 
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              // --- SECCIÓN 1: ENCABEZADO (Proveedor y Factura) ---
              Container(
                padding: const EdgeInsets.all(16),
                color: const Color(0xFF1A1A1A),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Datos del Documento', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(flex: 2, child: _buildDropdown('Proveedor *', 'Seleccione', _proveedores, _proveedorSeleccionado, (v) => setState(() => _proveedorSeleccionado = v as int?))),
                        const SizedBox(width: 12),
                        Expanded(flex: 1, child: _buildTextField('Factura', 'Opcional', controller: _facturaController)),
                      ],
                    ),
                  ],
                ),
              ),

              // --- SECCIÓN 2: FORMULARIO DE LÍNEA (Agregar Productos) ---
              Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _lineaFormKey,
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 2, child: _buildDropdown('Producto *', 'Buscar...', _productos, _productoActual, (v) => setState(() => _productoActual = v as int?))),
                          const SizedBox(width: 12),
                          Expanded(flex: 1, child: _buildTextField('Cant. *', '0', controller: _cantidadController, isNumber: true, isRequired: true)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildTextField('Lote (Opcional)', 'Ej. L-2026', controller: _loteController)),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: _agregarALaLista,
                            icon: const Icon(Icons.add_shopping_cart, color: Colors.black, size: 18),
                            label: const Text('Agregar', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(color: Colors.grey),

              // --- SECCIÓN 3: EL CARRITO / LISTA DE ENTRADAS ---
              Expanded(
                child: _listaEntradas.isEmpty
                  ? const Center(child: Text('La lista está vacía.\nAgrega productos arriba.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: _listaEntradas.length,
                      itemBuilder: (context, index) {
                        final item = _listaEntradas[index];
                        return ListTile(
                          leading: CircleAvatar(backgroundColor: Colors.green.withValues(alpha: 0.2), child: Text('${index + 1}', style: const TextStyle(color: Colors.greenAccent))),
                          title: Text(item['nombre_producto'], style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Cant: ${item['cantidad']} ${item['unidad']} | Lote: ${item['lote'] ?? 'N/A'}'),
                          trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => _eliminarDeLaLista(index)),
                        );
                      },
                    ),
              ),

              // --- BOTÓN FINAL DE GUARDAR ---
              Container(
                padding: const EdgeInsets.all(16),
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _guardarEntradaMasiva,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : Text('Confirmar Entrada (${_listaEntradas.length} Insumos)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ),
    );
  }

  // Widgets Reutilizables (Simplificados para encajar bien)
  Widget _buildTextField(String label, String hint, {TextEditingController? controller, bool isNumber = false, bool isRequired = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
          validator: isRequired ? (v) => v!.isEmpty ? '*' : null : null,
          decoration: InputDecoration(hintText: hint, filled: true, fillColor: const Color(0xFF2A2A2A), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)),
        ),
      ],
    );
  }

  Widget _buildDropdown(String label, String hint, List<dynamic> items, int? selectedValue, Function(dynamic) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        DropdownButtonFormField<int>(
          initialValue: selectedValue,
          isExpanded: true, // Evita errores visuales si el nombre es muy largo
          decoration: InputDecoration(filled: true, fillColor: const Color(0xFF2A2A2A), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)),
          hint: Text(hint),
          items: items.map((item) => DropdownMenuItem<int>(value: item['id'], child: Text(item['nombre']))).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}