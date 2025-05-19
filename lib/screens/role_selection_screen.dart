// Archivo: lib/screens/role_selection_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_role_provider.dart';
import 'passenger/passenger_screen.dart';
import 'driver/driver_screen.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _serverIpController = TextEditingController(
    text: '192.168.1.X',
  );
  String _selectedRole = 'passenger';
  bool _isConnecting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _serverIpController.dispose();
    super.dispose();
  }

  void _navigateToRoleScreen() {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor ingresa tu nombre')),
      );
      return;
    }

    if (!_serverIpController.text.contains('192.168.') ||
        _serverIpController.text.contains('X')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor ingresa una IP válida')),
      );
      return;
    }

    final roleProvider = Provider.of<UserRoleProvider>(context, listen: false);
    roleProvider.setName(_nameController.text);

    if (_selectedRole == 'passenger') {
      roleProvider.setRole(UserRole.passenger);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (context) => PassengerScreen(
                serverUrl: 'ws://${_serverIpController.text}:8080',
              ),
        ),
      );
    } else {
      roleProvider.setRole(UserRole.driver);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (context) => DriverScreen(
                serverUrl: 'ws://${_serverIpController.text}:8080',
              ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mototaxi - Seleccionar Rol'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '¿Cómo deseas usar la aplicación?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),

            // Selección de rol
            Row(
              children: [
                Expanded(
                  child: RadioListTile<String>(
                    title: const Row(
                      children: [
                        Icon(Icons.person, size: 24),
                        SizedBox(width: 8),
                        Text('Pasajero'),
                      ],
                    ),
                    value: 'passenger',
                    groupValue: _selectedRole,
                    onChanged: (value) {
                      setState(() {
                        _selectedRole = value!;
                      });
                    },
                  ),
                ),
                Expanded(
                  child: RadioListTile<String>(
                    title: const Row(
                      children: [
                        Icon(Icons.motorcycle, size: 24),
                        SizedBox(width: 8),
                        Text('Conductor'),
                      ],
                    ),
                    value: 'driver',
                    groupValue: _selectedRole,
                    onChanged: (value) {
                      setState(() {
                        _selectedRole = value!;
                      });
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),

            // Campo para nombre
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Tu nombre',
                hintText: 'Ingresa tu nombre',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            // Campo para IP del servidor
            TextField(
              controller: _serverIpController,
              decoration: const InputDecoration(
                labelText: 'IP del servidor WebSocket',
                hintText: 'Ejemplo: 192.168.1.15',
                prefixIcon: Icon(Icons.computer),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 40),

            // Botón para continuar
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isConnecting ? null : _navigateToRoleScreen,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor:
                      _selectedRole == 'passenger'
                          ? Colors.blue
                          : Colors.orange,
                  foregroundColor: Colors.white,
                ),
                child:
                    _isConnecting
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                          'CONTINUAR',
                          style: TextStyle(fontSize: 16),
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
