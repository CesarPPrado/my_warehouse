import 'package:flutter/material.dart';

class CustomDropdown extends StatelessWidget {
  final String label;
  final String hint;
  final String? value;
  final List<String> items;
  final Function(String?) onChanged;
  final String? Function(String?)? validator;

  const CustomDropdown({
    super.key,
    required this.label,
    required this.hint,
    required this.items,
    required this.onChanged,
    this.value,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        FormField<String>(
          initialValue: value,
          validator: validator,
          builder: (FormFieldState<String> state) {
            return LayoutBuilder(
              builder: (context, constraints) {
                return DropdownMenu<String>(
                  initialSelection: state.value,
                  width: constraints.maxWidth, 
                  menuHeight: 300,
                  hintText: hint,
                  requestFocusOnTap: false, 
                  textStyle: const TextStyle(color: Colors.white, fontSize: 14),
                  errorText: state.errorText, 

                  // Aquí es donde aplicamos el diseño del menú flotante
                  menuStyle: MenuStyle(
                    backgroundColor: WidgetStateProperty.all(const Color(0xFF2A2A2A)),
                    
                    // *** ESTE ES EL CAMBIO MÁGICO ***
                    // Usamos 'BorderRadius.only' para elegir qué esquinas redondear
                    shape: WidgetStateProperty.all(
                      const RoundedRectangleBorder(
                        borderRadius: BorderRadius.only(
                          topRight: Radius.zero,       // Esquina superior derecha plana (cero)
                          topLeft: Radius.zero,        // Esquina superior izquierda plana (cero)
                          bottomLeft: Radius.circular(16), // Esquina inferior izquierda redonda
                          bottomRight: Radius.circular(16), // Esquina inferior derecha redonda
                        ),
                      ),
                    ),
                    // ********************************
                  ),
                  inputDecorationTheme: InputDecorationTheme(
                    filled: true,
                    fillColor: const Color(0xFF2A2A2A),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  trailingIcon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                  selectedTrailingIcon: const Icon(Icons.arrow_drop_up, color: Colors.white70),
                  dropdownMenuEntries: items.map((i) {
                    return DropdownMenuEntry<String>(
                      value: i,
                      label: i,
                      style: MenuItemButton.styleFrom(
                        foregroundColor: Colors.white, 
                      ),
                    );
                  }).toList(),
                  onSelected: (newValue) {
                    state.didChange(newValue); 
                    onChanged(newValue);       
                  },
                );
              }
            );
          },
        ),
      ],
    );
  }
}