import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/action_button.dart';
import 'inventory_screen.dart';
import 'production_screen.dart';
import 'inbound_screen.dart';
import 'outbound_screen.dart';

// Transformación a StatefulWidget para manejar alertas dinámicas de stock bajo
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Variables para el estado (Las alertas inteligentes)
  List<dynamic> _alertasStock = [];
  bool _isLoadingAlerts = true;

  @override
  void initState() {
    super.initState();
    _cargarAlertasStock(); // Buscamos en Supabase apenas abre la pantalla
  }

  // Motor inteligente de búsqueda
  Future<void> _cargarAlertasStock() async {
    try {
      final response = await Supabase.instance.client
          .from('productos')
          .select('nombre, stock_actual, stock_minimo, unidad_medida');

      final alertas = response.where((p) {
        final actual = (p['stock_actual'] ?? 0) as num;
        final minimo = (p['stock_minimo'] ?? 0) as num;
        return actual <= minimo && minimo > 0; 
      }).toList();

      alertas.sort((a, b) => (a['stock_actual'] as num).compareTo(b['stock_actual'] as num));

      if (mounted) {
        setState(() {
          _alertasStock = alertas;
          _isLoadingAlerts = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando alertas: $e');
      if (mounted) setState(() => _isLoadingAlerts = false);
    }
  }
  
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
            const Text('La Sinaloa - Almacen', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
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
                  subtitle: 'Registra nuevas compras',
                  icon: Icons.arrow_circle_down,
                  color: Colors.green.shade700,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const InboundScreen()));
                  },
                ),
                ActionButton(
                  title: 'Salida',
                  subtitle: 'Envios a Sucursales o Areas',
                  icon: Icons.arrow_circle_up,
                  color: Colors.red,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const OutboundScreen()));
                  },
                ),
                ActionButton(
                  title: 'Pesajes',
                  subtitle: 'Realiza Kits o Pasajes',
                  icon: Icons.view_in_ar,
                  color: Colors.purple.shade700,
                  onTap: () { Navigator.push(context, MaterialPageRoute(builder: (context) => const ProductionScreen())); debugPrint("Ir a Pasajes"); },
                ),
                ActionButton(
                  title: 'Inventario',
                  subtitle: 'Consulta el stock actual',
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

            // Sección DINÁMICA de Alertas
            const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 24),
                SizedBox(width: 8),
                Text('Alertas de Stock Bajo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),

            _isLoadingAlerts
                ? const Center(child: CircularProgressIndicator())
                : _alertasStock.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text('Todo el inventario está en niveles óptimos 🎉', style: TextStyle(color: Colors.grey)),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _alertasStock.length,
                        itemBuilder: (context, index) {
                          final item = _alertasStock[index];
                          final actual = (item['stock_actual'] ?? 0) as num;
                          final minimo = (item['stock_minimo'] ?? 0) as num;
                          
                          String etiqueta = 'BAJO';
                          Color colorEtiqueta = Colors.orange;
                          
                          if (actual <= 0) {
                            etiqueta = 'AGOTADO';
                            colorEtiqueta = Colors.red;
                          } else if (actual <= (minimo / 2)) {
                            etiqueta = 'CRÍTICO';
                            colorEtiqueta = Colors.redAccent;
                          }

                          return Card(
                            color: const Color(0xFF1A1A1A),
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8), 
                              side: BorderSide(color: colorEtiqueta.withValues(alpha: 0.3)) 
                            ),
                            child: ListTile(
                              title: Text(item['nombre'], style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('Stock actual: $actual ${item['unidad_medida']}\nMínimo requerido: $minimo', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: colorEtiqueta.withValues(alpha: 0.1),
                                  border: Border.all(color: colorEtiqueta),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(etiqueta, style: TextStyle(color: colorEtiqueta, fontWeight: FontWeight.bold, fontSize: 10)),
                              ),
                            ),
                          );
                        },
                      ),
          ],
        ),
      ),
    );
  }
}