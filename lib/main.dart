// Archivo: lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/websocket_service.dart';
import 'screens/role_selection_screen.dart';
import 'providers/negotiation_provider.dart';
import 'providers/user_role_provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserRoleProvider()),
        ChangeNotifierProvider(create: (_) => NegotiationProvider()),
        Provider(create: (_) => WebSocketService()),
      ],
      child: MaterialApp(
        title: 'Mototaxi Fare Negotiation',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
          useMaterial3: true,
        ),
        home: const RoleSelectionScreen(),
      ),
    );
  }
}
