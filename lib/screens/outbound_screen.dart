import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OutboundScreen extends StatefulWidget {
  const OutboundScreen({super.key});

  @override
  State<OutboundScreen> createState() => _OutboundScreenState();
}

class _OutboundScreenState extends State<OutboundScreen> {
  // --- ENCABEZADO ---
  int? _destinoSeleccionado;
  final _referenciaController = TextEditingController();
  int? _idAlmacenProduccion; // El origen por defecto

  // --- LÍNEA ---
  final _lineaFormKey = GlobalKey<FormState>();
  int? _productoActual;
  final _cajasController = TextEditingController();
  final _piezasController = TextEditingController();

  final List<Map<String, dynamic>> _listaSalidas = [];
  List<dynamic> _productos = [];
  List<dynamic> _sucursalesDestino = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _cargarCatalogos();
  }

  Future<void> _cargarCatalogos() async {
    try {
      // Solo traemos productos que tengan stock > 0 para no llenar la lista de basura
      final prods = await Supabase.instance.client.from('productos').select('id, nombre, stock_actual, unidad_medida, piezas_por_caja').gt('stock_actual', 0).order('nombre');
      
      // Traemos las sucursales a las que les podemos despachar
      final sucs = await Supabase.instance.client.from('sucursales').select('id, nombre').inFilter('tipo', ['Sucursal', 'Bodega']).order('nombre');
      
      // Buscamos de dónde sale la mercancía por defecto
      final origen = await Supabase.instance.client.from('sucursales').select('id').eq('nombre', 'Almacen Produccion').maybeSingle();

      if (mounted) {
        setState(() {
          _productos = prods;
          _sucursalesDestino = sucs;
          _idAlmacenProduccion = origen != null ? origen['id'] : null; 
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  int _calcularTotalTemporal() {
    if (_productoActual == null) return 0;
    final prodInfo = _productos.firstWhere((p) => p['id'] == _productoActual);
    final int ppc = (prodInfo['piezas_por_caja'] ?? 1).toInt();
    
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
    final stockActual = (prodInfo['stock_actual'] ?? 0).toInt();

    // --- REGLA DE NEGOCIO: PREVENIR INVENTARIO NEGATIVO ---
    // Calculamos si ya tenemos este producto en el carrito para sumar lo que ya apartamos
    int cantidadYaEnCarrito = 0;
    for (var item in _listaSalidas) {
      if (item['producto_id'] == _productoActual) {
        cantidadYaEnCarrito += (item['cantidad'] as num).toInt();
      }
    }

    if ((totalCalculado + cantidadYaEnCarrito) > stockActual) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('¡Stock insuficiente! Solo tienes $stockActual disponibles.'), backgroundColor: Colors.red),
      );
      return;
    }

    final cajas = int.tryParse(_cajasController.text.trim()) ?? 0;
    final piezas = int.tryParse(_piezasController.text.trim()) ?? 0;
    final int ppc = (prodInfo['piezas_por_caja'] ?? 1).toInt();
    
    setState(() {
      _listaSalidas.add({
        'producto_id': _productoActual,
        'nombre_producto': prodInfo['nombre'],
        'unidad': prodInfo['unidad_medida'],
        'stock_previo': stockActual,
        'cajas': cajas,
        'piezas_sueltas': piezas,
        'piezas_por_caja': ppc,
        'cantidad': totalCalculado,
      });
      
      _productoActual = null;
      _cajasController.clear();
      _piezasController.clear();
    });
  }

  void _eliminarDeLaLista(int index) {
    setState(() => _listaSalidas.removeAt(index));
  }

  Future<void> _guardarSalidaMasiva() async {
    if (_destinoSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Falta seleccionar la Sucursal de Destino'), backgroundColor: Colors.red));
      return;
    }
    if (_listaSalidas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Agrega al menos un producto a despachar'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final referencia = _referenciaController.text.trim().isEmpty ? null : _referenciaController.text.trim();
      
      List<Map<String, dynamic>> movimientosAInsertar = _listaSalidas.map((item) {
        return {
          'tipo_movimiento': 'Salida', // Marcamos como salida
          'producto_id': item['producto_id'],
          'cantidad': item['cantidad'],
          'factura': referencia,
          'origen_id': _idAlmacenProduccion, // Sale del almacén principal
          'destino_id': _destinoSeleccionado, // Va hacia la sucursal
        };
      }).toList();

      await Supabase.instance.client.from('movimientos').insert(movimientosAInsertar);

      // RESTAMOS EL STOCK MATEMÁTICAMENTE
      for (var item in _listaSalidas) {
        final nuevoStock = item['stock_previo'] - item['cantidad'];
        await Supabase.instance.client.from('productos').update({'stock_actual': nuevoStock}).eq('id', item['producto_id']);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Despacho registrado con éxito!'), backgroundColor: Colors.green));
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
    _referenciaController.dispose();
    _cajasController.dispose();
    _piezasController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Despacho de Mercancía', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.deepOrange.shade800),
      body: _productos.isEmpty 
        ? const Center(child: Text('No hay productos con stock disponible para sacar.', style: TextStyle(color: Colors.grey)))
        : Column(
            children: [
              // --- ENCABEZADO ---
              Container(
                padding: const EdgeInsets.all(16),
                color: const Color(0xFF1A1A1A),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Datos de Envío', style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(flex: 2, child: _buildDropdown('Sucursal Destino *', 'Seleccione', _sucursalesDestino, _destinoSeleccionado, (v) => setState(() => _destinoSeleccionado = v as int?))),
                        const SizedBox(width: 12),
                        Expanded(flex: 1, child: _buildTextField('Referencia', 'Opcional', controller: _referenciaController)),
                      ],
                    ),
                  ],
                ),
              ),

              // --- FORMULARIO MULTI-UNIDAD ---
              Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _lineaFormKey,
                  child: Column(
                    children: [
                      _buildDropdown('Producto a despachar *', 'Buscar...', _productos, _productoActual, (v) => setState(() => _productoActual = v as int?)),
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
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Mostramos el stock actual para que el almacenista sepa cuánto puede sacar
                          Text(
                            _productoActual != null ? 'Disponible: ${_productos.firstWhere((p) => p['id'] == _productoActual)['stock_actual']}' : '',
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                          Text(
                            'Total a sacar: ${_calcularTotalTemporal()} ${ _productoActual != null ? _productos.firstWhere((p) => p['id'] == _productoActual)['unidad_medida'] : ''}',
                            style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          onPressed: _agregarALaLista,
                          icon: const Icon(Icons.arrow_downward, color: Colors.white, size: 18),
                          label: const Text('Agregar a salida', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrangeAccent, padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(color: Colors.grey),

              // --- CARRITO ---
              Expanded(
                child: _listaSalidas.isEmpty
                  ? const Center(child: Text('La lista está vacía.', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: _listaSalidas.length,
                      itemBuilder: (context, index) {
                        final item = _listaSalidas[index];
                        return ListTile(
                          leading: CircleAvatar(backgroundColor: Colors.red.withValues(alpha: 0.2), child: const Icon(Icons.outbox, color: Colors.redAccent, size: 20)),
                          title: Text(item['nombre_producto'], style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Cajas = ${item['cajas']}, Piezas = ${item['piezas_sueltas']}\nTotal a restar: ${item['cantidad']} ${item['unidad']}'),
                          trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => _eliminarDeLaLista(index)),
                        );
                      },
                    ),
              ),

              Container(
                padding: const EdgeInsets.all(16),
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _guardarSalidaMasiva,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange.shade600, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : Text('Confirmar Despacho (${_listaSalidas.length} Insumos)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
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