import 'package:flutter/material.dart';
import '../widgets/action_button.dart';
import '../widgets/alert_card.dart'; // Importamos el nuevo widget
import 'inventory_screen.dart';
import 'movements_screen.dart';
import 'production_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // Función para obtener la fecha dinámica en español
  String _obtenerFechaActual() {
    final DateTime ahora = DateTime.now();
    final List<String> dias = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
    final List<String> meses = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];

    String diaSemana = dias[ahora.weekday - 1];
    String mes = meses[ahora.month - 1];

    return '$diaSemana, ${ahora.day} de $mes de ${ahora.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('La Sinaloa - Almacén', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
            // Llamamos a la función aquí
            Text(_obtenerFechaActual(), style: const TextStyle(fontSize: 14, color: Colors.grey)),
          ],
        ),
        toolbarHeight: 80,
      ),
      // Cambiamos el Padding por un SingleChildScrollView para poder hacer scroll hacia abajo
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Acciones Rápidas',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // GridView adaptado para convivir con el scroll
            GridView.count(
              shrinkWrap: true, // Esto es clave para que no marque error de tamaño
              physics: const NeverScrollableScrollPhysics(), // Apagamos el scroll del Grid para usar el general
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.1,
              children: [
                ActionButton(
                  title: 'Entrada',
                  subtitle: '(Proveedor)',
                  icon: Icons.arrow_circle_down,
                  color: Colors.green.shade700,
                  onTap: () { Navigator.push(context, MaterialPageRoute(builder: (context) => const MovementsScreen())); debugPrint("Ir a Entradas"); },
                ),
                ActionButton(
                  title: 'Salida',
                  subtitle: '(Sucursal/Producción)',
                  icon: Icons.arrow_circle_up,
                  color: Colors.blue.shade700,
                  onTap: () { Navigator.push(context, MaterialPageRoute(builder: (context) => const MovementsScreen())); debugPrint("Ir a Salidas"); },
                ),
                ActionButton(
                  title: 'Realizar',
                  subtitle: 'Pasaje/Kit',
                  icon: Icons.view_in_ar,
                  color: Colors.purple.shade700,
                  onTap: () { Navigator.push(context, MaterialPageRoute(builder: (context) => const ProductionScreen())); debugPrint("Ir a Pasajes"); },
                ),
                ActionButton(
                  title: 'Inventario',
                  subtitle: 'Físico',
                  icon: Icons.assignment,
                  color: Colors.orange.shade700,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const InventoryScreen()),
                    );
                  },
                ),
              ],
            ),
            
            const SizedBox(height: 32), // Espacio entre secciones

            // Sección de Alertas
            const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 24),
                SizedBox(width: 8),
                Text(
                  'Alertas de Stock Bajo',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Tarjetas de alerta con datos reales de tu bodega
            const AlertCard(
              productName: 'Harina Rosal (Saco 25kg)',
              stock: '3 Sacos',
              status: 'CRÍTICO',
              statusColor: Colors.redAccent,
            ),
            const AlertCard(
              productName: 'Frijol Mayocoba',
              stock: '2 Costales',
              status: 'CRÍTICO',
              statusColor: Colors.redAccent,
            ),
            const AlertCard(
              productName: 'Mexenil (.090 gr)',
              stock: '8 Bolsitas',
              status: 'BAJO',
              statusColor: Colors.amber,
            ),
          ],
        ),
      ),
      // Barra de navegación inferior
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF1E1E1E),
        selectedItemColor: Colors.greenAccent,
        unselectedItemColor: Colors.grey,
      // Agregamos la función onTap para que los botones reaccionen
      onTap: (index) {
          if (index == 1) {
            // Índice 1 es el segundo botón: Inventario
            Navigator.push(context, MaterialPageRoute(builder: (context) => const InventoryScreen()));
          } else if (index == 3) {
            // Índice 3 es el cuarto botón: Catálogos
            Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
          }
        },
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