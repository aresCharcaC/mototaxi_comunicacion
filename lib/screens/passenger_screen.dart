// Archivo: lib/screens/passenger_screen.dart (completo con gestión de solicitudes)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' show sin, cos, sqrt, atan2;
import '../models/route_info.dart';
import '../models/fare_offer.dart';
import '../providers/negotiation_provider.dart';
import '../providers/user_role_provider.dart';
import '../services/websocket_service.dart';
import '../widgets/fare_adjustment_slider.dart';
import '../widgets/offer_list.dart';
import 'dart:convert';

class PassengerScreen extends StatefulWidget {
  final String serverUrl;

  const PassengerScreen({super.key, required this.serverUrl});

  @override
  State<PassengerScreen> createState() => _PassengerScreenState();
}

class _PassengerScreenState extends State<PassengerScreen> {
  final WebSocketService _wsService = WebSocketService();
  final MapController _mapController = MapController();

  bool _isConnected = false;
  bool _isLoading = true;
  bool _isCalculatingRoute = false;
  bool _isRouteCalculated = false;
  bool _hasActiveFareRequest = false;

  LatLng? _currentPosition;
  LatLng? _startPoint;
  LatLng? _endPoint;
  List<LatLng> _routePoints = [];
  double _routeDistance = 0;
  double _currentOffer = 0.0;

  SelectionMode _selectionMode = SelectionMode.none;

  @override
  void initState() {
    super.initState();
    _connectWebSocket();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    // Si hay una solicitud activa, cancelarla al salir
    _cancelOfferIfActive();
    _wsService.disconnect();
    super.dispose();
  }

  // Obtener la ubicación actual del usuario
  Future<void> _getCurrentLocation() async {
    try {
      // Verificar permisos
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          // Permisos denegados
          setState(() => _isLoading = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        // Permisos denegados permanentemente
        setState(() => _isLoading = false);
        return;
      }

      // Obtener posición
      Position position = await Geolocator.getCurrentPosition();

      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        // Inicialmente, el punto de inicio es la ubicación actual
        _startPoint = _currentPosition;
        _isLoading = false;
      });

