import 'package:flutter_test/flutter_test.dart';
import 'package:quickpatch_mobile/features/autenticacion/domain/enlace_invitacion.dart';

/// SCRUM-98: token de la invitación desde el enlace que comparte el proveedor.
void main() {
  // 43 caracteres base64url, como el token del contrato (256 bits).
  const token = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJ012-_56';

  test('lee el token del enlace de Identity (después de #)', () {
    expect(
      tokenDeInvitacion('https://quickpatch.internal/activar#token=$token'),
      token,
    );
    expect(
      tokenDeInvitacion('https://qa.quickpatch.internal/activar#token=$token'),
      token,
    );
  });

  test('acepta espacios alrededor, el token solo o en la consulta', () {
    expect(tokenDeInvitacion('  $token\n'), token);
    expect(
      tokenDeInvitacion('https://quickpatch.internal/activar?token=$token'),
      token,
    );
    expect(tokenDeInvitacion('/activar#token=$token'), token);
  });

  test('rechaza enlaces sin token o con un token que no es del contrato', () {
    expect(tokenDeInvitacion(''), isNull);
    expect(tokenDeInvitacion('https://quickpatch.internal/activar'), isNull);
    expect(
      tokenDeInvitacion('https://quickpatch.internal/activar#token=corto'),
      isNull,
    );
    expect(tokenDeInvitacion('${token}x'), isNull);
    expect(
      tokenDeInvitacion(
        'https://quickpatch.internal/activar#token=${token.replaceFirst('a', '+')}',
      ),
      isNull,
    );
    expect(tokenDeInvitacion('hola, te mando el enlace'), isNull);
    expect(tokenDeInvitacion('https://x/activar#%zz'), isNull);
  });
}
