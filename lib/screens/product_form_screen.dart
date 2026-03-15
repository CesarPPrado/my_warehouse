import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProductFormScreen extends StatefulWidget {
  final Map<String, dynamic>? productoAEditar;

  const ProductFormScreen({super.key, this.productoAEditar});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  final _nombreController = TextEditingController();
  final _stockMinimoController = TextEditingController();
  final _piezasPorCajaController = TextEditingController();
  
  // --- LOS NUEVOS CONTROLADORES ---
  final _familiaController = TextEditingController();
  final _equivalenciaController = TextEditingController();

  String? _categoriaSeleccionada;
  String? _unidadSeleccionada;

  final List<String> _categorias = ['Materia Prima', 'Producción', 'Empaque', 'Limpieza', 'Mantenimiento', 'Otros',  'Complementos', 'Harinas y Polvos'];
  final List<String> _unidades = ['Kilos', 'Gramos', 'Litros', 'Sacos', 'Bolsas', 'Costales', 'Piezas', 'Cajas', 'Bidones', 'Latas', 'Paquetes'];

  @override
  void initState() {
    super.initState();
    if (widget.productoAEditar != null) {
      _nombreController.text = widget.productoAEditar!['nombre'];
      _categoriaSeleccionada = widget.productoAEditar!['categoria'];
      _unidadSeleccionada = widget.productoAEditar!['unidad_medida'];
      _stockMinimoController.text = widget.productoAEditar!['stock_minimo'].toString();
      _piezasPorCajaController.text = (widget.productoAEditar!['piezas_por_caja'] ?? 1).toString();
      
      // --- CARGAR LOS NUEVOS DATOS AL EDITAR ---
      _familiaController.text = widget.productoAEditar!['familia'] ?? '';
      _equivalenciaController.text = (widget.productoAEditar!['equivalencia_base'] ?? 1).toString();
    } else {
      _piezasPorCajaController.text = '1';
      _equivalenciaController.text = '1'; // Por defecto es 1 a 1
    }
  }

  Future<void> _guardarProducto() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final piezasCaja = int.tryParse(_piezasPorCajaController.text.trim()) ?? 1;
      
      // --- LEER Y CONVERTIR LOS NUEVOS CAMPOS ---
      final familiaStr = _familiaController.text.trim().isEmpty ? null : _familiaController.text.trim();
      final equivalencia = double.tryParse(_equivalenciaController.text.trim()) ?? 1.0;

      if (widget.productoAEditar == null) {
        await Supabase.instance.client.from('productos').insert({
          'nombre': _nombreController.text.trim(),
          'categoria': _categoriaSeleccionada,
          'unidad_medida': _unidadSeleccionada,
          'stock_minimo': int.parse(_stockMinimoController.text.trim()),
          'stock_actual': 0,
          'piezas_por_caja': piezasCaja,
          'familia': familiaStr,
          'equivalencia_base': equivalencia,
        });
      } else {
        await Supabase.instance.client.from('productos').update({
          'nombre': _nombreController.text.trim(),
          'categoria': _categoriaSeleccionada,
          'unidad_medida': _unidadSeleccionada,
          'stock_minimo': int.parse(_stockMinimoController.text.trim()),
          'piezas_por_caja': piezasCaja,
          'familia': familiaStr,
          'equivalencia_base': equivalencia,
        }).eq('id', widget.productoAEditar!['id']);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.productoAEditar == null ? 'Producto guardado' : 'Producto actualizado', style: const TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _stockMinimoController.dispose();
    _piezasPorCajaController.dispose();
    _familiaController.dispose();
    _equivalenciaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.productoAEditar == null ? 'Nuevo Producto' : 'Editar Producto', style: const TextStyle(fontWeight: FontWeight.bold))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTextField('Nombre del Producto (Empaque) *', 'Ej. Frijol Mayocoba (Costal 25kg)', controller: _nombreController, isRequired: true),
              const SizedBox(height: 16),
              _buildDropdown('Categoría *', 'Seleccione', _categorias, (val) => setState(() => _categoriaSeleccionada = val), isRequired: true),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildDropdown('Unidad de Medida *', 'Ej. Costales', _unidades, (val) => setState(() => _unidadSeleccionada = val), isRequired: true)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildTextField('Stock Mínimo *', '5', controller: _stockMinimoController, isNumber: true, isRequired: true)),
                ],
              ),
              const SizedBox(height: 16),
              _buildTextField('Piezas por caja/empaque *', 'Ej. 24 (Dejar en 1 si es granel)', controller: _piezasPorCajaController, isNumber: true, isRequired: true),
              const SizedBox(height: 24),
              
              // --- SECCIÓN DE AGRUPACIÓN ---
              const Divider(color: Colors.grey),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text('Matemática de Inventario Totalizado', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: _buildTextField('Familia (Para agrupar)', 'Ej. Frijol Mayocoba', controller: _familiaController)),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: _buildTextField('Equivale a (KG/L/PZ) *', '(Dejar en 1 si es granel)', controller: _equivalenciaController, isNumber: true, isRequired: true)),
                ],
              ),
              const SizedBox(height: 32),
              // -------------------------------------

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _guardarProducto,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Guardar Producto', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, String hint, {TextEditingController? controller, bool isNumber = false, bool isRequired = false}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)), const SizedBox(height: 4), TextFormField(controller: controller, keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text, validator: isRequired ? (v) => v == null || v.isEmpty ? 'Requerido' : null : null, decoration: InputDecoration(hintText: hint, filled: true, fillColor: const Color(0xFF2A2A2A), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)))]);
  }

  Widget _buildDropdown(String label, String hint, List<String> items, Function(String?) onChanged, {bool isRequired = false}) {
    String? value;
    if (widget.productoAEditar != null && label.contains('Categoría')) value = _categoriaSeleccionada;
    if (widget.productoAEditar != null && label.contains('Unidad')) value = _unidadSeleccionada;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)), const SizedBox(height: 4), DropdownButtonFormField<String>(initialValue: value, isExpanded: true, decoration: InputDecoration(filled: true, fillColor: const Color(0xFF2A2A2A), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)), hint: Text(hint), items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(), onChanged: onChanged, validator: isRequired ? (v) => v == null ? 'Requerido' : null : null)]);
  }
}