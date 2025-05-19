import 'package:flutter/material.dart';
import '../widgets/fare_adjustment_slider.dart';

class FareOfferPanel extends StatelessWidget {
  final double routeDistance;
  final double baseOffer;
  final double currentOffer;
  final Function(double) onOfferChanged;
  final VoidCallback onSendOffer;
  final VoidCallback onClearRoute;

  const FareOfferPanel({
    super.key,
    required this.routeDistance,
    required this.baseOffer,
    required this.currentOffer,
    required this.onOfferChanged,
    required this.onSendOffer,
    required this.onClearRoute,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
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
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: onClearRoute,
                  tooltip: 'Limpiar ruta',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Distancia: ${(routeDistance / 1000).toStringAsFixed(2)} km',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'Tarifa sugerida: S/ ${baseOffer.toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            FareAdjustmentSlider(
              initialValue: baseOffer,
              minValue: baseOffer * 0.7,
              maxValue: baseOffer * 1.5,
              onChanged: onOfferChanged,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onSendOffer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  'ENVIAR OFERTA DE S/ ${currentOffer.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
