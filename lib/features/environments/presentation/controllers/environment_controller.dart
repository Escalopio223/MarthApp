import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/environment_service.dart';
import '../../domain/models/environment_invitation_model.dart';
import '../../domain/models/environment_member_model.dart';
import '../../domain/models/environment_model.dart';
import '../../domain/repositories/i_environment_repository.dart';

/// Controlador reactivo para la gestión de entornos de trabajo (Workspaces)
/// Mantiene el entorno activo estrictamente en memoria volátil (sin persistencia local).
class EnvironmentController extends ChangeNotifier {
  final IEnvironmentRepository _environmentRepository;

  List<EnvironmentModel> _environments = [];
  EnvironmentModel? _activeEnvironment;
  bool _isAllSelected = false;
  List<EnvironmentInvitationModel> _pendingInvitations = [];

  bool _isLoading = false;
  bool _isActionLoading = false;
  String? _errorMessage;
  String? _successMessage;

  String? _currentUserId;
  RealtimeChannel? _invitationsChannel;

  EnvironmentController({IEnvironmentRepository? environmentRepository})
      : _environmentRepository = environmentRepository ?? EnvironmentService();

  IEnvironmentRepository get repository => _environmentRepository;

  // Getters de estado
  List<EnvironmentModel> get environments => List.unmodifiable(_environments);
  EnvironmentModel? get activeEnvironment => _activeEnvironment;
  bool get isAllSelected => _isAllSelected;

  EnvironmentModel? get personalEnvironment {
    try {
      return _environments.firstWhere((e) => e.isPersonal);
    } catch (_) {
      return _environments.isNotEmpty ? _environments.first : null;
    }
  }

  List<EnvironmentInvitationModel> get pendingInvitations =>
      List.unmodifiable(_pendingInvitations);
  int get pendingInvitationsCount => _pendingInvitations.length;

  bool get isLoading => _isLoading;
  bool get isActionLoading => _isActionLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  String? get currentUserId => _currentUserId;

  /// Inicializa los entornos del usuario y selecciona por defecto el entorno personal
  Future<void> initialize(String userId) async {
    _currentUserId = userId;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _loadEnvironments(userId);
      await _loadPendingInvitations(userId);
      _setupRealtimeSubscription(userId);
    } catch (e) {
      _errorMessage = 'Error al inicializar entornos: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadEnvironments(String userId) async {
    final list = await _environmentRepository.getEnvironments(userId);
    _environments = list;

    // Regla de negocio: Selección por defecto obligatoria de "Mi Espacio" (is_personal == true)
    EnvironmentModel? defaultPersonal;
    try {
      defaultPersonal = _environments.firstWhere((e) => e.isPersonal);
    } catch (_) {
      if (_environments.isNotEmpty) defaultPersonal = _environments.first;
    }

    _activeEnvironment = defaultPersonal;
    _isAllSelected = false;
  }

  Future<void> _loadPendingInvitations(String userId) async {
    _pendingInvitations =
        await _environmentRepository.getPendingInvitations(userId);
  }

  void _setupRealtimeSubscription(String userId) {
    _invitationsChannel = _environmentRepository.subscribeToInvitations(
      userId,
      () async {
        if (_currentUserId != null) {
          _pendingInvitations =
              await _environmentRepository.getPendingInvitations(_currentUserId!);
          notifyListeners();
        }
      },
    );
  }

  /// Selecciona un entorno específico o conmutador a "Todos"
  void selectEnvironment(EnvironmentModel? env) {
    if (env == null || env.isAll) {
      selectAllEnvironments();
      return;
    }
    _isAllSelected = false;
    _activeEnvironment = env;
    _errorMessage = null;
    notifyListeners();
  }

  /// Activa la vista combinada "Todos"
  void selectAllEnvironments() {
    _isAllSelected = true;
    _activeEnvironment = null;
    _errorMessage = null;
    notifyListeners();
  }

