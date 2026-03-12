import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InboundScreen extends StatefulWidget {
  const InboundScreen({super.key});

  @override
  State<InboundScreen> createState() => _InboundScreenState();
}

class _InboundScreenState extends State<InboundScreen> {
  // Encabezado
  int? _proveedorSeleccionado;
  final _facturaController = TextEditingController();
  int? _idAlmacenProduccion; 

  // Línea
  final _lineaFormKey = GlobalKey<FormState>();
  int? _productoActual;
  final _cajasController = TextEditingController();
  final _piezasController = TextEditingController();
  final _loteController = TextEditingController();

  final List<Map<String, dynamic>> _listaEntradas = [];
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
      // AHORA TRAEMOS EL NUEVO CAMPO: piezas_por_caja
      final prods = await Supabase.instance.client.from('productos').select('id, nombre, stock_actual, unidad_medida, piezas_por_caja').order('nombre');
      final provs = await Supabase.instance.client.from('sucursales').select('id, nombre').eq('tipo', 'Proveedor').order('nombre');
      final destino = await Supabase.instance.client.from('sucursales').select('id').eq('nombre', 'Almacen Produccion').maybeSingle();

      if (mounted) {
        setState(() {
          _productos = prods;
          _proveedores = provs;
          _idAlmacenProduccion = destino != null ? destino['id'] : null; 
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  // --- MOTOR MATEMÁTICO EN TIEMPO REAL ---
  int _calcularTotalTemporal() {
    if (_productoActual == null) return 0;
    final prodInfo = _productos.firstWhere((p) => p['id'] == _productoActual);
    final ppc = prodInfo['piezas_por_caja'] ?? 1;
    
    final cajas = int.tryParse(_cajasController.text.trim()) ?? 0;
    final piezas = int.tryParse(_piezasController.text.trim()) ?? 0;
    
    return ((cajas * ppc) + piezas).toInt();
  }

  void _agregarALaLista() {
    if (!_lineaFormKey.currentState!.validate()) return;
    if (_productoActual == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona un producto'), backgroundColor: Colors.orange));
      return;
    }

    final totalCalculado = _calcularTotalTemporal();
    if (totalCalculado <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingresa una cantidad mayor a 0'), backgroundColor: Colors.orange));
      return;
    }

    final prodInfo = _productos.firstWhere((p) => p['id'] == _productoActual);
    final cajas = int.tryParse(_cajasController.text.trim()) ?? 0;
    final piezas = int.tryParse(_piezasController.text.trim()) ?? 0;
    final ppc = prodInfo['piezas_por_caja'] ?? 1;
    
    setState(() {
      _listaEntradas.add({
        'producto_id': _productoActual,
        'nombre_producto': prodInfo['nombre'],
        'unidad': prodInfo['unidad_medida'],
        'stock_previo': prodInfo['stock_actual'],
        'cajas': cajas,
        'piezas_sueltas': piezas,
        'piezas_por_caja': ppc,
        'cantidad': totalCalculado, // El gran total que se va a la base de datos
        'lote': _loteController.text.trim().isEmpty ? null : _loteController.text.trim(),
      });
      
      _productoActual = null;
      _cajasController.clear();
      _piezasController.clear();
      _loteController.clear();
    });
  }

  void _eliminarDeLaLista(int index) {
    setState(() => _listaEntradas.removeAt(index));
  }

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
      final factura = _facturaController.text.trim().isEmpty ? null : _facturaController.text.trim();
      
      List<Map<String, dynamic>> movimientosAInsertar = _listaEntradas.map((item) {
        return {
          'tipo_movimiento': 'Entrada',
          'producto_id': item['producto_id'],
          'cantidad': item['cantidad'], // Guarda las piezas totales
          'factura': factura,
          'lote': item['lote'],
          'origen_id': _proveedorSeleccionado,
          'destino_id': _idAlmacenProduccion, 
        };
      }).toList();

      await Supabase.instance.client.from('movimientos').insert(movimientosAInsertar);

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
    _cajasController.dispose();
    _piezasController.dispose();
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
              // --- SECCIÓN 1: ENCABEZADO ---
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

              // --- SECCIÓN 2: FORMULARIO MULTI-UNIDAD ---
              Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _lineaFormKey,
                  child: Column(
                    children: [
                      _buildDropdown('Producto *', 'Buscar...', _productos, _productoActual, (v) => setState(() => _productoActual = v as int?)),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildTextField('Cajas', '0', controller: _cajasController, isNumber: true, onChanged: (_) => setState(() {}))),
                          const SizedBox(width: 12),
                          Expanded(child: _buildTextField('Piezas Sueltas', '0', controller: _piezasController, isNumber: true, onChanged: (_) => setState(() {}))),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Etiqueta dinámica que muestra la matemática en tiempo real
                      Container(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'Total a ingresar: ${_calcularTotalTemporal()} ${ _productoActual != null ? _productos.firstWhere((p) => p['id'] == _productoActual)['unidad_medida'] : ''}',
                          style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
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

              // --- SECCIÓN 3: EL CARRITO CON DESGLOSE ---
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
                          // Aquí mostramos el desglose exacto que pediste
                          subtitle: Text('Cajas = ${item['cajas']} (${item['piezas_por_caja']}pz c/u), Piezas = ${item['piezas_sueltas']}\nTotal: ${item['cantidad']} ${item['unidad']} | Lote: ${item['lote'] ?? 'N/A'}'),
                          trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => _eliminarDeLaLista(index)),
                        );
                      },
                    ),
              ),

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

  Widget _buildDropdown(String label, String hint, List<dynamic> items, int? selectedValue, Function(dynamic) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        DropdownButtonFormField<int>(
          initialValue: selectedValue,
          isExpanded: true, 
          decoration: InputDecoration(filled: true, fillColor: const Color(0xFF2A2A2A), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)),
          hint: Text(hint),
          items: items.map((item) => DropdownMenuItem<int>(value: item['id'], child: Text(item['nombre']))).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}