// lib/models/fare_offer.dart
enum OfferStatus { pending, accepted, rejected, expired, cancelled }

enum OfferType { initial, counter_offer }

class FareOffer {
  final String id;
  final String fromUserId;
  final String fromUserName;
  final String toUserId;
  final double amount;
  final Map<String, dynamic> routeData;
  final DateTime timestamp;
  OfferStatus status;
  final OfferType offerType;
  final String?
  parentOfferId; // ID de la oferta original si es una contraoferta

  FareOffer({
    required this.id,
    required this.fromUserId,
    required this.fromUserName,
    required this.toUserId,
    required this.amount,
    required this.routeData,
    required this.timestamp,
    this.status = OfferStatus.pending,
    this.offerType = OfferType.initial,
    this.parentOfferId,
  });

  factory FareOffer.fromJson(Map<String, dynamic> json) {
    return FareOffer(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      fromUserId: json['fromUserId'] ?? '',
      fromUserName: json['fromUserName'] ?? 'Usuario',
      toUserId: json['toUserId'] ?? '',
      amount: json['amount']?.toDouble() ?? 0.0,
      routeData: json['routeData'] ?? {},
      timestamp:
          json['timestamp'] != null
              ? DateTime.fromMillisecondsSinceEpoch(json['timestamp'])
              : DateTime.now(),
      status: _statusFromString(json['status'] ?? 'pending'),
      offerType: _typeFromString(json['offerType'] ?? 'initial'),
      parentOfferId: json['parentOfferId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': 'fare_offer', // Para el procesamiento de mensajes
      'fromUserId': fromUserId,
      'fromUserName': fromUserName,
      'toUserId': toUserId,
      'amount': amount,
      'routeData': routeData,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'status': _statusToString(status),
      'offerType': _typeToString(offerType),
      'parentOfferId': parentOfferId,
    };
  }

  static OfferStatus _statusFromString(String status) {
    switch (status) {
      case 'accepted':
        return OfferStatus.accepted;
      case 'rejected':
        return OfferStatus.rejected;
      case 'expired':
        return OfferStatus.expired;
      case 'cancelled':
        return OfferStatus.cancelled;
      case 'pending':
      default:
        return OfferStatus.pending;
    }
  }

  static String _statusToString(OfferStatus status) {
    switch (status) {
      case OfferStatus.accepted:
        return 'accepted';
      case OfferStatus.rejected:
        return 'rejected';
      case OfferStatus.expired:
        return 'expired';
      case OfferStatus.cancelled:
        return 'cancelled';
      case OfferStatus.pending:
      default:
        return 'pending';
    }
  }

  static OfferType _typeFromString(String type) {
    switch (type) {
      case 'counter_offer':
        return OfferType.counter_offer;
      case 'initial':
      default:
        return OfferType.initial;
    }
  }

  static String _typeToString(OfferType type) {
    switch (type) {
      case OfferType.counter_offer:
        return 'counter_offer';
      case OfferType.initial:
      default:
        return 'initial';
    }
  }

  // Método para crear una contraoferta basada en esta oferta
  FareOffer createCounterOffer({
    required String fromUserId,
    required String fromUserName,
    required double amount,
  }) {
    return FareOffer(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      fromUserId: fromUserId,
      fromUserName: fromUserName,
      toUserId: this.fromUserId, // Dirigida al creador de la oferta original
      amount: amount,
      routeData: this.routeData,
      timestamp: DateTime.now(),
      offerType: OfferType.counter_offer,
      parentOfferId: this.id,
    );
  }
}
