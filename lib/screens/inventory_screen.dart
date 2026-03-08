import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  // Canal de comunicación en tiempo real con Supabase
  final _productosStream = Supabase.instance.client
      .from('productos')
      .stream(primaryKey: ['id'])
      .order('nombre', ascending: true); // Los ordenamos alfabéticamente

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventario General', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Barra de Búsqueda (Visual por ahora)
            TextField(
              decoration: InputDecoration(
                hintText: 'Buscar producto...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.qr_code_scanner, color: Colors.greenAccent),
                  onPressed: () { debugPrint("Abrir cámara"); },
                ),
                filled: true,
                fillColor: const Color(0xFF1A1A1A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),

            // Pestañas de Categorías
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('Todos', true),
                  _buildFilterChip('Batida', false),
                  _buildFilterChip('Empaque', false),
                  _buildFilterChip('Frijoles', false),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Escuchando a PostgreSQL
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _productosStream,
                builder: (context, snapshot) {
                  // Mientras carga la primera vez
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Colors.greenAccent));
                  }
                  
                  // Si hay algún error de conexión
                  if (snapshot.hasError) {
                    return Center(child: Text('Error de conexión: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
                  }

                  final productos = snapshot.data ?? [];

                  // Si la base de datos está vacía
                  if (productos.isEmpty) {
                    return const Center(child: Text('No hay productos en el inventario', style: TextStyle(color: Colors.grey)));
                  }

                  // Mostramos la lista real
                  return ListView.builder(
                    itemCount: productos.length,
                    itemBuilder: (context, index) {
                      final p = productos[index];
                      
                      // Lógica de inventario inteligente
                      final num stockActual = p['stock_actual'];
                      final num stockMinimo = p['stock_minimo'];
                      
                      String statusText;
                      Color statusColor;

                      if (stockActual == 0) {
                        statusText = 'AGOTADO';
                        statusColor = Colors.redAccent;
                      } else if (stockActual <= stockMinimo) {
                        statusText = 'BAJO';
                        statusColor = Colors.amber;
                      } else {
                        statusText = 'OK';
                        statusColor = Colors.green;
                      }

                      return ProductListCard(
                        name: p['nombre'],
                        category: p['categoria'],
                        stock: '$stockActual ${p['unidad_medida']}',
                        status: statusText,
                        statusColor: statusColor,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? Colors.green.shade600 : const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.grey.shade400, fontWeight: FontWeight.bold)),
    );
  }
}

// El mismo widget de tarjeta que ya teniamos
class ProductListCard extends StatelessWidget {
  final String name;
  final String category;
  final String stock;
  final String status;
  final Color statusColor;

  const ProductListCard({
    super.key, required this.name, required this.category, required this.stock, required this.status, required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text('Categoría: $category', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.circle, size: 12, color: statusColor),
                    const SizedBox(width: 6),
                    Text(stock, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: statusColor.withValues(alpha: 0.5)),
            ),
            child: Text(status, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}