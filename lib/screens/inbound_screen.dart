import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InboundScreen extends StatefulWidget {
  const InboundScreen({super.key});

  @override
  State<InboundScreen> createState() => _InboundScreenState();
}

class _InboundScreenState extends State<InboundScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cantidadController = TextEditingController();
  final _facturaController = TextEditingController();
  final _loteController = TextEditingController();

  int? _productoSeleccionado;
  int? _origenSeleccionado;
  int? _destinoSeleccionado;
  bool _isLoading = false;

  // Listas vacías que se llenarán con los datos reales de la base de datos
  List<dynamic> _productos = [];
  List<dynamic> _sucursales = [];

  @override
  void initState() {
    super.initState();
    _cargarCatalogos();
  }

  // 1. Descarga los catálogos en tiempo real
  Future<void> _cargarCatalogos() async {
    try {
      final prods = await Supabase.instance.client.from('productos').select('id, nombre, stock_actual, unidad_medida').order('nombre');
      final sucs = await Supabase.instance.client.from('sucursales').select('id, nombre').order('nombre');

      if (mounted) {
        setState(() {
          _productos = prods;
          _sucursales = sucs;
        });
      }
    } catch (e) {
      debugPrint('Error al cargar catálogos: $e');
    }
  }

  // 2. La lógica matemática y de base de datos
  Future<void> _guardarEntrada() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final cantidadAIngresar = num.parse(_cantidadController.text.trim());

      // A. Calculamos el nuevo stock en memoria
      final productoActual = _productos.firstWhere((p) => p['id'] == _productoSeleccionado);
      final nuevoStock = productoActual['stock_actual'] + cantidadAIngresar;

      // B. Registramos el ticket en el historial (movimientos)
      await Supabase.instance.client.from('movimientos').insert({
        'tipo_movimiento': 'Entrada',
        'producto_id': _productoSeleccionado,
        'cantidad': cantidadAIngresar,
        'factura': _facturaController.text.trim().isEmpty ? null : _facturaController.text.trim(),
        'lote': _loteController.text.trim().isEmpty ? null : _loteController.text.trim(),
        'origen_id': _origenSeleccionado,
        'destino_id': _destinoSeleccionado,
      });

      // C. Actualizamos la cantidad física en el almacén (productos)
      await Supabase.instance.client.from('productos').update({
        'stock_actual': nuevoStock,
      }).eq('id', _productoSeleccionado!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Entrada registrada y stock sumado!', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.green),
        );
        Navigator.pop(context); // Regresamos al menú principal
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _cantidadController.dispose();
    _facturaController.dispose();
    _loteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Entrada de Mercancía', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green.shade800,
        centerTitle: true,
      ),
      // Si las listas están vacías, mostramos un círculo de carga
      body: _productos.isEmpty 
        ? const Center(child: CircularProgressIndicator(color: Colors.greenAccent))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Detalles de Entrada', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),

                  _buildDropdown('Producto *', 'Seleccione...', _productos, _productoSeleccionado, (val) => setState(() => _productoSeleccionado = val as int?), true),
                  const SizedBox(height: 16),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildTextField('Cantidad *', 'Ej. 10', isNumber: true, isRequired: true, controller: _cantidadController)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildTextField('Factura (Opcional)', 'Ej. FAC-123', controller: _facturaController)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  _buildTextField('Lote (Opcional)', 'Ej. L-2026-A', controller: _loteController),
                  const SizedBox(height: 16),

                  _buildDropdown('Sucursal/Área Origen *', '¿De dónde viene?', _sucursales, _origenSeleccionado, (val) => setState(() => _origenSeleccionado = val as int?), true),
                  const SizedBox(height: 16),
                  
                  _buildDropdown('Sucursal/Área Destino *', '¿A dónde entra?', _sucursales, _destinoSeleccionado, (val) => setState(() => _destinoSeleccionado = val as int?), true),
                  const SizedBox(height: 32),

                  SizedBox(
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _guardarEntrada,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Confirmar Entrada', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  // Widgets adaptados para leer los IDs y Nombres reales de la base de datos
  Widget _buildTextField(String label, String hint, {bool isNumber = false, bool isRequired = false, TextEditingController? controller}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
          validator: isRequired ? (value) => (value == null || value.isEmpty) ? 'Requerido' : null : null,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: const Color(0xFF1A1A1A),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown(String label, String hint, List<dynamic> items, int? selectedValue, Function(dynamic) onChanged, bool isRequired) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          initialValue: selectedValue,
          validator: isRequired ? (value) => value == null ? 'Requerido' : null : null,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF1A1A1A),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
          hint: Text(hint),
          items: items.map((item) => DropdownMenuItem<int>(
            value: item['id'], 
            child: Text(item['nombre'], overflow: TextOverflow.ellipsis)
          )).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}