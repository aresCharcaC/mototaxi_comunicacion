// Archivo: lib/screens/driver_screen.dart (Con correcciones)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'dart:math' show sin, cos, sqrt, atan2;
import '../../models/fare_offer.dart';
import '../../models/route_info.dart';
import '../../providers/negotiation_provider.dart';
import '../../providers/user_role_provider.dart';
import '../../services/websocket_service.dart';
import '../../widgets/offer_list.dart';
import '../../widgets/counter_offer_dialog.dart';
import '../../utils/format_utils.dart';

class DriverScreen extends StatefulWidget {
  final String serverUrl;

  const DriverScreen({super.key, required this.serverUrl});

  @override
  State<DriverScreen> createState() => _DriverScreenState();
}

class _DriverScreenState extends State<DriverScreen> {
  final WebSocketService _wsService = WebSocketService();
  final MapController _mapController = MapController();
  bool _isConnected = false;

  // Ubicación simulada del conductor (cerca de Arequipa pero no exactamente en el punto de origen del pasajero)
  final LatLng _driverPosition = const LatLng(-16.415, -71.530);
  RouteInfo? _selectedRouteInfo;

  @override
  void initState() {
    super.initState();
    _connectWebSocket();
  }

  @override
  void dispose() {
    _wsService.disconnect();
    super.dispose();
  }

