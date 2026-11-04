import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quickpatch_mobile/features/solicitudes/data/selector_fotos.dart';

import '../../helpers/evidencias.dart';

class _ImagePickerFalso extends Mock implements ImagePicker {}

/// La foto se reduce antes de subirla para quedar lejos de los 10 MB
/// (service-request 1.7.0).
void main() {
  setUpAll(() => registerFallbackValue(ImageSource.gallery));

  late _ImagePickerFalso picker;

  setUp(() => picker = _ImagePickerFalso());

  void responder(XFile? archivo) => when(
    () => picker.pickImage(
      source: any(named: 'source'),
      maxWidth: any(named: 'maxWidth'),
      maxHeight: any(named: 'maxHeight'),
      imageQuality: any(named: 'imageQuality'),
    ),
  ).thenAnswer((_) async => archivo);

  test('la cámara entrega la foto reducida con su nombre', () async {
    responder(XFile.fromData(pngMinimo, path: 'trabajo.jpg'));

    final foto = await SelectorFotosSistema(picker).elegir(OrigenFoto.camara);

    expect(foto!.bytes, pngMinimo);
    expect(foto.nombre, 'trabajo.jpg');
    verify(
      () => picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 2560,
        maxHeight: 2560,
        imageQuality: 85,
      ),
    ).called(1);
  });

  test('si vuelve sin elegir de la galería devuelve null', () async {
    responder(null);

    expect(
      await SelectorFotosSistema(picker).elegir(OrigenFoto.galeria),
      isNull,
    );
    verify(
      () => picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: any(named: 'maxWidth'),
        maxHeight: any(named: 'maxHeight'),
        imageQuality: any(named: 'imageQuality'),
      ),
    ).called(1);
  });
}
