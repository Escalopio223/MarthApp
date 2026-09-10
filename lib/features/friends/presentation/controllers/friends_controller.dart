import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/friends_service.dart';
import '../../domain/models/friend_request_model.dart';
import '../../domain/models/profile_model.dart';

/// Controlador reactivo del sistema de amigos y perfil de usuario con Supabase Realtime
class FriendsController extends ChangeNotifier {
  final IFriendsService _friendsService;

  ProfileModel? _currentProfile;
  List<FriendRequestModel> _incomingRequests = [];
  List<ProfileModel> _friends = [];

  bool _isLoading = false;
  bool _isUpdatingUsername = false;
  bool _isSendingRequest = false;
  String? _errorMessage;
  String? _successMessage;

  String? _currentUserId;
  RealtimeChannel? _friendRequestsChannel;
  RealtimeChannel? _profilesChannel;

  FriendsController({IFriendsService? friendsService})
      : _friendsService = friendsService ?? FriendsService();

  // Getters
  ProfileModel? get currentProfile => _currentProfile;
  List<FriendRequestModel> get incomingRequests => _incomingRequests;
  List<ProfileModel> get friends => _friends;
  int get pendingCount => _incomingRequests.length;
  bool get isLoading => _isLoading;
  bool get isUpdatingUsername => _isUpdatingUsername;
  bool get isSendingRequest => _isSendingRequest;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  /// Inicializa los datos del usuario y activa las suscripciones en tiempo real
  Future<void> initialize(String userId, {String? defaultEmail}) async {
    _currentUserId = userId;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Cargar perfil inicial
      _currentProfile = await _friendsService.getMyProfile(userId, defaultEmail: defaultEmail);

      // 2. Cargar solicitudes pendientes y lista de amigos
      await _loadAllData(userId);

      // 3. Suscribirse a canales en tiempo real
      _setupRealtimeSubscriptions(userId);
    } catch (e) {
      _errorMessage = 'Error al cargar datos de amigos: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadAllData(String userId) async {
    final results = await Future.wait([
      _friendsService.fetchPendingIncomingRequests(userId),
      _friendsService.fetchFriends(userId),
    ]);

    _incomingRequests = results[0] as List<FriendRequestModel>;
    _friends = results[1] as List<ProfileModel>;
  }

  /// Configura las escuchas en tiempo real para solicitudes y perfiles
  void _setupRealtimeSubscriptions(String userId) {
    // Canal de solicitudes de amistad (INSERT, UPDATE, DELETE)
    _friendRequestsChannel = _friendsService.subscribeToFriendRequests(
      userId: userId,
      onEvent: (record, eventType) async {
        final senderId = record['sender_id'] as String?;
        final receiverId = record['receiver_id'] as String?;
        final status = record['status'] as String?;

        if (eventType == 'INSERT') {
          // Si somos el receptor de una nueva solicitud entrante
          if (receiverId == userId && status == 'pending') {
            final id = record['id'] as String?;
            if (id != null && !_incomingRequests.any((r) => r.id == id)) {
              // Buscar información del emisor para mostrar su nombre de inmediato
              final senderProfile = senderId != null
                  ? await _friendsService.getMyProfile(senderId)
                  : null;
              _incomingRequests.insert(
                0,
                FriendRequestModel.fromJson(record, senderProfile: senderProfile),
              );
              notifyListeners();
            }
          }
        } else if (eventType == 'UPDATE') {
          // Si una solicitud cambió a 'accepted'
          if (status == 'accepted') {
            // Remover de pendientes si estaba ahí
            _incomingRequests.removeWhere((r) => r.id == record['id']);
            // Recargar lista de amigos para mostrar inmediatamente al nuevo amigo
            _friends = await _friendsService.fetchFriends(userId);
            notifyListeners();
          } else if (status == 'rejected') {
            _incomingRequests.removeWhere((r) => r.id == record['id']);
            notifyListeners();
          }
        } else if (eventType == 'DELETE') {
          _incomingRequests.removeWhere((r) => r.id == record['id']);
          _friends = await _friendsService.fetchFriends(userId);
          notifyListeners();
        }
      },
    );

    // Canal de perfiles: Actualización instantánea sin parpadeo si un amigo cambia su nombre
    _profilesChannel = _friendsService.subscribeToProfiles(
      onProfileUpdated: (updatedProfile) {
        // 1. Si es nuestro propio perfil
        if (_currentProfile?.id == updatedProfile.id) {
          _currentProfile = updatedProfile;
          notifyListeners();
        }

        // 2. Si es uno de nuestros amigos
        final index = _friends.indexWhere((f) => f.id == updatedProfile.id);
        if (index != -1) {
          _friends[index] = updatedProfile;
          notifyListeners();
        }

        // 3. Si es un emisor en solicitudes pendientes
        for (int i = 0; i < _incomingRequests.length; i++) {
          if (_incomingRequests[i].senderId == updatedProfile.id) {
            _incomingRequests[i] = _incomingRequests[i].copyWith(
              senderProfile: updatedProfile,
            );
            notifyListeners();
          }
        }
      },
    );
  }

