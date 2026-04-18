# my_warehouse (ERP Móvil de Almacén)

Este es el repositorio oficial de `my_warehouse`, una aplicación móvil tipo ERP desarrollada en Flutter y Dart, con Supabase (PostgreSQL) como backend. 

## Descripción
El proyecto busca solucionar los problemas de control de inventario manual mediante un sistema ágil para dispositivos móviles. Permite el control de stock, registro de entradas y salidas, y cuenta con un módulo especializado de Producción/Kits para descontar materia prima a granel automáticamente.

## Tecnologías Utilizadas
* **Frontend:** Flutter / Dart
* **Backend:** Supabase (BaaS)
* **Base de Datos:** PostgreSQL

## Instrucciones Básicas para Ejecutar
1. Clona este repositorio: `git clone https://github.com/cesarpprado/my_warehouse.git`
2. Abre la carpeta del proyecto en tu IDE (VS Code o Android Studio).
3. Ejecuta `flutter pub get` para instalar las dependencias necesarias.
4. Configura tus variables de entorno de Supabase en el archivo `.env` (URL y API Key).
5. Conecta un emulador o dispositivo físico y ejecuta `flutter run`.
