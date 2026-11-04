import 'package:flutter/material.dart';

/// Campana del buzón con el número de notificaciones sin leer (SCRUM-459).
/// Recibe el número y la acción: no sabe de dónde salen.
class CampanaNotificaciones extends StatelessWidget {
  const CampanaNotificaciones({
    super.key,
    required this.sinLeer,
    required this.alTocar,
  });

  final int sinLeer;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final etiqueta = switch (sinLeer) {
      0 => 'Notificaciones',
      1 => 'Notificaciones, 1 sin leer',
      _ => 'Notificaciones, $sinLeer sin leer',
    };
    return IconButton(
      key: const Key('campana-notificaciones'),
      tooltip: etiqueta,
      onPressed: alTocar,
      icon: Badge(
        isLabelVisible: sinLeer > 0,
        label: Text(sinLeer > 9 ? '9+' : '$sinLeer'),
        child: Icon(
          sinLeer > 0
              ? Icons.notifications_rounded
              : Icons.notifications_none_rounded,
        ),
      ),
    );
  }
}
