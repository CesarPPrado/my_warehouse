import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RecipeFormScreen extends StatefulWidget {
  final Map<String, dynamic>? recetaAEditar; // <--- LA MAGIA PARA EDITAR

  const RecipeFormScreen({super.key, this.recetaAEditar});

  @override
  State<RecipeFormScreen> createState() => _RecipeFormScreenState();
}

class _RecipeFormScreenState extends State<RecipeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _tipoSeleccionado;
  final _productoResultanteController = TextEditingController();

  int? _ingredienteActual;
  final _cantidadController = TextEditingController();
  List<Map<String, dynamic>> _ingredientes = [];

  List<dynamic> _productos = [];
  bool _isLoading = false;

  final List<String> _tiposReceta = ['Kit', 'Pesaje'];

  @override
  void initState() {
    super.initState();
    _cargarDatosIniciales();
  }

  Future<void> _cargarDatosIniciales() async {
    try {
      final prods = await Supabase.instance.client.from('productos').select('id, nombre, unidad_medida').order('nombre');
      
      // Si estamos editando, cargamos la información que ya existía
      if (widget.recetaAEditar != null) {
        _tipoSeleccionado = widget.recetaAEditar!['tipo_receta'];
        _productoResultanteController.text = widget.recetaAEditar!['nombre_producto'];

        // Traemos los ingredientes actuales de esta receta
        final ingData = await Supabase.instance.client.from('receta_ingredientes').select().eq('receta_id', widget.recetaAEditar!['id']);
        
        List<Map<String, dynamic>> ingsCargados = [];
        for (var row in ingData) {
          // Buscamos la posición del producto en la lista
          final pIndex = prods.indexWhere((p) => p['id'] == row['producto_origen_id']);
          
          if (pIndex != -1) { // Si no es -1, significa que SÍ lo encontró
            final pInfo = prods[pIndex];
            ingsCargados.add({
              'producto_id': pInfo['id'],
              'nombre': pInfo['nombre'],
              'unidad': pInfo['unidad_medida'],
              'cantidad': row['cantidad_requerida'],
            });
          }
        }
        _ingredientes = ingsCargados;
      }

      if (mounted) setState(() => _productos = prods);
    } catch (e) {
      debugPrint('Error cargando iniciales: $e');
    }
  }

  void _agregarIngrediente() {
    if (_ingredienteActual == null || _cantidadController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona ingrediente y cantidad'), backgroundColor: Colors.orange));
      return;
    }
    final cantidad = num.tryParse(_cantidadController.text.trim());
    if (cantidad == null || cantidad <= 0) return;

    final prodInfo = _productos.firstWhere((p) => p['id'] == _ingredienteActual);
    setState(() {
      _ingredientes.add({'producto_id': _ingredienteActual, 'nombre': prodInfo['nombre'], 'unidad': prodInfo['unidad_medida'], 'cantidad': cantidad});
      _ingredienteActual = null;
      _cantidadController.clear();
    });
  }

  void _eliminarIngrediente(int index) => setState(() => _ingredientes.removeAt(index));

  Future<void> _guardarReceta() async {
    if (!_formKey.currentState!.validate() || _ingredientes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Revisa el nombre y los ingredientes'), backgroundColor: Colors.red));
      return;
    }
    setState(() => _isLoading = true);

    try {
      final nombreNuevoKit = _productoResultanteController.text.trim();

      // MODO CREAR
      if (widget.recetaAEditar == null) {
        // Escudo Anti-Duplicados
        final existe = await Supabase.instance.client.from('productos').select('id').ilike('nombre', nombreNuevoKit).maybeSingle();
        if (existe != null) throw '¡Ese Kit ya existe en el catálogo!';

        final productoInsertado = await Supabase.instance.client.from('productos').insert({'nombre': nombreNuevoKit, 'categoria': 'Producción', 'unidad_medida': 'Piezas', 'stock_minimo': 0, 'stock_actual': 0, 'piezas_por_caja': 1, 'tipo_articulo': _tipoSeleccionado}).select().single();
        final recetaInsertada = await Supabase.instance.client.from('recetas').insert({'producto_resultante_id': productoInsertado['id'], 'tipo_receta': _tipoSeleccionado}).select().single();
        
        List<Map<String, dynamic>> lineas = _ingredientes.map((ing) => {'receta_id': recetaInsertada['id'], 'producto_origen_id': ing['producto_id'], 'cantidad_requerida': ing['cantidad']}).toList();
        await Supabase.instance.client.from('receta_ingredientes').insert(lineas);
      } 
      // MODO EDITAR
      else {
        final idReceta = widget.recetaAEditar!['id'];
        final idProductoResultante = widget.recetaAEditar!['producto_resultante_id'];

        // Escudo Anti-Duplicados (Permitiendo el mismo nombre si es el mismo producto)
        final existe = await Supabase.instance.client.from('productos').select('id').ilike('nombre', nombreNuevoKit).neq('id', idProductoResultante).maybeSingle();
        if (existe != null) throw 'Ya existe otro producto con ese nombre';

        // Actualizamos nombre y tipo
        await Supabase.instance.client.from('productos').update({'nombre': nombreNuevoKit, 'tipo_articulo': _tipoSeleccionado}).eq('id', idProductoResultante);
        await Supabase.instance.client.from('recetas').update({'tipo_receta': _tipoSeleccionado}).eq('id', idReceta);

        // El truco de ingeniero para actualizar ingredientes: Borrar todos y volver a insertar la nueva lista
        await Supabase.instance.client.from('receta_ingredientes').delete().eq('receta_id', idReceta);
        List<Map<String, dynamic>> lineas = _ingredientes.map((ing) => {'receta_id': idReceta, 'producto_origen_id': ing['producto_id'], 'cantidad_requerida': ing['cantidad']}).toList();
        await Supabase.instance.client.from('receta_ingredientes').insert(lineas);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Guardado con éxito!'), backgroundColor: Colors.green));
      Navigator.pop(context); 
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _productoResultanteController.dispose();
    _cantidadController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.recetaAEditar == null ? 'Nueva Fórmula' : 'Editar Fórmula', style: const TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.orange.shade800),
      body: _productos.isEmpty ? const Center(child: CircularProgressIndicator()) : Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16), color: const Color(0xFF1A1A1A),
                child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Datos del Producto Final', style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Expanded(flex: 1, child: _buildDropdown('Tipo *', 'Seleccione', _tiposReceta, _tipoSeleccionado, (v) => setState(() => _tipoSeleccionado = v as String?), isString: true)),
                          const SizedBox(width: 12),
                          Expanded(flex: 2, child: _buildTextField('Nombre del Nuevo Kit/Bolsa *', 'Ej. Kit Capirotada', controller: _productoResultanteController, isRequired: true)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Ingredientes del nuevo Kit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    const Text('Los materiales que selecciones aquí, se descontarán del inventario cuando se fabrique.', style: TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic)),
                    const SizedBox(height: 16),
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(flex: 2, child: _buildDropdown('Ingrediente', 'Buscar...', _productos, _ingredienteActual, (v) => setState(() => _ingredienteActual = v as int?))),
                        const SizedBox(width: 12),
                        Expanded(flex: 1, child: _buildTextField('Cant.', '0', controller: _cantidadController, isNumber: true)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(alignment: Alignment.centerRight, child: ElevatedButton.icon(onPressed: _agregarIngrediente, icon: const Icon(Icons.add, color: Colors.white, size: 18), label: const Text('Agregar a la fórmula', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent))),
                  ],
                ),
              ),
              const Divider(color: Colors.grey),
              Expanded(
                child: _ingredientes.isEmpty ? const Center(child: Text('Sin ingredientes.', style: TextStyle(color: Colors.grey))) : ListView.builder(itemCount: _ingredientes.length, itemBuilder: (context, index) {
                        final ing = _ingredientes[index];
                        return ListTile(leading: const Icon(Icons.arrow_right_alt, color: Colors.orangeAccent), title: Text(ing['nombre'], style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text('Se restarán: ${ing['cantidad']} ${ing['unidad']}'), trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: () => _eliminarIngrediente(index)));
                      },
                    ),
              ),
              Container(padding: const EdgeInsets.all(16), width: double.infinity, child: ElevatedButton(onPressed: _isLoading ? null : _guardarReceta, style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade600, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Guardar Fórmula', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)))),
            ],
          ),
    );
  }

  Widget _buildTextField(String label, String hint, {TextEditingController? controller, bool isNumber = false, bool isRequired = false}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)), const SizedBox(height: 4), TextFormField(controller: controller, keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text, validator: isRequired ? (v) => v!.isEmpty ? 'Requerido' : null : null, decoration: InputDecoration(hintText: hint, filled: true, fillColor: const Color(0xFF2A2A2A), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)))]);
  }

  Widget _buildDropdown(String label, String hint, List<dynamic> items, dynamic selectedValue, Function(dynamic) onChanged, {bool isString = false}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)), const SizedBox(height: 4), DropdownButtonFormField<dynamic>(initialValue: selectedValue, isExpanded: true, decoration: InputDecoration(filled: true, fillColor: const Color(0xFF2A2A2A), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)), hint: Text(hint), items: items.map((item) { final value = isString ? item : item['id']; final text = isString ? item : item['nombre']; return DropdownMenuItem<dynamic>(value: value, child: Text(text)); }).toList(), onChanged: onChanged)]);
  }
}