  /// Actualiza el nombre de usuario del perfil propio con validación y manejo de colisiones
  Future<bool> updateUsername(String newUsername) async {
    if (_currentUserId == null) return false;

    _isUpdatingUsername = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final updated = await _friendsService.updateUsername(_currentUserId!, newUsername);
      _currentProfile = updated;
      _successMessage = 'Nombre de usuario cambiado a "$newUsername"';
      _isUpdatingUsername = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isUpdatingUsername = false;
      notifyListeners();
      return false;
    }
  }

  IFriendsService get friendsService => _friendsService;
  String? get currentUserId => _currentUserId;

  /// Envía una solicitud de amistad por username o canjea un código de amigo MARTH-XXXX
  Future<bool> sendFriendRequest(String targetUsernameOrCode) async {
    if (_currentUserId == null) return false;

    _isSendingRequest = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final req = await _friendsService.sendFriendRequest(_currentUserId!, targetUsernameOrCode);
      final recipientName = req.receiverProfile?.username ?? targetUsernameOrCode;
      _successMessage = '¡Invitación enviada con éxito a @$recipientName!';
      _isSendingRequest = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isSendingRequest = false;
      notifyListeners();
      return false;
    }
  }

  /// Canjea un código de amigo temporal (60s), crea la invitación y resuelve el perfil real
  Future<bool> redeemFriendCode(String code) async {
    if (_currentUserId == null) return false;

    _isSendingRequest = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final friendProfile = await _friendsService.redeemFriendCode(_currentUserId!, code);
      _successMessage = '¡Invitación enviada a @${friendProfile.username}!';
      if (_currentUserId != null) {
        _friends = await _friendsService.fetchFriends(_currentUserId!);
      }
      _isSendingRequest = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isSendingRequest = false;
      notifyListeners();
      return false;
    }
  }

  /// Acepta una solicitud de amistad entrante
  Future<void> acceptRequest(String requestId) async {
    try {
      await _friendsService.acceptFriendRequest(requestId);
      _incomingRequests.removeWhere((r) => r.id == requestId);
      if (_currentUserId != null) {
        _friends = await _friendsService.fetchFriends(_currentUserId!);
      }
      _successMessage = '¡Solicitud de amistad aceptada!';
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error al aceptar solicitud: $e';
      notifyListeners();
    }
  }

  /// Rechaza una solicitud de amistad entrante
  Future<void> rejectRequest(String requestId) async {
    try {
      await _friendsService.rejectFriendRequest(requestId);
      _incomingRequests.removeWhere((r) => r.id == requestId);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error al rechazar solicitud: $e';
      notifyListeners();
    }
  }

  /// Elimina una amistad existente
  Future<void> removeFriend(String friendId) async {
    if (_currentUserId == null) return;
    try {
      // Remover optimista
      _friends.removeWhere((f) => f.id == friendId);
      notifyListeners();
      _friends = await _friendsService.fetchFriends(_currentUserId!);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error al eliminar amigo: $e';
      notifyListeners();
    }
  }

  /// Limpia los mensajes temporales de error y éxito
  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  /// Recarga manual opcional
  Future<void> refresh() async {
    if (_currentUserId != null) {
      await _loadAllData(_currentUserId!);
      notifyListeners();
    }
  }

  bool _isDisposed = false;

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    // Cancelar y limpiar rigurosamente todos los canales en tiempo real para evitar fugas de memoria
    _friendsService.unsubscribe(_friendRequestsChannel);
    _friendsService.unsubscribe(_profilesChannel);
    _friendRequestsChannel = null;
    _profilesChannel = null;
    super.dispose();
  }
}
