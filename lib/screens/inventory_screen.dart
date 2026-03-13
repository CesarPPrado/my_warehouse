import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<dynamic> _productos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarInventario();
  }

  Future<void> _cargarInventario() async {
    try {
      final data = await Supabase.instance.client
          .from('productos')
          .select('id, nombre, stock_actual, unidad_medida, categoria, familia, equivalencia_base, stock_minimo')
          .order('nombre');

      if (mounted) {
        setState(() {
          _productos = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando inventario: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- EL MOTOR MATEMÁTICO ---
  List<Map<String, dynamic>> _generarInventarioTotalizado() {
    Map<String, double> totalesPorFamilia = {};
    Map<String, String> unidadPorFamilia = {};

    for (var p in _productos) {
      // Si el producto no tiene familia, usamos su propio nombre para que no se pierda
      String familia = (p['familia'] != null && p['familia'].toString().trim().isNotEmpty)
          ? p['familia']
          : p['nombre'];

      double stockFisico = (p['stock_actual'] ?? 0).toDouble();
      double equivalencia = (p['equivalencia_base'] ?? 1).toDouble();
      
      // LA MULTIPLICACIÓN MÁGICA
      double totalConvertido = stockFisico * equivalencia;

      // Sumamos al acumulador de esa familia
      totalesPorFamilia[familia] = (totalesPorFamilia[familia] ?? 0) + totalConvertido;

      // Intentamos capturar la "Unidad Base" (Ej. Litros o Kilos)
      // Buscamos el producto hermano que tenga equivalencia = 1 (que es el granel)
      if (equivalencia == 1.0 || !unidadPorFamilia.containsKey(familia)) {
        unidadPorFamilia[familia] = p['unidad_medida'] ?? '';
      }
    }

    // Convertimos el diccionario a una lista para poder mostrarla en pantalla
    List<Map<String, dynamic>> listaTotalizada = [];
    totalesPorFamilia.forEach((familia, total) {
      listaTotalizada.add({
        'familia': familia,
        'total': total,
        'unidad': unidadPorFamilia[familia] ?? '',
      });
    });

    // Ordenamos alfabéticamente
    listaTotalizada.sort((a, b) => a['familia'].compareTo(b['familia']));
    
    return listaTotalizada;
  }

  @override
  Widget build(BuildContext context) {
    // Generamos la lista matemática antes de dibujar la pantalla
    final listaTotalizada = _generarInventarioTotalizado();

    // DefaultTabController es lo que nos permite tener pestañas navegables
    return DefaultTabController(
      length: 2, // Número de pestañas
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Inventario General', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.orange.shade800,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 4,
            tabs: [
              Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Físico (Sacos/Bultos Completos)'),
              Tab(icon: Icon(Icons.calculate_outlined), text: 'Totalizado (KG/L/PZ Granel)'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  // --- PESTAÑA 1: INVENTARIO FÍSICO ---
                  _buildListaFisico(),

                  // --- PESTAÑA 2: INVENTARIO TOTALIZADO ---
                  _buildListaTotalizada(listaTotalizada),
                ],
              ),
      ),
    );
  }

  // Widget para la Pestaña 1 (Físico)
  Widget _buildListaFisico() {
    if (_productos.isEmpty) {
      return const Center(child: Text('No hay productos en el catálogo.', style: TextStyle(color: Colors.grey)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _productos.length,
      itemBuilder: (context, index) {
        final item = _productos[index];
        final num stock = item['stock_actual'] ?? 0;
        final num minimo = item['stock_minimo'] ?? 0;

        // Lógica de colores para alertas visuales rápidas
        Color colorStock = Colors.white;
        if (stock <= 0) {
          colorStock = Colors.redAccent;
        } else if (minimo > 0 && stock <= minimo) {
          colorStock = Colors.orangeAccent;
        }

        return Card(
          color: const Color(0xFF1A1A1A),
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(item['nombre'], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Categoría: ${item['categoria'] ?? 'N/A'}'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('$stock', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorStock)),
                Text(item['unidad_medida'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        );
      },
    );
  }

  // Widget para la Pestaña 2 (Totalizado)
  Widget _buildListaTotalizada(List<Map<String, dynamic>> lista) {
    if (lista.isEmpty) {
      return const Center(child: Text('No hay datos para totalizar.', style: TextStyle(color: Colors.grey)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: lista.length,
      itemBuilder: (context, index) {
        final item = lista[index];
        
        // Formateamos el número para que si es exacto (ej. 120.0) se vea como 120, pero si tiene decimales (ej 364.8) se vean
        String totalFormateado = item['total'].toString();
        if (totalFormateado.endsWith('.0')) {
          totalFormateado = totalFormateado.substring(0, totalFormateado.length - 2);
        }

        return Card(
          color: const Color(0xFF1A1A1A),
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Colors.green, width: 0.5), // Un borde verde para diferenciar que esta es la vista matemática
          ),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.green,
              child: Icon(Icons.functions, color: Colors.white),
            ),
            title: Text(item['familia'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            subtitle: const Text('Suma total de todos los empaques', style: TextStyle(color: Colors.grey, fontSize: 12)),
            trailing: Text(
              '$totalFormateado ${item['unidad']}', 
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.greenAccent)
            ),
          ),
        );
      },
    );
  }
}