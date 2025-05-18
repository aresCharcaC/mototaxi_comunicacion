// Archivo: lib/utils/format_utils.dart

class FormatUtils {
  /// Formatea una distancia en metros a un formato legible
  static String formatDistance(double distanceInMeters) {
    if (distanceInMeters < 1000) {
      return '${distanceInMeters.round()} m';
    } else {
      return '${(distanceInMeters / 1000).toStringAsFixed(1)} km';
    }
  }

  /// Formatea una duración en segundos a un formato legible
  static String formatDuration(int durationInSeconds) {
    if (durationInSeconds < 60) {
      return '$durationInSeconds seg';
    } else if (durationInSeconds < 3600) {
      final minutes = durationInSeconds ~/ 60;
      return '$minutes min';
    } else {
      final hours = durationInSeconds ~/ 3600;
      final minutes = (durationInSeconds % 3600) ~/ 60;
      return '$hours h $minutes min';
    }
  }

  /// Formatea el precio a un formato de moneda (S/)
  static String formatCurrency(double amount) {
    return 'S/ ${amount.toStringAsFixed(2)}';
  }
}
