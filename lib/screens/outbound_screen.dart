import 'package:flutter/material.dart';

class OutboundScreen extends StatefulWidget {
  const OutboundScreen({super.key});

  @override
  State<OutboundScreen> createState() => _OutboundScreenState();
}

class _OutboundScreenState extends State<OutboundScreen> {
  // Llave global para validar el formulario completo
  final _formKey = GlobalKey<FormState>();

  String? _productoSeleccionado;
  String? _origenSeleccionado;
  String? _destinoSeleccionado;
  final TextEditingController _cantidadController = TextEditingController();

  final List<String> _productos = ['Harina rosal saco 25 kg', 'Maseca Tío Toño', 'Frijol mayocoba'];
  final List<String> _sucursales = ['Proveedor Externo', 'Bodega Principal', 'Producción Frijoles', 'Colorado', 'Florido'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Salida de Mercancía', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue.shade800, // Color distintivo para evitar errores
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey, // Envolvemos todo en un Form
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Detalles de Salida', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              // PRODUCTO (Obligatorio)
              _buildDropdown('Producto *', 'Seleccione...', _productos, (val) => _productoSeleccionado = val, true),
              const SizedBox(height: 16),

              // CANTIDAD (Obligatorio) y FACTURA
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildTextField('Cantidad *', 'Ej. 10', isNumber: true, isRequired: true, controller: _cantidadController)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildTextField('Factura', 'Ej. FAC-123', isRequired: false)),
                ],
              ),
              const SizedBox(height: 16),
              
              _buildTextField('Lote', 'Ej. L-2026-A', isRequired: false),
              const SizedBox(height: 16),

              // ORIGEN Y DESTINO (Obligatorios)
              _buildDropdown('Sucursal/Área Origen *', '¿De dónde viene?', _sucursales, (val) => _origenSeleccionado = val, true),
              const SizedBox(height: 16),
              _buildDropdown('Sucursal/Área Destino *', '¿A dónde entra?', _sucursales, (val) => _destinoSeleccionado = val, true),
              const SizedBox(height: 32),

              // BOTÓN GUARDAR CON VALIDACIÓN
              ElevatedButton(
                onPressed: () {
                  // Si el formulario es válido, procede a guardar
                  if (_formKey.currentState!.validate()) {
                    debugPrint('Guardando Salida de $_productoSeleccionado, de $_origenSeleccionado hacia $_destinoSeleccionado');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Salida registrada con éxito'), backgroundColor: Colors.green),
                    );
                    Navigator.pop(context); // Regresa al menú
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Confirmar Salida', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widgets mejorados con validación (TextFormField en lugar de TextField)
  Widget _buildTextField(String label, String hint, {bool isNumber = false, bool isRequired = false, TextEditingController? controller}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          validator: isRequired ? (value) {
            if (value == null || value.isEmpty) return 'Requerido';
            return null;
          } : null,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: const Color(0xFF1A1A1A),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            errorStyle: const TextStyle(color: Colors.redAccent),
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
          validator: isRequired ? (value) => value == null ? 'Seleccione una opción' : null : null,
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