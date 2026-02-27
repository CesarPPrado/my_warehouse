import 'package:flutter/material.dart';
import '../widgets/action_button.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sinaloa Stock', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
            Text('Viernes, 27 De Febrero De 2026', style: TextStyle(fontSize: 14, color: Colors.grey)),
          ],
        ),
        toolbarHeight: 80,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Acciones Rápidas',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            // Cuadrícula de 4 botones
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.1, // Ajusta la proporción del rectángulo
                children: [
                  ActionButton(
                    title: 'Entrada',
                    subtitle: '(Proveedor)',
                    icon: Icons.arrow_circle_down,
                    color: Colors.green.shade700,
                    onTap: () { debugPrint("Ir a Entradas"); },
                  ),
                  ActionButton(
                    title: 'Salida',
                    subtitle: '(Sucursal/Producción)',
                    icon: Icons.arrow_circle_up,
                    color: Colors.blue.shade700,
                    onTap: () { debugPrint("Ir a Salidas"); },
                  ),
                  ActionButton(
                    title: 'Realizar',
                    subtitle: 'Pasaje/Kit',
                    icon: Icons.view_in_ar,
                    color: Colors.purple.shade700,
                    onTap: () { debugPrint("Ir a Pasajes"); },
                  ),
                  ActionButton(
                    title: 'Inventario',
                    subtitle: 'Físico',
                    icon: Icons.assignment,
                    color: Colors.orange.shade700,
                    onTap: () { debugPrint("Ir a Inventario"); },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      // Barra de navegación inferior básica
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF1E1E1E),
        selectedItemColor: Colors.greenAccent,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.inventory_2), label: 'Inventario'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Historial'),
          BottomNavigationBarItem(icon: Icon(Icons.folder), label: 'Catálogos'),
        ],
      ),
    );
  }
}