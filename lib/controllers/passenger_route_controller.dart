import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../models/route_info.dart';
import '../models/fare_offer.dart';
import '../providers/negotiation_provider.dart';
import '../providers/user_role_provider.dart';
import '../services/websocket_service.dart';
import '../services/route_service.dart';
import 'dart:convert';
import 'dart:async';

enum SelectionMode { none, selectingStart, selectingEnd }

class PassengerRouteController extends ChangeNotifier {
  final BuildContext context;
  final String serverUrl;
  final WebSocketService wsService = WebSocketService();
  final MapController mapController = MapController();
  final RouteService _routeService = RouteService();

  // Estado de la conexión y ruta
  bool _isConnected = false;
  bool _isLoading = true;
  bool _isCalculatingRoute = false;
  bool _isRouteCalculated = false;
  bool _hasActiveFareRequest = false;
  SelectionMode _selectionMode = SelectionMode.none;

  // Datos de ruta
  LatLng? _currentPosition;
  LatLng? _startPoint;
  LatLng? _endPoint;
  List<LatLng> _routePoints = [];
  double _routeDistance = 0;
  double _currentOffer = 0.0;

  // Getters
  bool get isConnected => _isConnected;
  bool get isLoading => _isLoading;
  bool get isCalculatingRoute => _isCalculatingRoute;
  bool get isRouteCalculated => _isRouteCalculated;
  bool get hasActiveFareRequest => _hasActiveFareRequest;
  SelectionMode get selectionMode => _selectionMode;
  LatLng? get currentPosition => _currentPosition;
  LatLng? get startPoint => _startPoint;
  LatLng? get endPoint => _endPoint;
  List<LatLng> get routePoints => _routePoints;
  double get routeDistance => _routeDistance;
  double get currentOffer => _currentOffer;

  PassengerRouteController({required this.context, required this.serverUrl});

  Future<void> initialize() async {
    await connectWebSocket();
    await getCurrentLocation();
  }

  @override
  void dispose() {
    cancelOfferIfActive();
    wsService.disconnect();
    super.dispose();
  }

  // Conexión WebSocket y ubicación

