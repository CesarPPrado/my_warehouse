import 'package:flutter/material.dart';

class ProductionScreen extends StatefulWidget {
  const ProductionScreen({super.key});

  @override
  State<ProductionScreen> createState() => _ProductionScreenState();
}

class _ProductionScreenState extends State<ProductionScreen> {
  String? _formulaSeleccionada;
  final TextEditingController _cantidadController = TextEditingController(text: '1');

  // Aquí mapeamos las recetas exactas de nuestros documentos
  final Map<String, List<String>> _recetas = {
    'Compuesto Chico (Batida)': [
      '- 150 grs de Royal',
      '- 400 grs de Sal'
    ],
    'Compuesto Grande (Batida)': [
      '- 250 grs de Royal',
      '- 800 grs de Sal'
    ],
    'Kit para Chorizo 100KG': [
      '- 1 Paquete de Chiles',
      '- .800 grs Pimentón Rojo',
      '- 2 Kilos Ajo Entero',
      '- 1.5 Lt Vinagre',
      '- 1.9 Kilos Sal Granulada'
    ],
    'Kit Capirotada': [
      '- .250 grs Pasas',
      '- .500 grs Ciruela s/hueso',
      '- .250 grs Piña',
      '- 1 pza Piloncillo Obscuro'
    ],
    'Pasaje: Panarina Blanca': [
      '- 1 Saco 25kg (Se le quitarán 3kg para quedar en 22kg)'
    ]
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Módulo de Producción', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Seleccione la Fórmula o Pasaje', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            
            // Selector de Receta
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF1A1A1A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                prefixIcon: const Icon(Icons.science, color: Colors.purpleAccent),
              ),
              hint: const Text('Ej. Compuesto Chico...'),
              items: _recetas.keys.map((String formula) => DropdownMenuItem<String>(value: formula, child: Text(formula))).toList(),
              onChanged: (val) => setState(() => _formulaSeleccionada = val),
            ),
            
            const SizedBox(height: 24),
            
            Row(
              children: [
                const Expanded(flex: 2, child: Text('Cantidad a producir:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                Expanded(
                  flex: 1,
                  child: TextField(
                    controller: _cantidadController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    onChanged: (val) => setState(() {}), // Refresca la vista al cambiar cantidad
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF1A1A1A),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Tarjeta de Desglose de Materiales (Solo se muestra si hay algo seleccionado)
            if (_formulaSeleccionada != null) ...[
              const Text('Materiales que se descontarán del inventario:', style: TextStyle(fontSize: 14, color: Colors.amber)),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _recetas[_formulaSeleccionada]!.map((ingrediente) => Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(ingrediente, style: const TextStyle(fontSize: 16)),
                  )).toList(),
                ),
              ),
              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: () {
                  debugPrint('Procesando ${_cantidadController.text}x $_formulaSeleccionada');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple.shade600,
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Confirmar Producción', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ]
          ],
        ),
      ),
    );
  }
}