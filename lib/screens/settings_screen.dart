import 'package:flutter/material.dart';
import 'manage_products_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración y Catálogos', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text('Gestión de Base de Datos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
          const SizedBox(height: 16),
          // Aquí conectamos la pantalla de Gestionar Productos
          _buildSettingsCard(context, Icons.inventory_2, 'Gestionar Productos', 'Agregar, editar o eliminar insumos del catálogo', Colors.green, const ManageProductsScreen()),
          
          // A estas les pasamos "null" por ahora para que muestren el mensajito de "en construcción"
          _buildSettingsCard(context, Icons.storefront, 'Gestionar Sucursales', 'Configurar puntos de distribución', Colors.blue, null),
          _buildSettingsCard(context, Icons.people, 'Gestionar Proveedores', 'Administrar contactos y tiempos', Colors.purple, null),
          _buildSettingsCard(context, Icons.science, 'Fórmulas y Recetas', 'Configurar pasajes y compuestos', Colors.orange, null),
          
          const SizedBox(height: 32),
          const Text('Ajustes del Sistema', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 16),

          _buildSettingsCard(context, Icons.security, 'Usuarios y Permisos', 'Controlar quién puede registrar movimientos', Colors.grey, null),
          _buildSettingsCard(context, Icons.print, 'Impresoras Térmicas', 'Configurar impresión de tickets y etiquetas', Colors.grey, null),
        ],
      ),
      // Botón flotante para agregar nuevos registros rápidamente
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          debugPrint('Abrir modal para agregar nuevo registro');
        },
        backgroundColor: Colors.greenAccent,
        child: const Icon(Icons.add, color: Colors.black, size: 30),
      ),
    );
  }

  // Modifique el widget para aceptar una "ruta" (Widget de destino)
  Widget _buildSettingsCard(BuildContext context, IconData icon, String title, String subtitle, Color iconColor, Widget? destination) {
    return Card(
      color: const Color(0xFF1A1A1A),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: () { 
          if (destination != null) {
            Navigator.push(context, MaterialPageRoute(builder: (context) => destination));
          } else {
            // Muestra un mensaje si la pantalla aún no está construida
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Pantalla $title en construcción...')));
          }
        },
      ),
    );
  }
}