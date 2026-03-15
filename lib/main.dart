import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/main_layout.dart';

// Cambie el main() para que sea asíncrono y espere la conexión
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Cargamos el archivo .env
  await dotenv.load(fileName: ".env");

  // Usamos las variables seguras para conectarnos
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

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