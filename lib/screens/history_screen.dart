import 'package:flutter/material.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Movimientos', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildHistoryCard(
            'Salida a Producción', 'Frijol Mayocoba', '2 Costales', 
            'Entregado a: Irene (Frijoles)', 'Hace 2 horas', Colors.blue
          ),
          _buildHistoryCard(
            'Pasaje / Kit', 'Kit Chorizo 100KG', '1 Kit', 
            'Procesado por: Victor Salazar', 'Hace 5 horas', Colors.purple
          ),
          _buildHistoryCard(
            'Entrada Proveedor', 'Maseca Tío Toño', '15 Sacos', 
            'Factura: FAC-8922', 'Ayer', Colors.green
          ),
          _buildHistoryCard(
            'Salida a Sucursal', 'Harina Bonfil', '4 Bolsas', 
            'Destino: Sucursal Colorado', 'Ayer', Colors.blue
          ),
        ],
      ),
    );
  }

  // Widget para las tarjetas del historial
  Widget _buildHistoryCard(String type, String product, String amount, String detail, String time, Color color) {
    return Card(
      color: const Color(0xFF1A1A1A),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.2), child: Icon(Icons.history, color: color)),
        title: Text(product, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(type, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
            Text(detail, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(amount, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 4),
            Text(time, style: const TextStyle(color: Colors.grey, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}