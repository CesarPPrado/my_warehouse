import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LocationFormScreen extends StatefulWidget {
  final Map<String, dynamic>? sucursalAEditar;
  const LocationFormScreen({super.key, this.sucursalAEditar});

  @override
  State<LocationFormScreen> createState() => _LocationFormScreenState();
}

class _LocationFormScreenState extends State<LocationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  String? _tipoSeleccionado;
  bool _isLoading = false;
  final List<String> _tipos = ['Bodega', 'Sucursal', 'Proveedor', 'Producción'];

  @override
  void initState() {
    super.initState();
    if (widget.sucursalAEditar != null) {
      _nombreController.text = widget.sucursalAEditar!['nombre'];
      _tipoSeleccionado = widget.sucursalAEditar!['tipo'];
    }
  }

  Future<void> _guardarSucursal() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      if (widget.sucursalAEditar == null) {
        await Supabase.instance.client.from('sucursales').insert({'nombre': _nombreController.text.trim(), 'tipo': _tipoSeleccionado});
      } else {
        await Supabase.instance.client.from('sucursales').update({'nombre': _nombreController.text.trim(), 'tipo': _tipoSeleccionado}).eq('id', widget.sucursalAEditar!['id']);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registro guardado'), backgroundColor: Colors.blue));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Aquí aplicamos la lógica dinámica para el título
        title: Text(
          widget.sucursalAEditar == null 
              ? 'Agregar Nueva Sucursal' 
              : 'Editar ${widget.sucursalAEditar!['tipo']}', // Lee el tipo exacto (Bodega, Proveedor, etc.)
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue.shade800,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(controller: _nombreController, decoration: const InputDecoration(labelText: 'Nombre *', filled: true), validator: (v) => v!.isEmpty ? 'Requerido' : null),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(initialValue: _tipoSeleccionado, items: _tipos.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(), onChanged: (v) => _tipoSeleccionado = v, decoration: const InputDecoration(labelText: 'Tipo *', filled: true), validator: (v) => v == null ? 'Requerido' : null),
              const SizedBox(height: 32),
              ElevatedButton(onPressed: _isLoading ? null : _guardarSucursal, style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, padding: const EdgeInsets.all(16)), child: _isLoading ? const CircularProgressIndicator() : const Text('Guardar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            ],
          ),
        ),
      ),
    );
  }
}