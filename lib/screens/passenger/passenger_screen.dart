import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import '../../models/fare_offer.dart';
import '../../providers/negotiation_provider.dart';
import '../../providers/user_role_provider.dart';
import '../../controllers/passenger_route_controller.dart';
import '../../widgets/fare_adjustment_slider.dart';
import '../../widgets/offer_list.dart';
import '../../widgets/route_info_panel.dart';
import '../../widgets/counter_offer_dialog.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import '../../providers/user_role_provider.dart';
import '../../services/websocket_service.dart';

class PassengerScreen extends StatefulWidget {
  final String serverUrl;

  const PassengerScreen({super.key, required this.serverUrl});

  @override
  State<PassengerScreen> createState() => _PassengerScreenState();
}

class _PassengerScreenState extends State<PassengerScreen> {
  final WebSocketService _wsService = WebSocketService();

  PassengerRouteController? _controller;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    // Inicializamos de manera más segura
    _initializeController();
  }

  void _acceptCounterOffer(FareOffer offer) {
    final userProvider = Provider.of<UserRoleProvider>(context, listen: false);
    final controller = Provider.of<PassengerRouteController>(
      context,
      listen: false,
    );

    // Actualizamos el estado de la oferta
    offer.status = OfferStatus.accepted;

    // Creamos un mensaje de aceptación
    final acceptMessage = {
      ...offer.toJson(),
      'type': 'fare_accepted',
      'fromUserId': userProvider.userId,
      'fromUserName': userProvider.name,
      'toUserId':
          offer.fromUserId, // Dirigido al conductor que hizo la contraoferta
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    // Enviamos el mensaje
    controller.wsService.sendMessage(acceptMessage);

    // El controlador se encargará de actualizar el estado
    controller.cancelOffer(); // Esto establece hasActiveFareRequest en false

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Has aceptado la contraoferta de S/ ${offer.amount.toStringAsFixed(2)}',
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  // Rechazar una contraoferta
  void _rejectCounterOffer(FareOffer offer) {
    final userProvider = Provider.of<UserRoleProvider>(context, listen: false);

    // Actualizamos el estado de la oferta
    offer.status = OfferStatus.rejected;

    // Creamos un mensaje de rechazo
    final rejectMessage = {
      ...offer.toJson(),
      'type': 'fare_rejected',
      'fromUserId': userProvider.userId,
      'fromUserName': userProvider.name,
      'toUserId':
          offer.fromUserId, // Dirigido al conductor que hizo la contraoferta
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    // Enviamos el mensaje
    _wsService.sendMessage(rejectMessage);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Has rechazado la contraoferta'),
        backgroundColor: Colors.red,
      ),
    );
  }

  // Implementar nueva contraoferta (opcional - si quieres que el pasajero pueda hacer contraofertas múltiples)
  void _makeCounterCounterOffer(FareOffer originalOffer) {
    final userProvider = Provider.of<UserRoleProvider>(context, listen: false);
    final negotiationProvider = Provider.of<NegotiationProvider>(
      context,
      listen: false,
    );

    // Mostramos un diálogo para que el pasajero ingrese el nuevo monto
    showDialog(
      context: context,
      builder:
          (context) => CounterOfferDialog(
            originalOffer: originalOffer,
            onSubmit: (amount) {
              // Crear la nueva contraoferta
              final counterOffer = negotiationProvider.createCounterOffer(
                originalOffer,
                fromUserId: userProvider.userId,
                fromUserName: userProvider.name,
                amount: amount,
              );

              // Enviar mensaje
              final message = {
                ...counterOffer.toJson(),
                'type': 'fare_counter_offer',
              };

              // Enviar a través de WebSocket
              _wsService.sendMessage(message);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Nueva contraoferta de S/ ${amount.toStringAsFixed(2)} enviada',
                  ),
                ),
              );
            },
          ),
    );
  }

  Future<void> _initializeController() async {
    setState(() {
      _isInitializing = true;
    });

    // Creamos el controlador
    final controller = PassengerRouteController(
      context: context,
      serverUrl: widget.serverUrl,
    );

    // Inicializamos el controlador
    await controller.initialize();

    // Solo actualizamos el estado una vez que todo esté listo
    setState(() {
      _controller = controller;
      _isInitializing = false;
    });
  }

  @override
  void dispose() {
    // Verificamos que el controlador exista antes de llamar a dispose
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Mostramos un indicador de carga mientras se inicializa
    if (_isInitializing || _controller == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Trip Router para Mototaxis'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Inicializando aplicación...'),
            ],
          ),
        ),
      );
    }

    // Una vez inicializado, mostramos la pantalla completa
    return ChangeNotifierProvider.value(
      value: _controller!,
      child: Consumer<PassengerRouteController>(
        builder: (context, controller, _) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Trip Router para Mototaxis'),
              backgroundColor: Theme.of(context).colorScheme.inversePrimary,
              actions: [
                IconButton(
                  icon: Icon(
                    controller.isConnected ? Icons.wifi : Icons.wifi_off,
                  ),
                  onPressed:
                      controller.isConnected
                          ? null
                          : controller.connectWebSocket,
                  tooltip:
                      controller.isConnected ? 'Conectado' : 'Desconectado',
                ),
              ],
            ),
            body:
                controller.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : Stack(
                      children: [
                        // El mapa
                        FlutterMap(
                          mapController: controller.mapController,
                          options: MapOptions(
                            initialCenter:
                                controller.currentPosition ??
                                const LatLng(-16.4090, -71.5375),
                            initialZoom: 15.0,
                            onTap: controller.handleMapTap,
                          ),
                          children: [
                            // Capa de mapa base
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
                                    child: const Icon(
                                      Icons.place,
                                      color: Colors.red,
                                      size: 30,
                                    ),
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
                                  if (controller.hasActiveFareRequest)
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
                                            onPressed: controller.cancelOffer,
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
                                            onPressed:
                                                controller.selectStartPoint,
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
                                            onPressed:
                                                controller.selectEndPoint,
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
                                      !controller.hasActiveFareRequest)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          onPressed: controller.calculateRoute,
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
                        if (controller.isCalculatingRoute)
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

                        // Panel de información de ruta si está calculada
                        if (controller.routePoints.isNotEmpty)
                          RouteInfoPanel(
                            distance: controller.routeDistance,
                            onClear: controller.clearRoute,
                          ),

                        // Panel de ajuste de tarifa si hay ruta calculada
                        if (controller.isRouteCalculated &&
                            !controller.hasActiveFareRequest &&
                            controller.routePoints.isNotEmpty)
                          Positioned(
                            bottom: 120, // Debajo del panel de info de ruta
                            left: 16,
                            right: 16,
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Proponer una tarifa',
                                      style:
                                          Theme.of(
                                            context,
                                          ).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 16),
                                    Consumer<NegotiationProvider>(
                                      builder: (
                                        context,
                                        negotiationProvider,
                                        child,
                                      ) {
                                        return FareAdjustmentSlider(
                                          initialValue:
                                              negotiationProvider.baseOffer,
                                          minValue:
                                              negotiationProvider.baseOffer *
                                              0.7,
                                          maxValue:
                                              negotiationProvider.baseOffer *
                                              1.5,
                                          onChanged: controller.onOfferChanged,
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: controller.sendOffer,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.orange,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                        ),
                                        child: Text(
                                          'ENVIAR OFERTA DE S/ ${controller.currentOffer.toStringAsFixed(2)}',
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
                          ),

                        // Lista de ofertas y contraofertas
                        Consumer<NegotiationProvider>(
                          builder: (context, negotiationProvider, child) {
                            return negotiationProvider.offers.isNotEmpty
                                ? Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  height:
                                      200, // Altura fija para la lista de ofertas
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          spreadRadius: 1,
                                          blurRadius: 5,
                                          offset: const Offset(0, -3),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 8,
                                            horizontal: 16,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.grey[100],
                                            border: Border(
                                              bottom: BorderSide(
                                                color: Colors.grey[300]!,
                                                width: 1,
                                              ),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.notifications,
                                                size: 20,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Respuestas de conductores',
                                                style:
                                                    Theme.of(
                                                      context,
                                                    ).textTheme.titleSmall,
                                              ),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          child: OfferList(
                                            offers: negotiationProvider.offers,
                                            userRole: UserRole.passenger,
                                            onAccept: _acceptCounterOffer,
                                            onReject: _rejectCounterOffer,
                                            onCounterOffer:
                                                _makeCounterCounterOffer, // Opcional
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                : const SizedBox.shrink();
                          },
                        ),
                      ],
                    ),
            // Botón para centrar en la ubicación actual
            floatingActionButton: FloatingActionButton(
              onPressed: controller.centerOnCurrentLocation,
              child: const Icon(Icons.my_location),
            ),
          );
        },
      ),
    );
  }
}
