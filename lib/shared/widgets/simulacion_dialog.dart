import 'package:flutter/material.dart';

/// Pide duración de simulación en minutos (para pruebas rápidas).
Future<double?> pedirDuracionSimulacion(BuildContext context) async {
  final ctrl = TextEditingController(text: '2');
  return showDialog<double>(
    context: context,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return AlertDialog(
        title: const Text('Duración de simulación'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '¿En cuántos minutos debe llegar el técnico?',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Minutos',
                border: OutlineInputBorder(),
                suffixText: 'min',
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final m in [1, 2, 5, 10])
                  ActionChip(
                    label: Text('$m min'),
                    onPressed: () {
                      ctrl.text = '$m';
                    },
                  ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(ctrl.text.replaceAll(',', '.'));
              if (v == null || v <= 0 || v > 120) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Ingrese entre 1 y 120 minutos')),
                );
                return;
              }
              Navigator.pop(ctx, v);
            },
            child: const Text('Iniciar'),
          ),
        ],
      );
    },
  );
}
