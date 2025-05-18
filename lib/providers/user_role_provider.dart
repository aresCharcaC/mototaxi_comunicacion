// Archivo: lib/providers/user_role_provider.dart

import 'package:flutter/material.dart';

enum UserRole { passenger, driver }

class UserRoleProvider extends ChangeNotifier {
  UserRole _role = UserRole.passenger;
  String _userId = DateTime.now().millisecondsSinceEpoch.toString();
  String _name = '';

  UserRole get role => _role;
  String get userId => _userId;
  String get name => _name;

  void setRole(UserRole role) {
    _role = role;
    notifyListeners();
  }

  void setName(String name) {
    _name = name;
    notifyListeners();
  }

  bool isPassenger() => _role == UserRole.passenger;
  bool isDriver() => _role == UserRole.driver;
}
