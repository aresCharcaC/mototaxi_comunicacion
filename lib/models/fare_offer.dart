// Archivo: lib/models/fare_offer.dart

enum OfferStatus { pending, accepted, rejected, expired, cancelled }

class FareOffer {
  final String id;
  final String fromUserId;
  final String fromUserName;
  final String toUserId;
  final double amount;
  final Map<String, dynamic> routeData;
  final DateTime timestamp;
  OfferStatus status;

  FareOffer({
    required this.id,
    required this.fromUserId,
    required this.fromUserName,
    required this.toUserId,
    required this.amount,
    required this.routeData,
    required this.timestamp,
    this.status = OfferStatus.pending,
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
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': 'fare_offer',
      'fromUserId': fromUserId,
      'fromUserName': fromUserName,
      'toUserId': toUserId,
      'amount': amount,
      'routeData': routeData,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'status': _statusToString(status),
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
      case OfferStatus.pending:
      default:
        return 'pending';
    }
  }
}