  Future<void> connectWebSocket() async {
    final negotiationProvider = Provider.of<NegotiationProvider>(
      context,
      listen: false,
    );

    final connected = await wsService.connect(serverUrl, (message) {
      negotiationProvider.processIncomingMessage(message);
      debugPrint("Mensaje recibido en PassengerScreen: $message");
      checkActiveFareRequest();
    });

    _isConnected = connected;
    notifyListeners();

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
            onPressed: connectWebSocket,
          ),
        ),
      );
    }
  }

  Future<void> getCurrentLocation() async {
    try {
      // Verificar permisos
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          // Permisos denegados
          _isLoading = false;
          notifyListeners();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        // Permisos denegados permanentemente
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Obtener posición actual
      Position position = await Geolocator.getCurrentPosition();

      _currentPosition = LatLng(position.latitude, position.longitude);
      _startPoint = _currentPosition;
      _isLoading = false;
      notifyListeners();

      // Centrar mapa en la posición actual
      centerOnCurrentLocation();
    } catch (e) {
      debugPrint("Error getting location: $e");
      _isLoading = false;
      notifyListeners();
    }
  }

  void centerOnCurrentLocation() {
    if (_currentPosition != null) {
      mapController.move(_currentPosition!, 15);
    }
  }

  // Métodos para gestión de rutas

  void selectStartPoint() {
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

    _selectionMode = SelectionMode.selectingStart;
    notifyListeners();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Toca el mapa para seleccionar el punto de inicio'),
      ),
    );
  }

  void selectEndPoint() {
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

    _selectionMode = SelectionMode.selectingEnd;
    notifyListeners();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Toca el mapa para seleccionar el punto de destino'),
      ),
    );
  }

  void handleMapTap(TapPosition tapPosition, LatLng point) {
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
      _startPoint = point;
      _selectionMode = SelectionMode.none;

      // Si ya se había calculado una ruta, la reseteamos
      if (_isRouteCalculated) {
        _routePoints = [];
        _routeDistance = 0;
        _isRouteCalculated = false;
      }

      notifyListeners();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Punto de inicio seleccionado')),
      );
    } else if (_selectionMode == SelectionMode.selectingEnd) {
      _endPoint = point;
      _selectionMode = SelectionMode.none;

      // Si ya se había calculado una ruta, la reseteamos
      if (_isRouteCalculated) {
        _routePoints = [];
        _routeDistance = 0;
        _isRouteCalculated = false;
      }

      notifyListeners();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Punto de destino seleccionado')),
      );
    }
  }

  Future<void> calculateRoute() async {
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

    _isCalculatingRoute = true;
    notifyListeners();

    try {
      // Verificar si los puntos están en carreteras para vehículos
      final bool startIsValid = await _routeService.isOnVehicleRoad(
        _startPoint!,
      );
      final bool endIsValid = await _routeService.isOnVehicleRoad(_endPoint!);

      // Si alguno no está en carretera, mostramos un mensaje y ajustamos los puntos
      if (!startIsValid || !endIsValid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Algunos puntos no están en calles para vehículos. Ajustando a la calle más cercana.",
            ),
            duration: Duration(seconds: 3),
          ),
        );

        // Ajustar los puntos a carreteras para vehículos
        if (!startIsValid) {
          final LatLng snappedStart = await _routeService.snapToVehicleRoad(
            _startPoint!,
          );
          _startPoint = snappedStart;
          notifyListeners();
        }

        if (!endIsValid) {
          final LatLng snappedEnd = await _routeService.snapToVehicleRoad(
            _endPoint!,
          );
          _endPoint = snappedEnd;
          notifyListeners();
        }
      }

      // Ahora calcular la ruta
      final trip = await _routeService.findTotalTrip(
        [_startPoint!, _endPoint!],
        preferWalkingPaths: false,
        replaceWaypointsWithBuildingEntrances: false,
      );

      _routePoints = trip.route;
      _routeDistance = trip.distance;
      _isCalculatingRoute = false;
      _isRouteCalculated = true;
      notifyListeners();

      // Calcular oferta base y actualizar en el provider
      updateRouteInfo();

      // Ajustar zoom para mostrar toda la ruta
      fitRouteBounds();

      if (trip.route.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "No se pudo encontrar una ruta viable para vehículos",
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error calculating route: $e");
      _isCalculatingRoute = false;
      notifyListeners();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error al calcular la ruta: $e")));
    }
  }

  void updateRouteInfo() {
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
    _currentOffer = negotiationProvider.baseOffer;
    notifyListeners();
  }

  void fitRouteBounds() {
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

    // Usar el método actual para ajustar la vista
    try {
      mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50.0)),
      );
    } catch (e) {
      // Si algo falla, al menos centrar en el medio
      mapController.move(bounds.center, 14);
      debugPrint("Error ajustando límites: $e");
    }
  }

  // Métodos para gestión de ofertas

  void sendOffer() {
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
            'Ya tienes una solicitud activa. Cancélala antes de crear una nueva.',
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
    wsService.sendMessage(message);

    // Add to local list
    negotiationProvider.addOffer(offer);

    // Update active request state
    _hasActiveFareRequest = true;
    notifyListeners();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Oferta de S/ ${_currentOffer.toStringAsFixed(2)} enviada',
        ),
      ),
    );
  }

  void cancelOffer() {
    cancelOfferIfActive();

    // Restablecer el estado de la UI para permitir nuevas solicitudes
    _hasActiveFareRequest = false;
    notifyListeners();
  }

  void cancelOfferIfActive() {
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
    wsService.sendMessage(cancelMessage);

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

  void checkActiveFareRequest() {
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

    if (_hasActiveFareRequest != hasActive) {
      _hasActiveFareRequest = hasActive;
      notifyListeners();
    }

    debugPrint("Estado de solicitud activa: $_hasActiveFareRequest");
  }

  void onOfferChanged(double value) {
    _currentOffer = value;
    notifyListeners();
  }

  void clearRoute() {
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

    _endPoint = null;
    _routePoints = [];
    _routeDistance = 0;
    _isRouteCalculated = false;
    notifyListeners();

    final negotiationProvider = Provider.of<NegotiationProvider>(
      context,
      listen: false,
    );
    negotiationProvider.clearOffers();
  }

  void acceptOffer(FareOffer offer) {
    // Implementación de aceptación de oferta
    offer.status = OfferStatus.accepted;
    wsService.sendMessage({...offer.toJson(), 'type': 'fare_accepted'});
    _hasActiveFareRequest = false;
    notifyListeners();
  }

  void rejectOffer(FareOffer offer) {
    // Implementación de rechazo de oferta
    offer.status = OfferStatus.rejected;
    wsService.sendMessage({...offer.toJson(), 'type': 'fare_rejected'});
    notifyListeners();
  }
}
