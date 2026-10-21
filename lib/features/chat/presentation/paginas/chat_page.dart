import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/tokens.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/realtime/canal_tiempo_real.dart';
import '../../../../core/realtime/mensaje_tiempo_real.dart';
import '../../../../core/session/controlador_sesion.dart';
import '../../../../core/utils/fechas.dart';
import '../../../../shared/widgets/vista_error.dart';
import '../../data/repositorio_chat.dart';
import '../../domain/mensaje_chat.dart';

/// Chat de la solicitud entre el cliente y el técnico asignado (RF-37,
/// SCRUM-482, ADR-026). Contrato: `GET` y `POST
/// /v1/service-requests/{id}/messages` (communication 1.3.0) y la trama
/// `chat.message` del canal `/v1/realtime` (1.1.0).
///
/// El historial llega por REST; los mensajes nuevos del otro participante
/// llegan completos por el canal y se agregan sin volver a pedirlo. Si el
/// canal no está conectado, la pantalla consulta la primera página cada 30 s
/// (RNF-06). Un aviso de cambio de estado vuelve a pedirla para saber si el
/// chat sigue abierto: al completar, pagar o cancelar queda de solo lectura
/// (RN-CH2).
class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({required this.solicitudId, super.key});

  final String solicitudId;

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _texto = TextEditingController();

  /// Del más reciente al más antiguo, sin repetidos (la trama y el historial
  /// pueden traer el mismo mensaje).
  final _mensajes = <String, MensajeChat>{};
  List<MensajeChat> _ordenados = const [];

  CanalTiempoReal? _canal;
  StreamSubscription<MensajeTiempoReal>? _avisos;
  Timer? _respaldo;

  Object? _error;
  bool _cargando = true;
  bool _cargandoAnteriores = false;
  bool _enviando = false;
  bool _escribible = false;
  int _pagina = 1;
  bool _hayMas = false;

  RepositorioChat get _repositorio => ref.read(repositorioChatProvider);

  @override
  void initState() {
    super.initState();
    unawaited(_cargar());
    _respaldo = Timer.periodic(MensajeTiempoReal.intervaloRespaldo, (_) {
      if (_canal?.estado.value != EstadoCanal.conectado) unawaited(_cargar());
    });
  }

  /// Primera página: la del inicio, la del respaldo y la de un cambio de
  /// estado. Conserva los mensajes anteriores que ya se habían cargado.
  Future<void> _cargar() async {
    try {
      final pagina = await _repositorio.listar(widget.solicitudId);
      if (!mounted) return;
      setState(() {
        _agregar(pagina.mensajes);
        _escribible = pagina.escribible;
        if (_pagina == 1) _hayMas = pagina.hayMas;
        _error = null;
        _cargando = false;
      });
    } on Object catch (e) {
      if (!mounted) return;
      // Con mensajes en pantalla, un fallo del respaldo no la tapa.
      setState(() {
        if (_mensajes.isEmpty) _error = e;
        _cargando = false;
      });
    }
  }

  Future<void> _cargarAnteriores() async {
    setState(() => _cargandoAnteriores = true);
    try {
      final pagina = await _repositorio.listar(
        widget.solicitudId,
        pagina: _pagina + 1,
      );
      if (!mounted) return;
      setState(() {
        _pagina = pagina.pagina;
        _hayMas = pagina.hayMas;
        _agregar(pagina.mensajes);
      });
    } on AppException catch (e) {
      _avisar(e.mensaje);
    } finally {
      if (mounted) setState(() => _cargandoAnteriores = false);
    }
  }

  void _agregar(Iterable<MensajeChat> nuevos) {
    for (final m in nuevos) {
      _mensajes[m.id] = m;
    }
    _ordenados = _mensajes.values.toList()
      ..sort((a, b) {
        final porHora = b.enviadoEn.compareTo(a.enviadoEn);
        return porHora != 0 ? porHora : b.id.compareTo(a.id);
      });
  }

  /// Se suscribe al canal actual; cambia si la sesión crea uno nuevo.
  void _escuchar(CanalTiempoReal canal) {
    if (identical(canal, _canal)) return;
    unawaited(_avisos?.cancel());
    _canal = canal;
    _avisos = canal.avisos.listen((m) {
      if (m.esChatDe(widget.solicitudId)) {
        final mensaje = MensajeChat.intentar(m.mensajeChat!);
        if (mensaje != null && mounted) setState(() => _agregar([mensaje]));
      } else if (m.cambiaSolicitud(widget.solicitudId)) {
        unawaited(_cargar());
      }
    });
  }

  Future<void> _enviar() async {
    final texto = _texto.text.trim();
    if (texto.isEmpty || _enviando) return;
    setState(() => _enviando = true);
    try {
      final mensaje = await _repositorio.enviar(widget.solicitudId, texto);
      if (!mounted) return;
      _texto.clear();
      setState(() => _agregar([mensaje]));
    } on AppException catch (e) {
      if (!mounted) return;
      if (e.esProblema('chat-cerrado')) {
        setState(() => _escribible = false);
        _avisar('La solicitud terminó: el chat quedó de solo lectura.');
      } else if (e.esProblema('chat-no-disponible')) {
        setState(() => _escribible = false);
        _avisar('La solicitud no tiene un técnico asignado en este momento.');
      } else {
        // El texto se conserva para reintentar.
        _avisar(e.errorDe('text') ?? e.mensaje);
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  void _avisar(String texto) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  @override
  void dispose() {
    _respaldo?.cancel();
    unawaited(_avisos?.cancel());
    _texto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _escuchar(ref.watch(canalTiempoRealProvider));
    final yo = ref.watch(controladorSesionProvider).value?.usuario.userId;

    return Scaffold(
      appBar: AppBar(title: const Text('Chat del servicio')),
      body: SafeArea(
        child: _cargando
            ? const IndicadorCarga(etiqueta: 'Cargando el chat')
            : _error != null
            ? Center(
                child: SingleChildScrollView(
                  child: VistaError(
                    key: const Key('chat-error'),
                    error: _error!,
                    titulo: 'No pudimos abrir el chat',
                    alReintentar: () {
                      setState(() => _cargando = true);
                      unawaited(_cargar());
                    },
                  ),
                ),
              )
            : Column(
                children: [
                  Expanded(child: _conversacion(yo)),
                  if (_escribible) _redactor() else const _SoloLectura(),
                ],
              ),
      ),
    );
  }

  Widget _conversacion(String? yo) {
    if (_ordenados.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(QpEspacio.e6),
          child: Text(
            _escribible
                ? 'Aún no hay mensajes. Escribe para coordinar el servicio.'
                : 'No hubo mensajes en este servicio.',
            key: const Key('chat-vacio'),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final anteriores = _hayMas ? 1 : 0;
    return ListView.builder(
      key: const Key('chat-mensajes'),
      // El más reciente queda abajo, junto al campo de texto.
      reverse: true,
      padding: const EdgeInsets.all(QpEspacio.pantalla),
      itemCount: _ordenados.length + anteriores,
      itemBuilder: (context, i) {
        if (i == _ordenados.length) {
          return Center(
            child: TextButton(
              key: const Key('chat-anteriores'),
              onPressed: _cargandoAnteriores ? null : _cargarAnteriores,
              child: const Text('Ver mensajes anteriores'),
            ),
          );
        }
        final m = _ordenados[i];
        return _Burbuja(m, propio: m.autorId == yo);
      },
    );
  }

  Widget _redactor() => Padding(
    padding: const EdgeInsets.fromLTRB(
      QpEspacio.pantalla,
      QpEspacio.e2,
      QpEspacio.e2,
      QpEspacio.e2,
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextField(
            key: const Key('chat-texto'),
            controller: _texto,
            minLines: 1,
            maxLines: 4,
            maxLength: LimitesChat.longitudMaxima,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Escribe un mensaje',
              counterText: '',
            ),
            onSubmitted: (_) => _enviar(),
          ),
        ),
        const SizedBox(width: QpEspacio.e2),
        IconButton.filled(
          key: const Key('chat-enviar'),
          tooltip: 'Enviar',
          onPressed: _enviando ? null : _enviar,
          icon: const Icon(Icons.send_rounded),
        ),
      ],
    ),
  );
}

class _Burbuja extends StatelessWidget {
  const _Burbuja(this.mensaje, {required this.propio});

  final MensajeChat mensaje;
  final bool propio;

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    final fondo = propio ? colores.primary : colores.surfaceContainerHighest;
    final texto = propio ? colores.onPrimary : colores.onSurface;
    final autor = propio
        ? 'Tú'
        : mensaje.rolAutor == 'tecnico'
        ? 'Técnico'
        : 'Cliente';
    return Align(
      alignment: propio ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        child: Semantics(
          label: '$autor, ${fechaCorta(mensaje.enviadoEn.toLocal())}',
          child: Container(
            key: Key('mensaje-${mensaje.id}'),
            margin: const EdgeInsets.symmetric(vertical: QpEspacio.e1),
            padding: const EdgeInsets.symmetric(
              horizontal: QpEspacio.e3,
              vertical: QpEspacio.e2,
            ),
            decoration: BoxDecoration(
              color: fondo,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(mensaje.texto, style: TextStyle(color: texto)),
                const SizedBox(height: QpEspacio.e1),
                Text(
                  fechaCorta(mensaje.enviadoEn.toLocal()),
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: texto),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// En `completado`, `pagado` o `cancelado`, o sin técnico asignado, el
/// historial se lee pero no se escribe (RN-CH2).
class _SoloLectura extends StatelessWidget {
  const _SoloLectura();

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('chat-solo-lectura'),
    width: double.infinity,
    padding: const EdgeInsets.all(QpEspacio.e4),
    color: Theme.of(context).colorScheme.surfaceContainerHigh,
    child: const Text(
      'El chat está cerrado: puedes leer los mensajes, pero ya no escribir.',
      textAlign: TextAlign.center,
    ),
  );
}
