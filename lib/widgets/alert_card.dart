import 'package:flutter/material.dart';

class AlertCard extends StatelessWidget {
  final String productName;
  final String stock;
  final String status;
  final Color statusColor;

  const AlertCard({
    super.key,
    required this.productName,
    required this.stock,
    required this.status,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12), // Separación entre tarjetas
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A), // Un gris un poquito más claro que el fondo
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10), // Borde sutil
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Textos de la tarjeta
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                productName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                'Stock actual: $stock',
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ),
          // Etiqueta de estado (CRÍTICO / BAJO)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15), // Fondo semitransparente
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withValues(alpha: 0.5)),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}