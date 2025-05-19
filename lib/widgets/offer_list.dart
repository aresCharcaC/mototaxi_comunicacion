// lib/widgets/offer_list.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/fare_offer.dart';
import '../providers/user_role_provider.dart';

class OfferList extends StatelessWidget {
  final List<FareOffer> offers;
  final UserRole userRole;
  final Function(FareOffer)? onAccept;
  final Function(FareOffer)? onReject;
  final Function(FareOffer)? onCounterOffer;

  const OfferList({
    super.key,
    required this.offers,
    required this.userRole,
    this.onAccept,
    this.onReject,
    this.onCounterOffer,
  });

  @override
  Widget build(BuildContext context) {
    // Ordenar ofertas por más recientes primero
    final sortedOffers = List<FareOffer>.from(offers)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (sortedOffers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              userRole == UserRole.passenger
                  ? Icons.motorcycle_outlined
                  : Icons.person_search_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              userRole == UserRole.passenger
                  ? 'Todavía no hay respuestas de conductores'
                  : 'Esperando solicitudes de pasajeros',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: sortedOffers.length,
      padding: const EdgeInsets.all(8.0),
      itemBuilder: (context, index) {
        final offer = sortedOffers[index];

        // Determinar si la oferta es para/de este usuario según su rol
        final bool isForThisUser =
            userRole == UserRole.driver
                ? offer.toUserId == 'all_drivers' ||
                    offer.toUserId == 'your_driver_id'
                : userRole == UserRole.passenger &&
                    offer.fromUserId != 'your_passenger_id';

        final bool isFromThisUser =
            userRole == UserRole.passenger
                ? offer.toUserId == 'all_drivers'
                : userRole == UserRole.driver &&
                    offer.toUserId == 'all_drivers';

        // Determinar si es una contraoferta
        final bool isCounterOffer = offer.offerType == OfferType.counter_offer;

        return GestureDetector(
          onTap: () {
            if (userRole == UserRole.driver) {
              // Si somos conductor, mostramos los detalles de la ruta al tocar
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => _RouteDetailScreen(offer: offer),
                ),
              );
            }
          },
          child: OfferCard(
            offer: offer,
            userRole: userRole,
            isFromThisUser: isFromThisUser,
            isForThisUser: isForThisUser,
            isCounterOffer: isCounterOffer,
            onAccept: onAccept,
            onReject: onReject,
            onCounterOffer: onCounterOffer,
          ),
        );
      },
    );
  }
}

// Pantalla simple para mostrar detalles de la ruta
class _RouteDetailScreen extends StatelessWidget {
  final FareOffer offer;

