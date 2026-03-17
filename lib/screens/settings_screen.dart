import 'package:flutter/material.dart';
import 'manage_products_screen.dart';
import 'manage_locations_screen.dart';
import 'manage_recipes_screen.dart';
import 'package:my_warehouse/screens/manage_providers_screen.dart';
import 'package:my_warehouse/screens/manage_area_stock_screen.dart';
import 'audit_history_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text('Gestión de Base de Datos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 16),
          // Pantalla Gestionar Productos (Verde)
          _buildSettingsCard(context, Icons.inventory_2, 'Gestionar Productos', 'Agregar, editar o eliminar insumos del catálogo', Colors.green, const ManageProductsScreen()),

          // Pantalla Sucursales (Azul)
          _buildSettingsCard(context, Icons.storefront, 'Gestionar Sucursales', 'Configurar puntos de distribución', Colors.blue, const ManageLocationsScreen()),
          
          // Pantalla Proveedores (Morado)
          _buildSettingsCard(context, Icons.people, 'Gestionar Proveedores', 'Administrar catálogo de proveedores', Colors.purple, const ManageProvidersScreen()),

          // Pantalla Pesajes (Naranja)
          _buildSettingsCard(context, Icons.science, 'Gestionar Recetas', 'Configurar pesajes, compuestos y kits', Colors.orange, const ManageRecipesScreen()),
          
          // Pantalla Stock de Areas (Turquesa)
          _buildSettingsCard(context, Icons.checklist_rtl, 'Plantillas de Stock Base', 'Configurar cuánto insumo debe tener cada área', Colors.teal, const ManageAreaStockScreen()),
          
          // Pantalla Auditorias (Cian)
          _buildSettingsCard(context, Icons.history_edu, 'Historial de Cierres', 'Revisar reportes de auditorías pasadas', Colors.cyan, const AuditHistoryScreen()),

          const SizedBox(height: 32),
          const Text('Ajustes del Sistema', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 16),

          _buildSettingsCard(context, Icons.security, 'Usuarios y Permisos', 'Controlar quién puede registrar movimientos', Colors.grey, null),
          _buildSettingsCard(context, Icons.print, 'Impresoras Térmicas', 'Configurar impresión de tickets y etiquetas', Colors.grey, null),
        ],
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