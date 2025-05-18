// Archivo: lib/models/route_info.dart

import 'package:latlong2/latlong.dart';

class RouteInfo {
  final LatLng startPoint;
  final LatLng endPoint;
  final double distance; // en metros
  final int estimatedTimeSeconds; // tiempo estimado en segundos
  final List<LatLng> routePoints; // puntos que conforman la ruta

  RouteInfo({
    required this.startPoint,
    required this.endPoint,
    required this.distance,
    required this.estimatedTimeSeconds,
    required this.routePoints,
  });

  // Para simulación, podemos crear rutas de ejemplo
  factory RouteInfo.sample() {
    // Coordenadas cerca de Arequipa
    return RouteInfo(
      startPoint: const LatLng(-16.4090, -71.5375),
      endPoint: const LatLng(-16.4253, -71.5192),
      distance: 2500, // 2.5 km
      estimatedTimeSeconds: 600, // 10 minutos
      routePoints: [
        const LatLng(-16.4090, -71.5375),
        const LatLng(-16.4120, -71.5340),
        const LatLng(-16.4180, -71.5290),
        const LatLng(-16.4220, -71.5230),
        const LatLng(-16.4253, -71.5192),
      ],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'startPoint': {'lat': startPoint.latitude, 'lng': startPoint.longitude},
      'endPoint': {'lat': endPoint.latitude, 'lng': endPoint.longitude},
      'distance': distance,
      'estimatedTimeSeconds': estimatedTimeSeconds,
    };
  }
}
