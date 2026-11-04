import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Hora actual. Las pruebas lo reemplazan para avanzar el tiempo, por
/// ejemplo en la cuenta regresiva de una oferta.
final relojProvider = Provider<DateTime Function()>((ref) => DateTime.now);
