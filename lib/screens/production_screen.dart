import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProductionScreen extends StatefulWidget {
  const ProductionScreen({super.key});

  @override
  State<ProductionScreen> createState() => _ProductionScreenState();
}

class _ProductionScreenState extends State<ProductionScreen> {
  List<Map<String, dynamic>> _recetas = [];
  Map<String, dynamic>? _recetaSeleccionada;
  
  final _cantidadController = TextEditingController(text: '1');
  final _buscadorRecetaController = TextEditingController(); // <--- NUEVO CONTROLADOR PARA EL BUSCADOR
  
  List<Map<String, dynamic>> _ingredientes = [];
  
  bool _isLoading = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _cargarRecetas();
  }

  Future<void> _cargarRecetas() async {
    try {
      final recetasData = await Supabase.instance.client.from('recetas').select();
      final productosData = await Supabase.instance.client.from('productos').select('id, nombre, unidad_medida');

      List<Map<String, dynamic>> lista = [];
      for (var r in recetasData) {
        final pIndex = productosData.indexWhere((p) => p['id'] == r['producto_resultante_id']);
        if (pIndex != -1) {
          final prod = productosData[pIndex];
          lista.add({
            'id': r['id'],
            'producto_resultante_id': r['producto_resultante_id'],
            'nombre': prod['nombre'],
            'unidad': prod['unidad_medida'],
            'tipo_receta': r['tipo_receta']
          });
        }
      }
      
      lista.sort((a, b) => a['nombre'].compareTo(b['nombre']));

      if (mounted) {
        setState(() {
          _recetas = lista;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando recetas: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cargarIngredientes(int recetaId) async {
    setState(() => _isLoading = true);
    try {
      final ingData = await Supabase.instance.client.from('receta_ingredientes').select().eq('receta_id', recetaId);
      final productosData = await Supabase.instance.client.from('productos').select('id, nombre, unidad_medida, stock_actual');

      List<Map<String, dynamic>> listaIng = [];
      for (var row in ingData) {
        final pIndex = productosData.indexWhere((p) => p['id'] == row['producto_origen_id']);
        if (pIndex != -1) {
          final p = productosData[pIndex];
          listaIng.add({
            'producto_id': p['id'],
            'nombre': p['nombre'],
            'unidad': p['unidad_medida'],
            'stock_actual': p['stock_actual'],
            'cantidad_base': row['cantidad_requerida'], 
          });
        }
      }
      if (mounted) setState(() => _ingredientes = listaIng);
    } catch (e) {
      debugPrint('Error cargando ingredientes: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _procesarProduccion() async {
    if (_recetaSeleccionada == null) return;
    
    final cantidadAProducir = double.tryParse(_cantidadController.text.trim());
    if (cantidadAProducir == null || cantidadAProducir <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingresa una cantidad válida a producir'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isProcessing = true);
    try {
      // Candado de seguridad
      for (var ing in _ingredientes) {
        double requeridoTotal = ing['cantidad_base'] * cantidadAProducir;
        double stockActual = (ing['stock_actual'] ?? 0).toDouble();
        
        if (stockActual < requeridoTotal) {
          throw '⚠️ STOCK INSUFICIENTE\nNo hay suficiente ${ing['nombre']}.\nNecesitas: $requeridoTotal ${ing['unidad']}\nTienes: $stockActual ${ing['unidad']}';
        }
      }

      // Descontar inventario
      for (var ing in _ingredientes) {
        double requeridoTotal = ing['cantidad_base'] * cantidadAProducir;
        double nuevoStockIngrediente = (ing['stock_actual'] ?? 0).toDouble() - requeridoTotal;
        await Supabase.instance.client.from('productos').update({'stock_actual': nuevoStockIngrediente}).eq('id', ing['producto_id']);
      }

      // Sumar producto resultante
      final prodResultanteId = _recetaSeleccionada!['producto_resultante_id'];
      final prodResultanteData = await Supabase.instance.client.from('productos').select('stock_actual').eq('id', prodResultanteId).single();
      
      double nuevoStockResultante = (prodResultanteData['stock_actual'] ?? 0).toDouble() + cantidadAProducir;
      await Supabase.instance.client.from('productos').update({'stock_actual': nuevoStockResultante}).eq('id', prodResultanteId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('¡Se fabricaron $cantidadAProducir ${_recetaSeleccionada!['nombre']} con éxito!'), backgroundColor: Colors.green));
        Navigator.pop(context); 
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString(), style: const TextStyle(height: 1.5)), backgroundColor: Colors.redAccent, duration: const Duration(seconds: 4)));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  void dispose() {
    _cantidadController.dispose();
    _buscadorRecetaController.dispose(); // <--- LIMPIAMOS MEMORIA
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double multiplicador = double.tryParse(_cantidadController.text.trim()) ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Módulo de Producción', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.purple.shade700),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // --- PANEL SUPERIOR: SELECCIÓN ---
                Container(
                  padding: const EdgeInsets.all(16),
                  color: const Color(0xFF1A1A1A),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- EL NUEVO BUSCADOR IMPLEMENTADO ---
                      _buildSearchableDropdown(
                        '¿Qué vas a fabricar/pesar?', 
                        'Escribe para buscar kit...', 
                        _recetas, 
                        _recetaSeleccionada, 
                        _buscadorRecetaController, 
                        (val) {
                          setState(() => _recetaSeleccionada = val);
                          if (val != null) _cargarIngredientes(val['id']);
                        }
                      ),
                      
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Text('Cantidad a producir:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const Spacer(),
                          SizedBox(
                            width: 100,
                            child: TextFormField(
                              controller: _cantidadController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                              decoration: InputDecoration(filled: true, fillColor: const Color(0xFF2A2A2A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)),
                              onChanged: (val) => setState(() {}), 
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // --- PANEL INFERIOR: RESUMEN DE MATERIALES ---
                Expanded(
                  child: _recetaSeleccionada == null
                      ? const Center(child: Text('Selecciona una fórmula arriba', style: TextStyle(color: Colors.grey)))
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Text('Material a descontar del inventario:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                            ),
                            Expanded(
                              child: ListView.builder(
                                itemCount: _ingredientes.length,
                                itemBuilder: (context, index) {
                                  final ing = _ingredientes[index];
                                  final gastar = ing['cantidad_base'] * multiplicador;
                                  final stock = ing['stock_actual'] ?? 0;
                                  final bool alcanza = stock >= gastar;

                                  return ListTile(
                                    leading: Icon(alcanza ? Icons.check_circle : Icons.error, color: alcanza ? Colors.green : Colors.red),
                                    title: Text(ing['nombre'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text('Stock actual: $stock ${ing['unidad']}'),
                                    trailing: Text('- $gastar ${ing['unidad']}', style: TextStyle(color: alcanza ? Colors.orangeAccent : Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                ),

                // --- BOTÓN DE CONFIRMACIÓN ---
                Container(
                  padding: const EdgeInsets.all(16),
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: (_isProcessing || _recetaSeleccionada == null) ? null : _procesarProduccion,
                    icon: _isProcessing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.precision_manufacturing, color: Colors.white),
                    label: Text(_isProcessing ? 'Procesando...' : 'Confirmar Producción', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade600, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                ),
              ],
            ),
    );
  }

  // --- WIDGET BUSCADOR REUTILIZABLE ---
  Widget _buildSearchableDropdown(String label, String hint, List<Map<String, dynamic>> items, Map<String, dynamic>? selectedValue, TextEditingController controller, Function(Map<String, dynamic>?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            return DropdownMenu<Map<String, dynamic>>(
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
                return DropdownMenuEntry<Map<String, dynamic>>(
                  value: item,
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