      // Centrar mapa en la posición actual
      _mapController.move(_currentPosition!, 15);
    } catch (e) {
      debugPrint("Error getting location: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _connectWebSocket() async {
    final negotiationProvider = Provider.of<NegotiationProvider>(
      context,
      listen: false,
    );

    final connected = await _wsService.connect(widget.serverUrl, (message) {
      // Procesar mensajes recibidos
      negotiationProvider.processIncomingMessage(message);
      debugPrint("Mensaje recibido en PassengerScreen: $message");

      // Verificar si hay ofertas activas
      _checkActiveFareRequest();
    });

    setState(() {
      _isConnected = connected;
    });

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

  void _checkActiveFareRequest() {
    final negotiationProvider = Provider.of<NegotiationProvider>(
      context,
      listen: false,
    );
    final userProvider = Provider.of<UserRoleProvider>(context, listen: false);

    // Verificar si hay ofertas activas de este usuario
    bool hasActive = false;
    for (final offer in negotiationProvider.offers) {
      if (offer.fromUserId == userProvider.userId &&
          offer.status == OfferStatus.pending) {
        hasActive = true;
        break;
      }
    }

    setState(() {
      _hasActiveFareRequest = hasActive;
    });

    debugPrint("Estado de solicitud activa: $_hasActiveFareRequest");
  }

  void _selectStartPoint() {
    // No permitir cambiar puntos si hay una solicitud activa
    if (_hasActiveFareRequest) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cancelar la solicitud actual antes de crear una nueva',
          ),
        ),
      );
      return;
    }

    // Cambiar al modo de selección de punto de inicio
    setState(() {
      _selectionMode = SelectionMode.selectingStart;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Toca el mapa para seleccionar el punto de inicio'),
      ),
    );
  }

  void _selectEndPoint() {
    // No permitir cambiar puntos si hay una solicitud activa
    if (_hasActiveFareRequest) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cancelar la solicitud actual antes de crear una nueva',
          ),
        ),
      );
      return;
    }

    // Cambiar al modo de selección de punto de destino
    setState(() {
      _selectionMode = SelectionMode.selectingEnd;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Toca el mapa para seleccionar el punto de destino'),
      ),
    );
  }

  void _handleMapTap(TapPosition tapPosition, LatLng point) {
    // No permitir cambiar puntos si hay una solicitud activa
    if (_hasActiveFareRequest) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cancelar la solicitud actual antes de crear una nueva',
          ),
        ),
      );
      return;
    }

    if (_selectionMode == SelectionMode.selectingStart) {
      setState(() {
        _startPoint = point;
        _selectionMode = SelectionMode.none;
        // Si ya se había calculado una ruta, la reseteamos
        if (_isRouteCalculated) {
          _routePoints = [];
          _routeDistance = 0;
          _isRouteCalculated = false;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Punto de inicio seleccionado')),
      );
    } else if (_selectionMode == SelectionMode.selectingEnd) {
      setState(() {
        _endPoint = point;
        _selectionMode = SelectionMode.none;
        // Si ya se había calculado una ruta, la reseteamos
        if (_isRouteCalculated) {
          _routePoints = [];
          _routeDistance = 0;
          _isRouteCalculated = false;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Punto de destino seleccionado')),
      );
    }
  }

  Future<void> _calculateRoute() async {
    // No permitir calcular ruta si hay una solicitud activa
    if (_hasActiveFareRequest) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cancelar la solicitud actual antes de crear una nueva',
          ),
        ),
      );
      return;
    }

    if (_startPoint == null || _endPoint == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Selecciona puntos de inicio y destino")),
      );
      return;
    }

    setState(() => _isCalculatingRoute = true);

    try {
      // Simulación de cálculo de ruta
      // En un caso real, aquí usarías VehicleTripService().findTotalTrip

      await Future.delayed(const Duration(seconds: 1)); // Simulación de proceso

      final routePoints = [
        _startPoint!,
        LatLng(
          _startPoint!.latitude +
              (_endPoint!.latitude - _startPoint!.latitude) * 0.25,
          _startPoint!.longitude +
              (_endPoint!.longitude - _startPoint!.longitude) * 0.25,
        ),
        LatLng(
          _startPoint!.latitude +
              (_endPoint!.latitude - _startPoint!.latitude) * 0.5,
          _startPoint!.longitude +
              (_endPoint!.longitude - _startPoint!.longitude) * 0.5,
        ),
        LatLng(
          _startPoint!.latitude +
              (_endPoint!.latitude - _startPoint!.latitude) * 0.75,
          _startPoint!.longitude +
              (_endPoint!.longitude - _startPoint!.longitude) * 0.75,
        ),
        _endPoint!,
      ];

      // Calcular distancia en metros (Haversine)
      double distance = 0;
      for (int i = 0; i < routePoints.length - 1; i++) {
        distance += _calculateDistance(routePoints[i], routePoints[i + 1]);
      }

      setState(() {
        _routePoints = routePoints;
        _routeDistance = distance;
        _isCalculatingRoute = false;
        _isRouteCalculated = true;
      });

      // Calcular oferta base y actualizar en el provider
      _updateRouteInfo();

      // Ajustar zoom para mostrar toda la ruta
      _fitRouteBounds();
    } catch (e) {
      debugPrint("Error calculating route: $e");
      setState(() => _isCalculatingRoute = false);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error al calcular la ruta: $e")));
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

  void _updateRouteInfo() {
    if (!_isRouteCalculated) return;

    final negotiationProvider = Provider.of<NegotiationProvider>(
      context,
      listen: false,
    );

    // Crear objeto RouteInfo con los datos calculados
    final routeInfo = RouteInfo(
      startPoint: _startPoint!,
      endPoint: _endPoint!,
      distance: _routeDistance,
      estimatedTimeSeconds:
          (_routeDistance / 500 * 60).round(), // Estimación: 500m por minuto
      routePoints: _routePoints,
    );

    // Actualizar provider
    negotiationProvider.setCurrentRoute(routeInfo);

    // Actualizar oferta actual
    setState(() {
      _currentOffer = negotiationProvider.baseOffer;
    });
  }

  void _fitRouteBounds() {
    if (_routePoints.isEmpty) return;

    // Crear un límite que contenga todos los puntos de la ruta
    var bounds = LatLngBounds.fromPoints(_routePoints);

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
          CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50.0)),
        );
      } catch (e2) {
        // Si ambos fallan, solo mueve al centro
        _mapController.move(bounds.center, 13);
        debugPrint("Error al ajustar límites: $e2");
      }
    }
  }

  void _sendOffer() {
    final userProvider = Provider.of<UserRoleProvider>(context, listen: false);
    final negotiationProvider = Provider.of<NegotiationProvider>(
      context,
      listen: false,
    );

    // No permitir enviar múltiples solicitudes
    if (_hasActiveFareRequest) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ya tienes una solicitud activa. Cancelala antes de crear una nueva.',
          ),
        ),
      );
      return;
    }

    if (!_isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No conectado al servidor. No se puede enviar oferta.'),
        ),
      );
      return;
    }

    if (!_isRouteCalculated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Calcula una ruta primero.')),
      );
      return;
    }

    // Crear oferta
    final offer = FareOffer(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      fromUserId: userProvider.userId,
      fromUserName: userProvider.name,
      toUserId: 'all_drivers', // Offer for all drivers
      amount: _currentOffer,
      routeData: negotiationProvider.currentRoute!.toJson(),
      timestamp: DateTime.now(),
    );

    // Create message with explicit type field
    final message = {
      ...offer.toJson(),
      'type': 'fare_offer', // Ensure this is explicitly set
    };

    // Send through WebSocket
    debugPrint('Sending fare offer: ${jsonEncode(message)}');
    _wsService.sendMessage(message);

    // Add to local list
    negotiationProvider.addOffer(offer);

    // Update active request state
    setState(() {
      _hasActiveFareRequest = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Oferta de S/ ${_currentOffer.toStringAsFixed(2)} enviada',
        ),
      ),
    );
  }

  void _cancelOffer() {
    _cancelOfferIfActive();

    // Restablecer el estado de la UI para permitir nuevas solicitudes
    setState(() {
      _hasActiveFareRequest = false;
    });
  }

  void _cancelOfferIfActive() {
    if (!_hasActiveFareRequest) return;

    final userProvider = Provider.of<UserRoleProvider>(context, listen: false);
    final negotiationProvider = Provider.of<NegotiationProvider>(
      context,
      listen: false,
    );

    if (!_isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No conectado al servidor.')),
      );
      return;
    }

    // Enviar mensaje de cancelación
    final cancelMessage = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'type': 'fare_cancelled',
      'fromUserId': userProvider.userId,
      'fromUserName': userProvider.name,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    // Enviar a través de WebSocket
    _wsService.sendMessage(cancelMessage);

    // Marcar ofertas como canceladas localmente
    for (final offer in negotiationProvider.offers) {
      if (offer.fromUserId == userProvider.userId &&
          offer.status == OfferStatus.pending) {
        offer.status = OfferStatus.cancelled;
      }
    }

    negotiationProvider.notifyListeners();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Solicitud cancelada')));
  }

  void _onOfferChanged(double value) {
    setState(() {
      _currentOffer = value;
    });
  }

  void _clearRoute() {
    // No permitir limpiar ruta si hay una solicitud activa
    if (_hasActiveFareRequest) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cancelar la solicitud actual antes de crear una nueva',
          ),
        ),
      );
      return;
    }

    setState(() {
      _endPoint = null;
      _routePoints = [];
      _routeDistance = 0;
      _isRouteCalculated = false;
    });

    final negotiationProvider = Provider.of<NegotiationProvider>(
      context,
      listen: false,
    );
    negotiationProvider.clearOffers();
  }

  @override
  Widget build(BuildContext context) {
    final negotiationProvider = Provider.of<NegotiationProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pasajero - Selecciona Ruta'),
        backgroundColor: Colors.blue[100],
        actions: [
          IconButton(
            icon: Icon(_isConnected ? Icons.wifi : Icons.wifi_off),
            onPressed: _isConnected ? null : _connectWebSocket,
            tooltip: _isConnected ? 'Conectado' : 'Desconectado',
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  // Mapa grande con más espacio
                  Expanded(
                    flex: 2, // Dar más espacio al mapa
                    child: Stack(
                      children: [
                        FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter:
                                _currentPosition ??
                                const LatLng(-16.4090, -71.5375),
                            initialZoom: 15.0,
                            onTap: _handleMapTap,
                          ),
                          children: [
                            // Capa de mapa base OpenStreetMap
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName:
                                  'com.example.mototaxi_fare_negotiation',
                            ),

                            // Capa de marcadores
                            MarkerLayer(
                              markers: [
                                // Marcador de posición actual
                                if (_currentPosition != null)
                                  Marker(
                                    point: _currentPosition!,
                                    width: 40,
                                    height: 40,
                                    child: const Icon(
                                      Icons.my_location,
                                      color: Colors.blue,
                                      size: 30,
                                    ),
                                  ),

                                // Marcador de punto inicial
                                if (_startPoint != null)
                                  Marker(
                                    point: _startPoint!,
                                    width: 40,
                                    height: 40,
                                    child: const Icon(
                                      Icons.trip_origin,
                                      color: Colors.green,
                                      size: 30,
                                    ),
                                  ),

                                // Marcador de punto final
                                if (_endPoint != null)
                                  Marker(
                                    point: _endPoint!,
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

                            // Capa de ruta
                            if (_routePoints.isNotEmpty)
                              PolylineLayer(
                                polylines: [
                                  Polyline(
                                    points: _routePoints,
                                    strokeWidth: 4.0,
                                    color: Colors.blue,
                                  ),
                                ],
                              ),
                          ],
                        ),

                        // Controles de selección de puntos
                        Positioned(
                          top: 16,
                          left: 16,
                          right: 16,
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                children: [
                                  // Si hay una solicitud activa, mostrar información
                                  if (_hasActiveFareRequest)
                                    Container(
                                      padding: const EdgeInsets.all(8.0),
                                      decoration: BoxDecoration(
                                        color: Colors.orange[50],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.info_outline,
                                            color: Colors.orange,
                                          ),
                                          const SizedBox(width: 8),
                                          const Expanded(
                                            child: Text(
                                              'Solicitud activa - esperando respuesta',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          ElevatedButton(
                                            onPressed: _cancelOffer,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red[100],
                                              foregroundColor: Colors.red[800],
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 0,
                                                  ),
                                            ),
                                            child: const Text('Cancelar'),
                                          ),
                                        ],
                                      ),
                                    )
                                  else
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: _selectStartPoint,
                                            icon: const Icon(Icons.trip_origin),
                                            label: const Text('Origen'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Colors.green[100],
                                              foregroundColor:
                                                  Colors.green[800],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: _selectEndPoint,
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
                                  if (_startPoint != null &&
                                      _endPoint != null &&
                                      !_isRouteCalculated &&
                                      !_hasActiveFareRequest)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          onPressed: _calculateRoute,
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
                        ),

                        // Indicador de carga durante el cálculo de ruta
                        if (_isCalculatingRoute)
                          const Center(
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
                          ),
                      ],
                    ),
                  ),

                  // Panel de ajuste de tarifa si hay ruta calculada
                  if (_isRouteCalculated && !_hasActiveFareRequest)
                    Card(
                      margin: const EdgeInsets.all(8.0),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Proponer una tarifa',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.refresh),
                                  onPressed: _clearRoute,
                                  tooltip: 'Limpiar ruta',
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Distancia: ${(_routeDistance / 1000).toStringAsFixed(2)} km',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Tarifa sugerida: S/ ${negotiationProvider.baseOffer.toStringAsFixed(2)}',
                              style: const TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 16),
                            FareAdjustmentSlider(
                              initialValue: negotiationProvider.baseOffer,
                              minValue: negotiationProvider.baseOffer * 0.7,
                              maxValue: negotiationProvider.baseOffer * 1.5,
                              onChanged: _onOfferChanged,
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _sendOffer,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                                child: Text(
                                  'ENVIAR OFERTA DE S/ ${_currentOffer.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Lista de ofertas y contraofertas
                  if (negotiationProvider.offers.isNotEmpty)
                    Expanded(
                      child: OfferList(
                        offers: negotiationProvider.offers,
                        userRole: UserRole.passenger,
                        onAccept: (offer) {
                          // Implementar lógica para aceptar contraoferta
                          offer.status = OfferStatus.accepted;
                          _wsService.sendMessage({
                            ...offer.toJson(),
                            'type': 'fare_accepted',
                          });
                          setState(() {
                            _hasActiveFareRequest =
                                false; // Ya no hay solicitud activa una vez aceptada
                          });
                        },
                        onReject: (offer) {
                          // Implementar lógica para rechazar contraoferta
                          offer.status = OfferStatus.rejected;
                          _wsService.sendMessage({
                            ...offer.toJson(),
                            'type': 'fare_rejected',
                          });
                          setState(() {});
                        },
                      ),
                    ),
                ],
              ),

      // Botón para centrar en la ubicación actual
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_currentPosition != null) {
            _mapController.move(_currentPosition!, 15);
          }
        },
        child: const Icon(Icons.my_location),
      ),
    );
  }
}

enum SelectionMode { none, selectingStart, selectingEnd }
