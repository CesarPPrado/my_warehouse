import 'package:flutter/material.dart';

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

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
            // Barra de Búsqueda
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
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Pestañas de Categorías (Scroll Horizontal)
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

            // Lista de Productos
            Expanded(
              child: ListView(
                children: const [
                  ProductListCard(
                    name: 'Harina de Trigo (50kg)',
                    category: 'Batida',
                    stock: '3 Sacos',
                    status: 'CRÍTICO',
                    statusColor: Colors.redAccent,
                  ),
                  ProductListCard(
                    name: 'Royal Polvo (1kg)',
                    category: 'Batida',
                    stock: '5 Cajas',
                    status: 'BAJO',
                    statusColor: Colors.amber,
                  ),
                  ProductListCard(
                    name: 'Sal Refinada (500g)',
                    category: 'Especias',
                    stock: '8 Paquetes',
                    status: 'BAJO',
                    statusColor: Colors.amber,
                  ),
                  ProductListCard(
                    name: 'Bolsas de Plástico (1000u)',
                    category: 'Empaque',
                    stock: '45 Paquetes',
                    status: 'OK',
                    statusColor: Colors.green,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget pequeño para las "pestañas" de categorías
  Widget _buildFilterChip(String label, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? Colors.green.shade600 : const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.grey.shade400,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// Widget reutilizable para cada producto en la lista
class ProductListCard extends StatelessWidget {
  final String name;
  final String category;
  final String stock;
  final String status;
  final Color statusColor;

  const ProductListCard({
    super.key,
    required this.name,
    required this.category,
    required this.stock,
    required this.status,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
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