import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../controllers/passenger_route_controller.dart';
import 'route_calculation_indicator.dart';

class PassengerMapView extends StatelessWidget {
  final PassengerRouteController controller;

  const PassengerMapView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: controller.mapController,
          options: MapOptions(
            initialCenter:
                controller.currentPosition ??
                const LatLng(-16.4090, -71.5375), // Arequipa por defecto
            initialZoom: 15.0,
            onTap: controller.handleMapTap,
          ),
          children: [
            // Capa de mapa base
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.mototaxi_fare_negotiation',
            ),

            // Capa de marcadores
            MarkerLayer(
              markers: [
                // Marcador de posición actual
                if (controller.currentPosition != null)
                  Marker(
                    point: controller.currentPosition!,
                    width: 40,
                    height: 40,
                    child: const Icon(
                      Icons.my_location,
                      color: Colors.blue,
                      size: 30,
                    ),
                  ),

                // Marcador de punto inicial
                if (controller.startPoint != null)
                  Marker(
                    point: controller.startPoint!,
                    width: 40,
                    height: 40,
                    child: const Icon(
                      Icons.trip_origin,
                      color: Colors.green,
                      size: 30,
                    ),
                  ),

                // Marcador de punto final
                if (controller.endPoint != null)
                  Marker(
                    point: controller.endPoint!,
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.place, color: Colors.red, size: 30),
                  ),
              ],
            ),

            // Capa de ruta
            if (controller.routePoints.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: controller.routePoints,
                    strokeWidth: 4.0,
                    color: Colors.blue,
                  ),
                ],
              ),
          ],
        ),

        // Indicador de cálculo de ruta
        if (controller.isCalculatingRoute) const RouteCalculationIndicator(),
      ],
    );
  }
}
