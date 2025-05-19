// lib/widgets/counter_offer_dialog.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/fare_offer.dart';
import '../providers/negotiation_provider.dart';

class CounterOfferDialog extends StatefulWidget {
  final FareOffer originalOffer;
  final Function(double) onSubmit;

  const CounterOfferDialog({
    super.key,
    required this.originalOffer,
    required this.onSubmit,
  });

  @override
  State<CounterOfferDialog> createState() => _CounterOfferDialogState();
}

class _CounterOfferDialogState extends State<CounterOfferDialog> {
  late TextEditingController _amountController;
  late double _suggestedAmount;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Iniciar con el valor de la oferta original
    _suggestedAmount = widget.originalOffer.amount;
    _amountController = TextEditingController(
      text: _suggestedAmount.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _validateAmount() {
    final negotiationProvider = Provider.of<NegotiationProvider>(
      context,
      listen: false,
    );

    try {
      final double amount = double.parse(_amountController.text);

      if (amount <= 0) {
        setState(() {
          _errorMessage = 'El monto debe ser mayor a 0';
        });
        return;
      }

      if (!negotiationProvider.isValidCounterOffer(
        amount,
        widget.originalOffer,
      )) {
        setState(() {
          final minAmount = (negotiationProvider.baseOffer * 0.7)
              .toStringAsFixed(2);
          final maxAmount = (negotiationProvider.baseOffer * 2.0)
              .toStringAsFixed(2);
          _errorMessage =
              'Monto inválido. Debe estar entre S/ $minAmount y S/ $maxAmount';
        });
        return;
      }

      setState(() {
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Ingresa un número válido';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Hacer Contraoferta'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Oferta recibida: S/ ${widget.originalOffer.amount.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Distancia: ${((widget.originalOffer.routeData['distance'] as num) / 1000).toStringAsFixed(2)} km',
          ),
          const SizedBox(height: 16),
          const Text('Ingresa tu contraoferta:'),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Monto (S/)',
              prefixText: 'S/ ',
              errorText: _errorMessage,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => _validateAmount(),
          ),
          const SizedBox(height: 8),
          const Text(
            'La contraoferta será enviada al pasajero y podrá aceptarla o rechazarla.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCELAR'),
        ),
        ElevatedButton(
          onPressed: () {
            _validateAmount();
            if (_errorMessage == null) {
              final amount = double.parse(_amountController.text);
              widget.onSubmit(amount);
              Navigator.pop(context);
            }
          },
          child: const Text('ENVIAR CONTRAOFERTA'),
        ),
      ],
    );
  }
}
