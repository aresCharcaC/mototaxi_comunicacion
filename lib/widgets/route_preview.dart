// Archivo: lib/widgets/route_preview.dart

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/route_info.dart';
import '../utils/format_utils.dart';

class RoutePreview extends StatelessWidget {
  final RouteInfo route;

  const RoutePreview({super.key, required this.route});

  @override
  Widget build(BuildContext context) {
    final bounds = LatLngBounds.fromPoints(route.routePoints);

    return SizedBox(
      height: 200,
      child: Column(
        children: [
          // Mapa con la ruta
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: bounds.center,
                initialZoom: 14.0,
                minZoom: 10.0,
                maxZoom: 18.0,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
                initialCameraFit: CameraFit.bounds(
                  bounds: bounds,
                  padding: const EdgeInsets.all(30.0),
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.mototaxi_fare_negotiation',
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: route.routePoints,
                      strokeWidth: 4.0,
                      color: Colors.blue,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    // Marcador de origen
                    Marker(
                      point: route.startPoint,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.trip_origin,
                        color: Colors.green,
                        size: 30,
                      ),
                    ),
                    // Marcador de destino
                    Marker(
                      point: route.endPoint,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.place,
                        color: Colors.red,
                        size: 30,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Información de la ruta
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Distancia
                Row(
                  children: [
                    const Icon(Icons.straighten, size: 18, color: Colors.blue),
                    const SizedBox(width: 4),
                    Text(
                      FormatUtils.formatDistance(route.distance),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),

                // Tiempo estimado
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 18, color: Colors.blue),
                    const SizedBox(width: 4),
                    Text(
                      FormatUtils.formatDuration(route.estimatedTimeSeconds),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),

                // Tipo de vehículo
                Row(
                  children: [
                    const Icon(Icons.motorcycle, size: 18, color: Colors.blue),
                    const SizedBox(width: 4),
                    const Text(
                      'Mototaxi',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
