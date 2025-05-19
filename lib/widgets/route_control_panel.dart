import 'package:flutter/material.dart';
import '../controllers/passenger_route_controller.dart';

class RouteControlPanel extends StatelessWidget {
  final PassengerRouteController controller;
  final bool hasActiveFareRequest;
  final VoidCallback onSelectStart;
  final VoidCallback onSelectEnd;
  final VoidCallback onCalculateRoute;
  final VoidCallback onCancelOffer;

  const RouteControlPanel({
    super.key,
    required this.controller,
    required this.hasActiveFareRequest,
    required this.onSelectStart,
    required this.onSelectEnd,
    required this.onCalculateRoute,
    required this.onCancelOffer,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              // Si hay una solicitud activa, mostrar información
              if (hasActiveFareRequest)
                ActiveRequestPanel(onCancelOffer: onCancelOffer)
              else
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onSelectStart,
                        icon: const Icon(Icons.trip_origin),
                        label: const Text('Origen'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[100],
                          foregroundColor: Colors.green[800],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onSelectEnd,
                        icon: const Icon(Icons.place),
                        label: const Text('Destino'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[100],
                          foregroundColor: Colors.red[800],
                        ),
                      ),
                    ),
                  ],
                ),
              if (controller.startPoint != null &&
                  controller.endPoint != null &&
                  !controller.isRouteCalculated &&
                  !hasActiveFareRequest)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: onCalculateRoute,
                      icon: const Icon(Icons.directions),
                      label: const Text('Calcular Ruta'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[100],
                        foregroundColor: Colors.blue[800],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class ActiveRequestPanel extends StatelessWidget {
  final VoidCallback onCancelOffer;

  const ActiveRequestPanel({super.key, required this.onCancelOffer});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.orange),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Solicitud activa - esperando respuesta',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            onPressed: onCancelOffer,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[100],
              foregroundColor: Colors.red[800],
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
            ),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }
}
