// Archivo: lib/widgets/fare_adjustment_slider.dart

import 'package:flutter/material.dart';

class FareAdjustmentSlider extends StatefulWidget {
  final double initialValue;
  final double minValue;
  final double maxValue;
  final Function(double) onChanged;

  const FareAdjustmentSlider({
    super.key,
    required this.initialValue,
    required this.minValue,
    required this.maxValue,
    required this.onChanged,
  });

  @override
  State<FareAdjustmentSlider> createState() => _FareAdjustmentSliderState();
}

class _FareAdjustmentSliderState extends State<FareAdjustmentSlider> {
  late double _currentValue;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'S/ ${widget.minValue.toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.grey),
            ),
            Text(
              'S/ ${_currentValue.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Colors.deepOrange,
              ),
            ),
            Text(
              'S/ ${widget.maxValue.toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: Colors.deepOrange,
            inactiveTrackColor: Colors.orange.shade100,
            thumbColor: Colors.orange,
            overlayColor: Colors.orange.withOpacity(0.3),
          ),
          child: Slider(
            value: _currentValue,
            min: widget.minValue,
            max: widget.maxValue,
            divisions: ((widget.maxValue - widget.minValue) * 2).round(),
            onChanged: (value) {
              setState(() {
                _currentValue = (value * 2).round() / 2; // Redondear a 0.5
              });
              widget.onChanged(_currentValue);
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Tarifa más baja',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const Text(
              'Tarifa más alta',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ],
    );
  }
}
