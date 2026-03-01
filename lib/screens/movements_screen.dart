import 'package:flutter/material.dart';

class MovementsScreen extends StatefulWidget {
  const MovementsScreen({super.key});

  @override
  State<MovementsScreen> createState() => _MovementsScreenState();
}

class _MovementsScreenState extends State<MovementsScreen> {
  // Variables para controlar el formulario
  String _tipoMovimiento = 'Entrada';
  String? _productoSeleccionado;
  String? _destinoSeleccionado;
  
  // Listas extraídas de los documentos reales de "La Sinaloa"
  final List<String> _productosBatida = [
    'Harina rosal saco 25 kg',
    'Maseca Tío Toño',
    'Maíz Blanco',
    'Frijol mayocoba',
    'Mexenil .090 gr',
    'Bolsa Camiseta Reforzada'
  ];

  final List<String> _destinos = [
    'Bodega Principal (Batida)',
    'Producción Frijoles',
    'Colorado',
    'Villa',
    'Florido',
    'Brisas',
    'Murua',
    'Venecia',
    'La mejor (nat 1)'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registro de Movimientos', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Selector de Entrada o Salida
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _tipoMovimiento = 'Entrada'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: _tipoMovimiento == 'Entrada' ? Colors.green.shade700 : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(child: Text('Entrada', style: TextStyle(fontWeight: FontWeight.bold))),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _tipoMovimiento = 'Salida'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: _tipoMovimiento == 'Salida' ? Colors.blue.shade700 : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(child: Text('Salida', style: TextStyle(fontWeight: FontWeight.bold))),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Formulario basado en el documento "Control de Entrada y Salidas"
            const Text('Detalles del Movimiento', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            _buildDropdown('Producto', 'Seleccionar producto...', _productosBatida, (val) => setState(() => _productoSeleccionado = val)),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(child: _buildTextField('Cantidad', '0.0', isNumber: true)),
                const SizedBox(width: 16),
                Expanded(child: _buildTextField('Factura', 'Ej. FAC-123')),
              ],
            ),
            const SizedBox(height: 16),

            _buildTextField('Lote', 'Ej. L-2026-A'),
            const SizedBox(height: 16),

            // El destino cambia dependiendo si es entrada o salida, pero usamos tu lista de sucursales reales
            _buildDropdown('Destino / Origen', 'Seleccionar sucursal/área...', _destinos, (val) => setState(() => _destinoSeleccionado = val)),
            const SizedBox(height: 32),

            // Botón de Guardar
            ElevatedButton(
              onPressed: () {
                debugPrint('Guardando $_tipoMovimiento de $_productoSeleccionado hacia/desde: $_destinoSeleccionado');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _tipoMovimiento == 'Entrada' ? Colors.green.shade600 : Colors.blue.shade600,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Guardar Registro', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // Widgets auxiliares para limpiar el código
  Widget _buildTextField(String label, String hint, {bool isNumber = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 8),
        TextField(
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
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

  Widget _buildDropdown(String label, String hint, List<String> items, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
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