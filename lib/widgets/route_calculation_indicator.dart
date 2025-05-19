import 'package:flutter/material.dart';

class RouteCalculationIndicator extends StatelessWidget {
  const RouteCalculationIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("Calculando ruta..."),
            ],
          ),
        ),
      ),
    );
  }
}