  /// Crea un nuevo entorno de forma atómica mediante RPC
  Future<bool> createEnvironment(String name) async {
    final clean = name.trim();
    if (clean.length < 3) {
      _errorMessage = 'El nombre debe tener al menos 3 caracteres';
      notifyListeners();
      return false;
    }

    _isActionLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final created = await _environmentRepository.createEnvironment(name: clean);
      if (created != null) {
        _environments.add(created);
        _activeEnvironment = created;
        _isAllSelected = false;
        _successMessage = 'Entorno "${created.name}" creado con éxito';
        return true;
      }
      _errorMessage = 'No se pudo crear el entorno';
      return false;
    } catch (e) {
      _errorMessage = 'Error al crear entorno: $e';
      return false;
    } finally {
      _isActionLoading = false;
      notifyListeners();
    }
  }

  /// Elimina un entorno mediante RPC (valida que no tenga miembros adicionales)
  Future<bool> deleteEnvironment(String environmentId) async {
    _isActionLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final ok = await _environmentRepository.deleteEnvironment(environmentId);
      if (ok) {
        _environments.removeWhere((e) => e.id == environmentId);
        if (_activeEnvironment?.id == environmentId) {
          _activeEnvironment = personalEnvironment;
          _isAllSelected = false;
        }
        _successMessage = 'Entorno eliminado correctamente';
        return true;
      }
      _errorMessage = 'No se pudo eliminar el entorno';
      return false;
    } catch (e) {
      _errorMessage = 'Error al eliminar entorno: $e';
      return false;
    } finally {
      _isActionLoading = false;
      notifyListeners();
    }
  }

  /// Envía una invitación a un amigo para unirse a un entorno
  Future<bool> inviteFriend({
    required String environmentId,
    required String friendId,
  }) async {
    if (_currentUserId == null) return false;

    // Validación de negocio: No se admiten invitaciones a espacios personales
    final targetEnv = _environments.where((e) => e.id == environmentId).firstOrNull;
    if (targetEnv != null && targetEnv.isPersonal) {
      _errorMessage = 'El espacio personal es privado y no permite miembros';
      notifyListeners();
      return false;
    }

    _isActionLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final ok = await _environmentRepository.sendInvitation(
        environmentId: environmentId,
        receiverId: friendId,
        senderId: _currentUserId!,
      );
      if (ok) {
        _successMessage = 'Invitación enviada con éxito';
        return true;
      }
      _errorMessage = 'No se pudo enviar la invitación';
      return false;
    } catch (e) {
      _errorMessage = 'Error al invitar al amigo: $e';
      return false;
    } finally {
      _isActionLoading = false;
      notifyListeners();
    }
  }

  /// Obtiene los IDs de usuarios con invitación pendiente para este entorno
  Future<List<String>> getPendingInvitedUserIds(String environmentId) async {
    return _environmentRepository.getPendingInvitedUserIds(environmentId);
  }

  /// Acepta o rechaza una invitación entrante a un entorno
  Future<bool> respondInvitation({
    required String invitationId,
    required bool accept,
  }) async {
    _isActionLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final ok = await _environmentRepository.respondInvitation(
        invitationId: invitationId,
        accept: accept,
      );

      if (ok) {
        _pendingInvitations.removeWhere((i) => i.id == invitationId);
        if (accept && _currentUserId != null) {
          // Refrescar lista de entornos tras unirse
          final list = await _environmentRepository.getEnvironments(_currentUserId!);
          _environments = list;
        }
        _successMessage = accept ? '¡Te has unido al entorno!' : 'Invitación rechazada';
        return true;
      }
      _errorMessage = 'No se pudo procesar la invitación';
      return false;
    } catch (e) {
      _errorMessage = 'Error al responder invitación: $e';
      return false;
    } finally {
      _isActionLoading = false;
      notifyListeners();
    }
  }

  /// Migra de forma atómica el contenido propio de un entorno a otro antes de salir o borrar
  Future<bool> migrateAllContent({
    required String sourceEnvironmentId,
    required String targetEnvironmentId,
  }) async {
    _isActionLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final ok = await _environmentRepository.migrateContent(
        sourceEnvironmentId: sourceEnvironmentId,
        targetEnvironmentId: targetEnvironmentId,
      );
      if (ok) {
        _successMessage = 'Contenido propio migrado con éxito';
        return true;
      }
      _errorMessage = 'No se pudo completar la migración de contenido';
      return false;
    } catch (e) {
      _errorMessage = 'Error al migrar contenido: $e';
      return false;
    } finally {
      _isActionLoading = false;
      notifyListeners();
    }
  }

  /// Expulsa a un miembro de un entorno (solo owner)
  Future<bool> removeMember({
    required String environmentId,
    required String userId,
  }) async {
    _isActionLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final ok = await _environmentRepository.removeMember(
        environmentId: environmentId,
        userId: userId,
      );
      if (ok) {
        _successMessage = 'Miembro expulsado del entorno';
        return true;
      }
      _errorMessage = 'No se pudo expulsar al miembro';
      return false;
    } catch (e) {
      _errorMessage = 'Error al expulsar miembro: $e';
      return false;
    } finally {
      _isActionLoading = false;
      notifyListeners();
    }
  }

  /// Abandona voluntariamente un entorno compartido
  Future<bool> leaveEnvironment(String environmentId) async {
    if (_currentUserId == null) return false;

    _isActionLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final ok = await _environmentRepository.leaveEnvironment(
        environmentId: environmentId,
        userId: _currentUserId!,
      );
      if (ok) {
        _environments.removeWhere((e) => e.id == environmentId);
        if (_activeEnvironment?.id == environmentId) {
          _activeEnvironment = personalEnvironment;
          _isAllSelected = false;
        }
        _successMessage = 'Has abandonado el entorno';
        return true;
      }
      _errorMessage = 'No se pudo abandonar el entorno';
      return false;
    } catch (e) {
      _errorMessage = 'Error al abandonar entorno: $e';
      return false;
    } finally {
      _isActionLoading = false;
      notifyListeners();
    }
  }

  /// Obtiene los miembros de un entorno para visualización
  Future<List<EnvironmentMemberModel>> getMembers(String environmentId) async {
    return _environmentRepository.getEnvironmentMembers(environmentId);
  }

  /// Recarga manual de entornos e invitaciones (pull-to-refresh)
  Future<void> refresh() async {
    if (_currentUserId == null) return;
    try {
      final envs = await _environmentRepository.getEnvironments(_currentUserId!);
      _environments = envs;

      // Si el entorno activo actual ya no existe, reajustar al personal
      if (_activeEnvironment != null &&
          !_environments.any((e) => e.id == _activeEnvironment!.id)) {
        _activeEnvironment = personalEnvironment;
        _isAllSelected = false;
      }

      _pendingInvitations =
          await _environmentRepository.getPendingInvitations(_currentUserId!);
    } catch (e) {
      debugPrint('[EnvironmentController] Error en refresh: $e');
    } finally {
      notifyListeners();
    }
  }

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _environmentRepository.unsubscribe(_invitationsChannel);
    super.dispose();
  }
}
