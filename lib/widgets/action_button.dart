import 'package:flutter/material.dart';

class ActionButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final EdgeInsetsGeometry? padding; 

  const ActionButton({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        // Si nos mandan un padding, lo usamos; si no, ponemos un margen de 16 por defecto.
        padding: padding ?? const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Colors.white),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center, // Para que se vea siempre bien centrado
              style: const TextStyle(
                  color: Colors.white, 
                  fontWeight: FontWeight.bold, 
                  fontSize: 16),
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 4), // Separación sutil entre título y subtítulo
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ]
          ],
        ),
      ),
    );
  }
}