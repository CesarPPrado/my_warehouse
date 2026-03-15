import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AreaAuditScreen extends StatefulWidget {
  const AreaAuditScreen({super.key});

  @override
  State<AreaAuditScreen> createState() => _AreaAuditScreenState();
}

class _AreaAuditScreenState extends State<AreaAuditScreen> {
  List<dynamic> _sucursales = [];
  dynamic _sucursalSeleccionada;
  
  // Lista que contendrá los insumos y sus controladores de texto
  List<Map<String, dynamic>> _listaAuditoria = [];
  
  final _produccionController = TextEditingController();
  final _observacionesController = TextEditingController();
  
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _cargarSucursales();
  }

  Future<void> _cargarSucursales() async {
    try {
      final sucs = await Supabase.instance.client.from('sucursales').select('id, nombre, tipo').order('nombre');
      if (mounted) {
        setState(() {
          _sucursales = sucs;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cargarPlantilla(dynamic sucursalId) async {
    if (sucursalId == null) return;
    setState(() => _isLoading = true);

    try {
      final stockData = await Supabase.instance.client.from('stock_ideal_areas').select().eq('sucursal_id', sucursalId);
      final prods = await Supabase.instance.client.from('productos').select('id, nombre, unidad_medida, stock_actual');

      List<Map<String, dynamic>> listaTemporal = [];
      for (var item in stockData) {
        final pIndex = prods.indexWhere((p) => p['id'] == item['producto_id']);
        if (pIndex != -1) {
          listaTemporal.add({
            'producto_id': item['producto_id'],
            'nombre': prods[pIndex]['nombre'],
            'unidad': prods[pIndex]['unidad_medida'],
            'stock_almacen_actual': prods[pIndex]['stock_actual'] ?? 0,
            'meta': item['cantidad_ideal'],
            // Controlador independiente para cada producto
            'controller': TextEditingController(), 
          });
        }
      }

      listaTemporal.sort((a, b) => a['nombre'].toString().compareTo(b['nombre'].toString()));

      if (mounted) {
        setState(() {
          _listaAuditoria = listaTemporal;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _procesarCierre() async {
    // 1. Validar que al menos haya escrito algo en los campos
    bool todosLlenos = _listaAuditoria.every((item) => item['controller'].text.trim().isNotEmpty);
    if (!todosLlenos) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor llena el conteo físico de todos los insumos (pon 0 si no hay).'), backgroundColor: Colors.orange));
      return;
    }

    // 2. --- NUEVO CANDADO DE SEGURIDAD ANTI-NEGATIVOS ---
    List<String> erroresStock = [];
    for (var item in _listaAuditoria) {
      final double meta = (item['meta'] as num).toDouble();
      final double fisico = double.tryParse(item['controller'].text.trim()) ?? 0.0;
      final double aSurtir = (meta - fisico > 0) ? (meta - fisico) : 0.0;
      final double stockActual = (item['stock_almacen_actual'] as num).toDouble();

      if (aSurtir > stockActual) {
        erroresStock.add('• ${item['nombre']}\n  (Pide: $aSurtir | Tienes: $stockActual)');
      }
    }

    if (erroresStock.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text('⚠️ Stock Insuficiente', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('No tienes suficiente mercancía en el Almacén Principal para surtir este cierre:', style: TextStyle(color: Colors.white)),
                const SizedBox(height: 12),
                Text(erroresStock.join('\n\n'), style: const TextStyle(color: Colors.orangeAccent, fontSize: 13)),
                const SizedBox(height: 12),
                const Text('Ajusta el almacén antes de continuar.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Entendido', style: TextStyle(color: Colors.grey))),
          ],
        ),
      );
      return; // Detenemos todo aquí
    }
    // ---------------------------------------------------

    // 3. Cuadro de confirmación original
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('¿Cerrar Turno y Surtir?', style: TextStyle(color: Colors.cyanAccent)),
        content: const Text('Esto registrará el conteo y generará automáticamente la SALIDA de almacén para reponer los faltantes.', style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Revisar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan.shade700),
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Confirmar Cierre', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar != true) return;
    setState(() => _isSaving = true);

    try {
      // A. Crear la Cabecera de la Auditoría
      final auditoriaResponse = await Supabase.instance.client.from('auditorias_cierre').insert({
        'sucursal_id': _sucursalSeleccionada,
        'produccion_reportada': {'texto': _produccionController.text.trim()},
        'observaciones': _observacionesController.text.trim()
      }).select().single();
      
      final auditoriaId = auditoriaResponse['id'];

      // B. Procesar fila por fila
      for (var item in _listaAuditoria) {
        final double meta = (item['meta'] as num).toDouble();
        final double fisico = double.tryParse(item['controller'].text.trim()) ?? 0.0;
        final double aSurtir = (meta - fisico > 0) ? (meta - fisico) : 0.0;

        // B1. Guardar el detalle del reporte
        await Supabase.instance.client.from('auditoria_detalles').insert({
          'auditoria_id': auditoriaId,
          'producto_id': item['producto_id'],
          'inventario_inicial': meta, 
          'existencia_fisica': fisico,
          'stock_ideal': meta,
          'cantidad_a_surtir': aSurtir
        });

        // B2. Generar Salida Automática de Almacén (si les faltó material)
        if (aSurtir > 0) {
          await Supabase.instance.client.from('movimientos').insert({
            'tipo_movimiento': 'Salida',
            'producto_id': item['producto_id'],
            'cantidad': aSurtir,
            'sucursal_id': _sucursalSeleccionada,
            'motivo': 'Resurtido aut. Cierre de Turno #$auditoriaId',
          });

          final stockActual = (item['stock_almacen_actual'] as num).toDouble();
          final nuevoStock = stockActual - aSurtir;
          await Supabase.instance.client.from('productos').update({'stock_actual': nuevoStock}).eq('id', item['producto_id']);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Cierre exitoso! Salidas generadas.'), backgroundColor: Colors.green));
        Navigator.pop(context); 
      }

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    for (var item in _listaAuditoria) {
      item['controller'].dispose();
    }
    _produccionController.dispose();
    _observacionesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Auditoría y Cierre', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.cyan.shade800),
      body: _isLoading && _sucursales.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // PANEL SUPERIOR: SELECCIÓN Y DATOS EXTRAS
                Container(
                  padding: const EdgeInsets.all(16),
                  color: const Color(0xFF1A1A1A),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<dynamic>(
                        initialValue: _sucursalSeleccionada,
                        decoration: InputDecoration(labelText: 'Área a auditar', filled: true, fillColor: const Color(0xFF2A2A2A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)),
                        items: _sucursales.map((s) => DropdownMenuItem(value: s['id'], child: Text('${s['nombre']} (${s['tipo']})'))).toList(),
                        onChanged: (val) {
                          setState(() => _sucursalSeleccionada = val);
                          _cargarPlantilla(val);
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _produccionController,
                              decoration: InputDecoration(labelText: 'Producción (Ej. 18.5kg Blanca)', filled: true, fillColor: const Color(0xFF2A2A2A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _observacionesController,
                              decoration: InputDecoration(labelText: 'Observaciones', filled: true, fillColor: const Color(0xFF2A2A2A), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // PANEL INFERIOR: TABLA DE CONTEO
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.cyan.withValues(alpha: 0.2),
                  child: const Row(
                    children: [
                      Expanded(flex: 2, child: Text('INSUMO', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.cyanAccent))),
                      Expanded(flex: 1, child: Text('FÍSICO', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.cyanAccent))),
                      Expanded(flex: 1, child: Text('SURTIR', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.cyanAccent))),
                    ],
                  ),
                ),

                Expanded(
                  child: _sucursalSeleccionada == null
                      ? const Center(child: Text('Selecciona un área para comenzar', style: TextStyle(color: Colors.grey)))
                      : _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _listaAuditoria.isEmpty
                              ? const Center(child: Text('El área no tiene Stock Base configurado.', style: TextStyle(color: Colors.grey)))
                              : ListView.builder(
                                  padding: const EdgeInsets.all(8),
                                  itemCount: _listaAuditoria.length,
                                  itemBuilder: (context, index) {
                                    final item = _listaAuditoria[index];
                                    
                                    // Cálculo en tiempo real de cuánto hay que surtir
                                    double fisico = double.tryParse(item['controller'].text) ?? 0.0;
                                    double aSurtir = (item['meta'] - fisico > 0) ? (item['meta'] - fisico) : 0.0;

                                    return Card(
                                      color: const Color(0xFF1A1A1A),
                                      margin: const EdgeInsets.only(bottom: 4),
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Row(
                                          children: [
                                            // COLUMNA 1: Nombre y Meta
                                            Expanded(
                                              flex: 2,
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(item['nombre'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                                  Text('Meta: ${item['meta']} ${item['unidad']}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                                ],
                                              ),
                                            ),
                                            // COLUMNA 2: Input para Conteo
                                            Expanded(
                                              flex: 1,
                                              child: TextField(
                                                controller: item['controller'],
                                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(color: Colors.yellowAccent, fontWeight: FontWeight.bold),
                                                decoration: const InputDecoration(hintText: '0', isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8)),
                                                onChanged: (val) => setState(() {}), // Refresca para actualizar el cálculo "A Surtir"
                                              ),
                                            ),
                                            // COLUMNA 3: Cálculo A Surtir
                                            Expanded(
                                              flex: 1,
                                              child: Text(
                                                '+$aSurtir', 
                                                textAlign: TextAlign.right, 
                                                style: TextStyle(color: aSurtir > 0 ? Colors.greenAccent : Colors.grey, fontWeight: FontWeight.bold, fontSize: 16)
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                ),

                // BOTÓN DE GUARDAR
                if (_sucursalSeleccionada != null && _listaAuditoria.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan.shade700, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      icon: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.check_circle, color: Colors.white),
                      label: Text(_isSaving ? 'Procesando...' : 'Cerrar Turno y Generar Salida', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      onPressed: _isSaving ? null : _procesarCierre,
                    ),
                  ),
              ],
            ),
    );
  }
}