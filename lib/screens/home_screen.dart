import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/action_button.dart';
import 'inventory_screen.dart';
import 'production_screen.dart';
import 'inbound_screen.dart';
import 'outbound_screen.dart';
import 'area_audit_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<dynamic> _alertasStock = [];
  bool _isLoadingAlerts = true;

  @override
  void initState() {
    super.initState();
    _cargarAlertasStock();
  }

  Future<void> _cargarAlertasStock() async {
    // Si ya estamos cargando y la lista está llena, no hacemos la animación de carga
    if (!mounted || (_isLoadingAlerts && _alertasStock.isNotEmpty)) return;

    if (_alertasStock.isEmpty) {
      setState(() => _isLoadingAlerts = true);
    }

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
  
  String _obtenerFechaActual() {
    final DateTime ahora = DateTime.now();
    final List<String> dias = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
    final List<String> meses = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];

    String diaSemana = dias[ahora.weekday - 1];
    String mes = meses[ahora.month - 1];

    return '$diaSemana, ${ahora.day} de $mes de ${ahora.year}';
  }

  // --- TRUCO DE REACTIVIDAD: Esta función abre la pantalla y ESPERA a que regreses ---
  Future<void> _abrirPantallaYRecargar(Widget pantalla) async {
    await Navigator.push(context, MaterialPageRoute(builder: (context) => pantalla));
    // ¡Cuando regresas a esta pantalla (se cierra la otra), esta línea se ejecuta!
    _cargarAlertasStock(); 
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('La Sinaloa - Almacen', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
            Text(_obtenerFechaActual(), style: const TextStyle(fontSize: 14, color: Colors.grey)),
          ],
        ),
        toolbarHeight: 80,
      ),
      // --- Agregamos RefreshIndicator por si acaso ---
      body: RefreshIndicator(
        color: Colors.white,
        backgroundColor: Colors.amber,
        onRefresh: _cargarAlertasStock,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(), // Asegura que siempre se pueda hacer Pull-to-refresh
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Acciones Rápidas',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              
              const SizedBox(height: 8),
              
              GridView.count(
                shrinkWrap: true, 
                physics: const NeverScrollableScrollPhysics(), 
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.1,
                children: [
                  // --- Conectamos los botones a nuestro truco ---
                  ActionButton(
                    title: 'Entrada',
                    subtitle: 'Registra nuevas compras',
                    icon: Icons.arrow_circle_down,
                    color: Colors.green.shade700,
                    onTap: () => _abrirPantallaYRecargar(const InboundScreen()),
                  ),
                  ActionButton(
                    title: 'Salida',
                    subtitle: 'Envios a Sucursales o Areas',
                    icon: Icons.arrow_circle_up,
                    color: Colors.red,
                    onTap: () => _abrirPantallaYRecargar(const OutboundScreen()),
                  ),
                  ActionButton(
                    title: 'Pesajes',
                    subtitle: 'Realiza Kits o Pasajes',
                    icon: Icons.view_in_ar,
                    color: Colors.purple.shade700,
                    onTap: () => _abrirPantallaYRecargar(const ProductionScreen()),
                  ),
                  ActionButton(
                    title: 'Inventario',
                    subtitle: 'Consulta el stock actual',
                    icon: Icons.assignment,
                    color: Colors.orange.shade700,
                    onTap: () => _abrirPantallaYRecargar(const InventoryScreen()),
                  ),
                ],
              ),
              
              const SizedBox(height: 16), 

              // --- BOTÓN DE AUDITORÍA ---
              SizedBox(
                width: double.infinity,
                child: ActionButton(
                  title: 'Auditoría y Cierre de Área',
                  subtitle: 'Cuenta sobrantes y genera resurtido automático',
                  icon: Icons.checklist_rtl,
                  color: Colors.cyan.shade800,


                  onTap: () => _abrirPantallaYRecargar(const AreaAuditScreen()),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16), // Agregamos más espacio arriba y abajo
                ),
              ),

              const SizedBox(height: 16),

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
      ),
    );
  }
}