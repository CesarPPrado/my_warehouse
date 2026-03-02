import 'package:flutter/material.dart';
import 'screens/main_layout.dart';

void main() {
  runApp(const SinaloaStockApp());
}

class SinaloaStockApp extends StatelessWidget {
  const SinaloaStockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'La Sinaloa - Almacen',
      debugShowCheckedModeBanner: false, // Quita la etiqueta de "DEBUG"
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212), // Color de fondo oscuro
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF121212),
          elevation: 0, // AppBar sin sombra para que se fusione con el fondo
        ),
      ),
      home: const MainLayout(),
    );
  }
}