import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

/// Gestor del código de amigo autogenerado con expiración de 1 minuto
class FriendCodeManager extends ChangeNotifier {
  static const int codeValiditySeconds = 60;

  Timer? _timer;
  String? _currentCode;
  int _remainingSeconds = 0;
  bool _isExpired = false;
  final List<String> _addedFriends = [];

  String? get currentCode => _currentCode;
  int get remainingSeconds => _remainingSeconds;
  double get progress => _currentCode != null && _remainingSeconds > 0
      ? _remainingSeconds / codeValiditySeconds
      : 0.0;
  bool get hasActiveCode => _currentCode != null && !_isExpired;
  bool get isExpired => _isExpired;
  List<String> get addedFriends => List.unmodifiable(_addedFriends);

  /// Genera un nuevo código único y activa el temporizador de 1 minuto
  void generateNewCode() {
    _timer?.cancel();

    // Generar código aleatorio en formato MARTH-XXXX (letras mayúsculas y dígitos)
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random();
    final randomPart =
        List.generate(4, (_) => chars[random.nextInt(chars.length)]).join();

    _currentCode = 'MARTH-$randomPart';
    _remainingSeconds = codeValiditySeconds;
    _isExpired = false;
    notifyListeners();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 1) {
        _remainingSeconds--;
        notifyListeners();
      } else {
        // Al transcurrir 1 minuto, el código se elimina
        _remainingSeconds = 0;
        _isExpired = true;
        _currentCode = null; // Se elimina el código
        timer.cancel();
        notifyListeners();
      }
    });
  }

  /// Añade un amigo a través de su código
  Future<bool> addFriend(String code) async {
    final cleanCode = code.trim().toUpperCase();
    if (cleanCode.isEmpty) return false;

    // Validación básica de formato
    if (_addedFriends.contains(cleanCode)) {
      throw Exception('Este amigo ya ha sido añadido.');
    }

    _addedFriends.add(cleanCode);
    notifyListeners();
    return true;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