  const _RouteDetailScreen({required this.offer});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalles de la Ruta')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Oferta: S/ ${offer.amount.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            if (offer.offerType == OfferType.counter_offer)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Contraoferta',
                  style: TextStyle(
                    color: Colors.deepOrange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const SizedBox(height: 20),
            Text(
              'Desde: ${offer.routeData['startPoint']['lat']}, ${offer.routeData['startPoint']['lng']}',
            ),
            const SizedBox(height: 8),
            Text(
              'Hasta: ${offer.routeData['endPoint']['lat']}, ${offer.routeData['endPoint']['lng']}',
            ),
            const SizedBox(height: 8),
            Text(
              'Distancia: ${(offer.routeData['distance'] as num).toStringAsFixed(2)} metros',
            ),
            const SizedBox(height: 8),
            Text(
              'Tiempo estimado: ${((offer.routeData['estimatedTimeSeconds'] as int) / 60).round()} minutos',
            ),
            const SizedBox(height: 30),
            const Center(
              child: Text(
                'Próximamente: Visualización en mapa',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OfferCard extends StatelessWidget {
  final FareOffer offer;
  final UserRole userRole;
  final bool isFromThisUser;
  final bool isForThisUser;
  final bool isCounterOffer;
  final Function(FareOffer)? onAccept;
  final Function(FareOffer)? onReject;
  final Function(FareOffer)? onCounterOffer;

  const OfferCard({
    super.key,
    required this.offer,
    required this.userRole,
    required this.isFromThisUser,
    required this.isForThisUser,
    required this.isCounterOffer,
    this.onAccept,
    this.onReject,
    this.onCounterOffer,
  });

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('HH:mm');

    // Color y alineación basados en quién envió el mensaje
    final bgColor =
        isFromThisUser
            ? Colors.blue.shade50
            : isCounterOffer
            ? Colors.orange.shade50
            : Colors.green.shade50;

    final alignment =
        isFromThisUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    // Texto del estado de la oferta
    String statusText = '';
    Color statusColor = Colors.grey;

    switch (offer.status) {
      case OfferStatus.accepted:
        statusText = '✓ Aceptada';
        statusColor = Colors.green;
        break;
      case OfferStatus.rejected:
        statusText = '✗ Rechazada';
        statusColor = Colors.red;
        break;
      case OfferStatus.expired:
        statusText = 'Expirada';
        statusColor = Colors.grey;
        break;
      case OfferStatus.cancelled:
        statusText = 'Cancelada';
        statusColor = Colors.grey;
        break;
      case OfferStatus.pending:
        statusText = 'Pendiente';
        statusColor = Colors.orange;
        break;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      color: bgColor,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: alignment,
          children: [
            // Encabezado con nombre y hora
            Row(
              mainAxisAlignment:
                  isFromThisUser
                      ? MainAxisAlignment.end
                      : MainAxisAlignment.start,
              children: [
                if (!isFromThisUser) ...[
                  CircleAvatar(
                    backgroundColor:
                        isCounterOffer ? Colors.orange : Colors.green,
                    radius: 16,
                    child: Icon(
                      userRole == UserRole.passenger
                          ? Icons.motorcycle
                          : Icons.person,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  offer.fromUserName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Text(
                  timeFormat.format(offer.timestamp),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                if (isFromThisUser) ...[
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor:
                        isCounterOffer ? Colors.orange : Colors.blue,
                    radius: 16,
                    child: Icon(
                      userRole == UserRole.passenger
                          ? Icons.person
                          : Icons.motorcycle,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ],
              ],
            ),

            if (isCounterOffer) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange),
                ),
                child: Text(
                  'Contraoferta a S/ ${offer.amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.deepOrange,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Monto de la oferta
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color:
                      offer.status == OfferStatus.pending
                          ? Colors.orange
                          : Colors.grey.shade300,
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.attach_money, color: Colors.green),
                  const SizedBox(width: 8),
                  Text(
                    'S/ ${offer.amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Estado de la oferta
            Text(
              statusText,
              style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
            ),

            // Botones de acción si es necesario
            if (!isFromThisUser && offer.status == OfferStatus.pending) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Botón Rechazar
                  ElevatedButton.icon(
                    onPressed: onReject != null ? () => onReject!(offer) : null,
                    icon: const Icon(Icons.close),
                    label: const Text('Rechazar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade100,
                      foregroundColor: Colors.red.shade800,
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Botón hacer contraoferta (solo para conductor)
                  if (userRole == UserRole.driver && onCounterOffer != null)
                    ElevatedButton.icon(
                      onPressed: () => onCounterOffer!(offer),
                      icon: const Icon(Icons.edit),
                      label: const Text('Contraoferta'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade100,
                        foregroundColor: Colors.blue.shade800,
                      ),
                    ),

                  const SizedBox(width: 8),

                  // Botón Aceptar
                  ElevatedButton.icon(
                    onPressed: onAccept != null ? () => onAccept!(offer) : null,
                    icon: const Icon(Icons.check),
                    label: const Text('Aceptar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade100,
                      foregroundColor: Colors.green.shade800,
                    ),
                  ),
                ],
              ),
            ],

            // Instrucción para ver detalles (solo para conductores)
            if (userRole == UserRole.driver &&
                offer.status == OfferStatus.pending &&
                !isFromThisUser)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  "Toca para ver detalles de la ruta",
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey[600],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
