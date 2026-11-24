import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Revisión de una solicitud en la app: sube cada vez que algo la cambia (un
/// aviso en tiempo real, un pago, la calificación). Los providers de las
/// features que leen datos de esa solicitud (`solicitudProvider`,
/// `pagoProvider`) la observan y se vuelven a pedir solos, así ninguna feature
/// invalida los providers de otra (features/README.md, SCRUM-714).
final revisionSolicitudProvider = NotifierProvider.autoDispose
    .family<RevisionSolicitud, int, String>(RevisionSolicitud.new);

class RevisionSolicitud extends Notifier<int> {
  RevisionSolicitud(this.solicitudId);

  final String solicitudId;

  @override
  int build() => 0;

  void subir() => state++;
}

/// Avisa que la solicitud cambió y hay que volver a pedir lo que depende de ella.
void solicitudCambio(WidgetRef ref, String solicitudId) =>
    ref.read(revisionSolicitudProvider(solicitudId).notifier).subir();
