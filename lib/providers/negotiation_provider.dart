// lib/providers/negotiation_provider.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/fare_offer.dart';
import '../models/route_info.dart';

class NegotiationProvider extends ChangeNotifier {
  final List<FareOffer> _offers = [];
  RouteInfo? _currentRoute;
  double _baseOffer = 0.0;

  List<FareOffer> get offers => List.unmodifiable(_offers);
  RouteInfo? get currentRoute => _currentRoute;
  double get baseOffer => _baseOffer;

  void setCurrentRoute(RouteInfo route) {
    _currentRoute = route;
    // Calcular oferta base basada en la distancia
    _calculateBaseOffer();
    notifyListeners();
  }

  void _calculateBaseOffer() {
    if (_currentRoute == null) return;

    // Tarifa base de 3 soles + 1 sol por kilómetro
    _baseOffer = 3.0 + (_currentRoute!.distance / 1000) * 1.0;

    // Redondear a 0.5 más cercano
    _baseOffer = ((_baseOffer * 2).round() / 2);

    notifyListeners();
  }

  void addOffer(FareOffer offer) {
    _offers.add(offer);
    notifyListeners();
  }

  // Agregar método para crear una contraoferta
  FareOffer createCounterOffer(
    FareOffer originalOffer, {
    required String fromUserId,
    required String fromUserName,
    required double amount,
  }) {
    final counterOffer = originalOffer.createCounterOffer(
      fromUserId: fromUserId,
      fromUserName: fromUserName,
      amount: amount,
    );

    addOffer(counterOffer);
    return counterOffer;
  }

  // Validar si un monto de contraoferta es válido
  bool isValidCounterOffer(double amount, FareOffer originalOffer) {
    // Mínimo: no menos del 70% de la tarifa base
    double minAmount = _baseOffer * 0.7;

    // Máximo: no más del 200% de la tarifa base
    double maxAmount = _baseOffer * 2.0;

    return amount >= minAmount && amount <= maxAmount;
  }

  void processIncomingMessage(String message) {
    try {
      debugPrint('NegotiationProvider processing message: $message');
      final data = jsonDecode(message);

      switch (data['type']) {
        case 'fare_offer':
          debugPrint('Processing fare_offer');
          final offer = FareOffer.fromJson(data);
          addOffer(offer);
          break;
        case 'fare_counter_offer':
          final offer = FareOffer.fromJson(data);
          addOffer(offer);
          break;
        case 'fare_accepted':
          final offer = FareOffer.fromJson(data);
          offer.status = OfferStatus.accepted;
          addOffer(offer);

          // También actualizar el estado de la oferta original
          if (offer.parentOfferId != null) {
            for (final existingOffer in _offers) {
              if (existingOffer.id == offer.parentOfferId) {
                existingOffer.status = OfferStatus.accepted;
                break;
              }
            }
          }
          notifyListeners();
          break;
        case 'fare_rejected':
          final offer = FareOffer.fromJson(data);
          offer.status = OfferStatus.rejected;
          addOffer(offer);

          // También actualizar el estado de la oferta original
          if (offer.parentOfferId != null) {
            for (final existingOffer in _offers) {
              if (existingOffer.id == offer.parentOfferId) {
                existingOffer.status = OfferStatus.rejected;
                break;
              }
            }
          }
          notifyListeners();
          break;
        case 'fare_cancelled':
          // Cuando un pasajero cancela la solicitud
          if (_offers.isNotEmpty) {
            final fromUserId = data['fromUserId'];

            // Marcar todas las ofertas de ese usuario como canceladas
            for (final offer in _offers) {
              if (offer.fromUserId == fromUserId ||
                  offer.toUserId == fromUserId) {
                offer.status = OfferStatus.cancelled;
              }
            }
            notifyListeners();
          }
          break;
      }
    } catch (e) {
      debugPrint('Error processing message: $e');
    }
  }

  void clearOffers() {
    _offers.clear();
    notifyListeners();
  }

  // Obtener todas las ofertas relacionadas con un ID de usuario
  List<FareOffer> getOffersForUser(String userId) {
    return _offers
        .where(
          (offer) =>
              offer.fromUserId == userId ||
              offer.toUserId == userId ||
              offer.toUserId == 'all_drivers',
        )
        .toList();
  }

  // Obtener solo las ofertas pendientes
  List<FareOffer> getPendingOffers() {
    return _offers
        .where((offer) => offer.status == OfferStatus.pending)
        .toList();
  }

  // Obtener la última oferta en una conversación
  FareOffer? getLatestOfferInConversation(String offerId) {
    // Primero encontrar la oferta
    final FareOffer? originalOffer = _offers.firstWhere(
      (offer) => offer.id == offerId,
      orElse: () => null as FareOffer,
    );

    if (originalOffer == null) return null;

    // Buscar todas las contraofertas relacionadas
    final List<FareOffer> relatedOffers =
        _offers
            .where(
              (offer) =>
                  offer.parentOfferId == offerId ||
                  offer.id == offerId ||
                  (originalOffer.parentOfferId != null &&
                      offer.parentOfferId == originalOffer.parentOfferId),
            )
            .toList();

    // Ordenarlas por fecha (más reciente primero)
    relatedOffers.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // Devolver la más reciente
    return relatedOffers.isNotEmpty ? relatedOffers.first : null;
  }
}
