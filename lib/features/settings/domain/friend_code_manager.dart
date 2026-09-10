import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../friends/data/friends_service.dart';
import '../../friends/domain/models/profile_model.dart';

/// Gestor del código de amigo autogenerado con expiración de 1 minuto y sincronización en Supabase
class FriendCodeManager extends ChangeNotifier {
  static const int codeValiditySeconds = 60;

  final IFriendsService? friendsService;
  String? userId;

  Timer? _timer;
  String? _currentCode;
  int _remainingSeconds = 0;
  bool _isExpired = false;
  final List<String> _addedFriends = [];

  FriendCodeManager({this.friendsService, this.userId});

  void setUserId(String? newUserId) {
    userId = newUserId;
  }

  String? get currentCode => _currentCode;
  int get remainingSeconds => _remainingSeconds;
  double get progress => _currentCode != null && _remainingSeconds > 0
      ? _remainingSeconds / codeValiditySeconds
      : 0.0;
  bool get hasActiveCode => _currentCode != null && !_isExpired;
  bool get isExpired => _isExpired;
  List<String> get addedFriends => List.unmodifiable(_addedFriends);

  /// Sincroniza la lista de amigos con los nombres de usuario ya existentes
  void syncFriends(List<String> usernames) {
    for (final name in usernames) {
      if (!_addedFriends.contains(name)) {
        _addedFriends.add(name);
      }
    }
    notifyListeners();
  }

  /// Genera un nuevo código único, lo sincroniza con Supabase si está disponible
  /// y activa el temporizador de 1 minuto (60 segundos)
  Future<String> generateNewCode({String? userId, IFriendsService? service}) async {
    _timer?.cancel();

    // Generar código aleatorio en formato MARTH-XXXX (letras mayúsculas y dígitos)
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random();
    final randomPart =
        List.generate(4, (_) => chars[random.nextInt(chars.length)]).join();

    final generated = 'MARTH-$randomPart';
    _currentCode = generated;
    _remainingSeconds = codeValiditySeconds;
    _isExpired = false;
    notifyListeners();

    // Sincronizar con Supabase en la tabla friend_codes con expiración de 60s
    final activeService = service ?? friendsService;
    final activeUserId = userId ?? this.userId;
    if (activeService != null && activeUserId != null) {
      try {
        await activeService.saveFriendCode(
          activeUserId,
          generated,
          durationSeconds: codeValiditySeconds,
        );
      } catch (e) {
        debugPrint('[FriendCodeManager] Advertencia al sincronizar código con Supabase: $e');
      }
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 1) {
        _remainingSeconds--;
        notifyListeners();
      } else {
        // Al transcurrir 1 minuto, el código se elimina automáticamente
        _remainingSeconds = 0;
        _isExpired = true;
        _currentCode = null;
        timer.cancel();
        notifyListeners();
      }
    });

    return generated;
  }

  /// Canjea un código de amigo, valida la caducidad (60s) en Supabase,
  /// envía la invitación en tiempo real y guarda el nombre de usuario real del amigo
  Future<bool> addFriend(
    String code, {
    String? currentUserId,
    IFriendsService? service,
  }) async {
    final cleanCode = code.trim().toUpperCase();
    if (cleanCode.isEmpty) return false;

    final activeService = service ?? friendsService;
    final activeUserId = currentUserId ?? userId ?? '';

    if (activeService != null) {
      // Canjear en Supabase: valida 60s, crea friend_request y obtiene el perfil real
      final ProfileModel friendProfile =
          await activeService.redeemFriendCode(activeUserId, cleanCode);

      final friendUsername = friendProfile.username;
      if (_addedFriends.contains(friendUsername)) {
        throw Exception('El usuario @$friendUsername ya ha sido añadido.');
      }

      _addedFriends.add(friendUsername);
      notifyListeners();
      return true;
    }

    // Modo offline/fallback: validación básica de formato para tests
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
