import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProductFormScreen extends StatefulWidget {
  final Map<String, dynamic>? productoAEditar; // Variable opcional

  // Si nos mandan un producto, lo guardamos. Si no, es null (modo crear).
  const ProductFormScreen({super.key, this.productoAEditar});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _stockMinimoController = TextEditingController(text: '5'); // 5 por defecto
  final _piezasPorCajaController = TextEditingController();
  
  String? _categoriaSeleccionada;
  String? _unidadSeleccionada;
  bool _isLoading = false; // Controla el estado del botón de guardar

  @override
  void initState() {
    super.initState();
    // Si recibimos un producto para editar, llenamos los controladores
    if (widget.productoAEditar != null) {
      _nombreController.text = widget.productoAEditar!['nombre'];
      _categoriaSeleccionada = widget.productoAEditar!['categoria'];
      _unidadSeleccionada = widget.productoAEditar!['unidad_medida'];
      _stockMinimoController.text = widget.productoAEditar!['stock_minimo'].toString();
      _piezasPorCajaController.text = (widget.productoAEditar!['piezas_por_caja'] ?? 1).toString();
      } else {
      _piezasPorCajaController.text = '1'; // Por defecto es 1
    }
  }

  // Las listas reales del almacén
  final List<String> _categorias = ['Materia Prima', 'Empaque', 'Harinas y Polvos', 'Mantecas y Lácteos', 'Complementos'];
  final List<String> _unidades = ['Sacos', 'Kilos', 'Litros', 'Costales', 'Paquetes', 'Piezas', 'Rollos', 'Cajas', 'Bolsitas', 'Kits', 'Latas', 'Bidones'];

  // Función asíncrona para inyectar a PostgreSQL
  Future<void> _guardarProducto() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Convertimos el texto del controlador a número (si está vacío, por defecto es 1)
      final piezasCaja = int.tryParse(_piezasPorCajaController.text.trim()) ?? 1;

      if (widget.productoAEditar == null) {
        // MODO CREAR: Hacemos un INSERT normal
        await Supabase.instance.client.from('productos').insert({
          'nombre': _nombreController.text.trim(),
          'categoria': _categoriaSeleccionada,
          'unidad_medida': _unidadSeleccionada,
          'stock_minimo': int.parse(_stockMinimoController.text.trim()),
          'stock_actual': 0,
          'piezas_por_caja': piezasCaja,
        });
      } else {
        // MODO EDITAR: Hacemos un UPDATE usando el ID
        await Supabase.instance.client.from('productos').update({
          'nombre': _nombreController.text.trim(),
          'categoria': _categoriaSeleccionada,
          'unidad_medida': _unidadSeleccionada,
          'stock_minimo': int.parse(_stockMinimoController.text.trim()),
          'piezas_por_caja': piezasCaja,
        }).eq('id', widget.productoAEditar!['id']);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.productoAEditar == null ? 'Producto guardado' : 'Producto actualizado', style: const TextStyle(fontWeight: FontWeight.bold)), 
            backgroundColor: Colors.green
          ),
        );
        Navigator.pop(context); 
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
    _nombreController.dispose();
    _stockMinimoController.dispose();
    _piezasPorCajaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.productoAEditar == null ? 'Nuevo Registro' : 'Editar Registro',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green.shade800,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTextField('Nombre del Producto *', 'Ej. Harina Extra Fina', controller: _nombreController, isRequired: true),
              const SizedBox(height: 16),
              
              _buildDropdown('Categoría *', 'Seleccione familia', _categorias, (val) => _categoriaSeleccionada = val, true),
              const SizedBox(height: 16),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildDropdown('Unidad de Medida *', 'Ej. Sacos', _unidades, (val) => _unidadSeleccionada = val, true)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildTextField('Piezas por caja/empaque *', 'Ej. 24 (Dejar en 1 si es granel)', controller: _piezasPorCajaController, isNumber: true, isRequired: true)),
                  const SizedBox(height: 16),
                  Expanded(child: _buildTextField('Stock Mínimo (Alerta) *', '5', controller: _stockMinimoController, isNumber: true, isRequired: true)),
                ],
              ),
              const SizedBox(height: 32),

              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _guardarProducto,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.greenAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                    : const Text('Guardar Producto', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widgets reutilizables de UI
  Widget _buildTextField(String label, String hint, {required TextEditingController controller, bool isNumber = false, bool isRequired = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
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

  Widget _buildDropdown(String label, String hint, List<String> items, Function(String?) onChanged, bool isRequired) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          validator: isRequired ? (value) => value == null ? 'Seleccione' : null : null,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF1A1A1A),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
          hint: Text(hint),
          items: items.map((String value) => DropdownMenuItem<String>(value: value, child: Text(value))).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}