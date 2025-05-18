// Archivo: lib/providers/negotiation_provider.dart

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

  void processIncomingMessage(String message) {
    try {
      final data = jsonDecode(message);
      switch (data['type']) {
        case 'fare_offer':
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
          break;
        case 'fare_rejected':
          final offer = FareOffer.fromJson(data);
          offer.status = OfferStatus.rejected;
          addOffer(offer);
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
}