  Future<void> _connectWebSocket() async {
    final negotiationProvider = Provider.of<NegotiationProvider>(
      context,
      listen: false,
    );

    final connected = await _wsService.connect(widget.serverUrl, (message) {
      // Process received messages
      debugPrint("Mensaje recibido detallado en DriverScreen: $message");
      negotiationProvider.processIncomingMessage(message);

      // Check if we have active requests after processing
      _updateOffersFromProvider();
    });

    setState(() {
      _isConnected = connected;
    });

    // Show connection status
    if (connected) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Conectado al servidor')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Error al conectar. Comprueba la IP y que el servidor esté activo.',
          ),
          action: SnackBarAction(
            label: 'Reintentar',
            onPressed: _connectWebSocket,
          ),
        ),
      );
    }
  }

  void _showCounterOfferDialog(FareOffer passengerOffer) {
    showDialog(
      context: context,
      builder:
          (context) => CounterOfferDialog(
            originalOffer: passengerOffer,
            onSubmit: (amount) => _sendCounterOffer(passengerOffer, amount),
          ),
    );
  }

  void _sendCounterOffer(FareOffer originalOffer, double counterOfferAmount) {
    final userProvider = Provider.of<UserRoleProvider>(context, listen: false);
    final negotiationProvider = Provider.of<NegotiationProvider>(
      context,
      listen: false,
    );

    if (!_isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No conectado al servidor. No se puede enviar contraoferta.',
          ),
        ),
      );
      return;
    }

    // Crear contraoferta
    final counterOffer = negotiationProvider.createCounterOffer(
      originalOffer,
      fromUserId: userProvider.userId,
      fromUserName: userProvider.name,
      amount: counterOfferAmount,
    );

    // Configurar como contraoferta
    final message = {...counterOffer.toJson(), 'type': 'fare_counter_offer'};

    // Enviar a través de WebSocket
    _wsService.sendMessage(message);

    // La oferta ya se añadió en createCounterOffer

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Contraoferta de S/ ${counterOfferAmount.toStringAsFixed(2)} enviada',
        ),
      ),
    );

    // Mostrar los detalles de la ruta para referencia
    _showRouteDetails(originalOffer);
  }

  void _showRouteDetails(FareOffer offer) {
    try {
      // Extraer datos de la ruta del JSON de la oferta
      final startLat = offer.routeData['startPoint']['lat'] as double;
      final startLng = offer.routeData['startPoint']['lng'] as double;
      final endLat = offer.routeData['endPoint']['lat'] as double;
      final endLng = offer.routeData['endPoint']['lng'] as double;
      final distance = offer.routeData['distance'] as double;
      final time = offer.routeData['estimatedTimeSeconds'] as int;

      // Crear puntos de la ruta
      final startPoint = LatLng(startLat, startLng);
      final endPoint = LatLng(endLat, endLng);

      // Generar una ruta simple desde la posición del conductor hasta el punto de inicio,
      // y luego hasta el destino
      final routePoints = [
        _driverPosition,
        LatLng(
          _driverPosition.latitude +
              (startPoint.latitude - _driverPosition.latitude) * 0.5,
          _driverPosition.longitude +
              (startPoint.longitude - _driverPosition.longitude) * 0.5,
        ),
        startPoint,
        LatLng(
          startPoint.latitude +
              (endPoint.latitude - startPoint.latitude) * 0.25,
          startPoint.longitude +
              (endPoint.longitude - startPoint.longitude) * 0.25,
        ),
        LatLng(
          startPoint.latitude + (endPoint.latitude - startPoint.latitude) * 0.5,
          startPoint.longitude +
              (endPoint.longitude - startPoint.longitude) * 0.5,
        ),
        LatLng(
          startPoint.latitude +
              (endPoint.latitude - startPoint.latitude) * 0.75,
          startPoint.longitude +
              (endPoint.longitude - startPoint.longitude) * 0.75,
        ),
        endPoint,
      ];

      // Calcular distancia adicional (conductor hasta punto de inicio)
      double additionalDistance = _calculateDistance(
        _driverPosition,
        startPoint,
      );

      // Crear objeto RouteInfo
      _selectedRouteInfo = RouteInfo(
        startPoint: startPoint,
        endPoint: endPoint,
        distance: distance + additionalDistance,
        estimatedTimeSeconds: time + (additionalDistance / 500 * 60).round(),
        routePoints: routePoints,
      );

      // Actualizar UI
      setState(() {});

      // Ajustar el mapa para mostrar toda la ruta
      _fitRouteBounds(routePoints);
    } catch (e) {
      debugPrint("Error al procesar datos de ruta: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al procesar datos de ruta: $e")),
      );
    }
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    // Fórmula de Haversine para calcular distancia en metros
    const double earthRadius = 6371000; // en metros
    final double lat1Rad = point1.latitude * (3.14159 / 180);
    final double lat2Rad = point2.latitude * (3.14159 / 180);
    final double deltaLatRad =
        (point2.latitude - point1.latitude) * (3.14159 / 180);
    final double deltaLonRad =
        (point2.longitude - point1.longitude) * (3.14159 / 180);

    final double a =
        sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) *
            cos(lat2Rad) *
            sin(deltaLonRad / 2) *
            sin(deltaLonRad / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  void _fitRouteBounds(List<LatLng> routePoints) {
    if (routePoints.isEmpty) return;

    // Crear un límite que contenga todos los puntos de la ruta
    var bounds = LatLngBounds.fromPoints(routePoints);

    // Añadir un poco de padding
    final latDiff = (bounds.north - bounds.south) * 0.3; // 30% de padding
    final lngDiff = (bounds.east - bounds.west) * 0.3;

    // Crear nuevos límites con padding
    bounds = LatLngBounds(
      LatLng(bounds.south - latDiff, bounds.west - lngDiff),
      LatLng(bounds.north + latDiff, bounds.east + lngDiff),
    );

    // Implementación compatible con diferentes versiones de flutter_map
    try {
      // Intenta usar el método más nuevo primero
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50.0)),
      );
    } catch (e) {
      // Si falla, intenta usar el método antiguo
      try {
        // Método anterior
        _mapController.fitCamera(
          CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
        );
      } catch (e2) {
        // Si ambos fallan, solo mueve al centro
        _mapController.move(bounds.center, 13);
        debugPrint("Error al ajustar límites: $e2");
      }
    }
  }

  void _updateOffersFromProvider() {
    final negotiationProvider = Provider.of<NegotiationProvider>(
      context,
      listen: false,
    );

    // Force UI update when offers change
    if (negotiationProvider.offers.isNotEmpty) {
      setState(() {
        // Just trigger a rebuild
      });

      debugPrint(
        "Ofertas actualizadas en DriverScreen: ${negotiationProvider.offers.length}",
      );
      // Show a notification for new offers
      for (final offer in negotiationProvider.offers) {
        if (offer.status == OfferStatus.pending &&
            offer.toUserId == 'all_drivers' &&
            !_processedOfferIds.contains(offer.id)) {
          _processedOfferIds.add(offer.id);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Nueva solicitud de ${offer.fromUserName}'),
              action: SnackBarAction(
                label: 'Ver',
                onPressed: () => _showRouteDetails(offer),
              ),
            ),
          );
        }
      }
    }
  }

  // Add this property to track processed offers
  final Set<String> _processedOfferIds = {};

  @override
  Widget build(BuildContext context) {
    final negotiationProvider = Provider.of<NegotiationProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Conductor - Solicitudes de Viaje'),
        backgroundColor: Colors.orange[100],
        actions: [
          IconButton(
            icon: Icon(_isConnected ? Icons.wifi : Icons.wifi_off),
            onPressed: _isConnected ? null : _connectWebSocket,
            tooltip: _isConnected ? 'Conectado' : 'Desconectado',
          ),
        ],
      ),
      body: Column(
        children: [
          // Mapa
          Expanded(
            flex: 2,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _driverPosition,
                initialZoom: 15.0,
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
                    // Marcador de posición del conductor
                    Marker(
                      point: _driverPosition,
                      width: 40,
                      height: 40,
                      child: const Stack(
                        children: [
                          Icon(Icons.circle, color: Colors.white, size: 22),
                          Icon(
                            Icons.motorcycle,
                            color: Colors.orange,
                            size: 20,
                          ),
                        ],
                      ),
                    ),

                    // Marcadores adicionales si hay una ruta seleccionada
                    if (_selectedRouteInfo != null) ...[
                      // Marcador de punto inicial
                      Marker(
                        point: _selectedRouteInfo!.startPoint,
                        width: 40,
                        height: 40,
                        child: const Icon(
                          Icons.trip_origin,
                          color: Colors.green,
                          size: 30,
                        ),
                      ),

                      // Marcador de punto final
                      Marker(
                        point: _selectedRouteInfo!.endPoint,
                        width: 40,
                        height: 40,
                        child: const Icon(
                          Icons.place,
                          color: Colors.red,
                          size: 30,
                        ),
                      ),
                    ],
                  ],
                ),

                // Capa de ruta
                if (_selectedRouteInfo != null)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _selectedRouteInfo!.routePoints,
                        strokeWidth: 4.0,
                        color: Colors.blue,
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // Tarjeta de estado
          Card(
            margin: const EdgeInsets.all(8.0),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.notifications_active, color: Colors.orange),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isConnected
                              ? 'Esperando solicitudes de viaje'
                              : 'Desconectado del servidor',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          _isConnected
                              ? 'Las solicitudes de pasajeros aparecerán aquí'
                              : 'Conecta al servidor para recibir solicitudes',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _isConnected ? Colors.green : Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Info de ruta seleccionada
          if (_selectedRouteInfo != null)
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Información de Ruta',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            setState(() {
                              _selectedRouteInfo = null;
                            });
                          },
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Icon(
                              Icons.straighten,
                              color: Colors.blue,
                              size: 20,
                            ),
                            Text(
                              (_selectedRouteInfo!.distance / 1000)
                                      .toStringAsFixed(1) +
                                  ' km',
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            const Icon(
                              Icons.access_time,
                              color: Colors.blue,
                              size: 20,
                            ),
                            Text(
                              (_selectedRouteInfo!.estimatedTimeSeconds / 60)
                                      .round()
                                      .toString() +
                                  ' min',
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            const Icon(
                              Icons.attach_money,
                              color: Colors.green,
                              size: 20,
                            ),
                            Text(
                              'S/ ${(3.0 + _selectedRouteInfo!.distance / 1000).toStringAsFixed(1)}',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // Lista de ofertas de pasajeros
          Expanded(
            child: OfferList(
              offers: negotiationProvider.offers,
              userRole: UserRole.driver,
              onAccept: (offer) {
                // Aceptar oferta de pasajero
                offer.status = OfferStatus.accepted;
                _wsService.sendMessage({
                  ...offer.toJson(),
                  'type': 'fare_accepted',
                });
                setState(() {});
                // Mostrar los detalles de la ruta al aceptar
                _showRouteDetails(offer);
              },
              onReject: (offer) {
                // Rechazar oferta de pasajero
                offer.status = OfferStatus.rejected;
                _wsService.sendMessage({
                  ...offer.toJson(),
                  'type': 'fare_rejected',
                });
                setState(() {});
              },
              onCounterOffer: (offer) {
                // Mostrar diálogo para hacer contraoferta
                _showCounterOfferDialog(offer);
                // Mostrar también los detalles de la ruta
                _showRouteDetails(offer);
              },
            ),
          ),
        ],
      ),

      // Botón para centrar en la ubicación del conductor
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _mapController.move(_driverPosition, 15);
        },
        child: const Icon(Icons.my_location),
      ),
    );
  }
}
