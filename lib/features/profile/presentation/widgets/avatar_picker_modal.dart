import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/liquid_theme.dart';
import '../../../../core/widgets/liquid_banner.dart';
import '../../../../core/widgets/liquid_button.dart';
import '../../../../core/widgets/neumorphic_container.dart';
import '../../domain/models/avatar_catalog.dart';
import '../../domain/models/avatar_data.dart';
import '../controllers/profile_controller.dart';
import 'user_avatar.dart';

/// Modal interactivo para personalizar el avatar del usuario
class AvatarPickerModal extends StatefulWidget {
  final ProfileController profileController;

  const AvatarPickerModal({
    super.key,
    required this.profileController,
  });

  static Future<void> show(
    BuildContext context, {
    required ProfileController profileController,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AvatarPickerModal(profileController: profileController),
    );
  }

  @override
  State<AvatarPickerModal> createState() => _AvatarPickerModalState();
}

class _AvatarPickerModalState extends State<AvatarPickerModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ImagePicker _picker = ImagePicker();

  // Estado local de previsualización
  late AvatarType _selectedType;
  late String _selectedIconKey;
  late String _selectedColorHex;
  Uint8List? _localPickedBytes;
  String? _localPickedExtension;
  String? _localError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    final currentData = widget.profileController.currentProfile?.avatarData ??
        const AvatarData.initials();

    _selectedType = currentData.type;
    _selectedIconKey = currentData.iconKey ?? 'gamepad';
    _selectedColorHex = currentData.bgColorHex ?? AvatarColorPalette.presetColors.first;

    // Sincronizar tab inicial
    switch (_selectedType) {
      case AvatarType.icon:
        _tabController.index = 0;
        break;
      case AvatarType.image:
        _tabController.index = 1;
        break;
      case AvatarType.initials:
        _tabController.index = 2;
        break;
    }

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          if (_tabController.index == 0) {
            _selectedType = AvatarType.icon;
          } else if (_tabController.index == 1) {
            if (_localPickedBytes != null) {
              _selectedType = AvatarType.image;
            }
          } else {
            _selectedType = AvatarType.initials;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  AvatarData _buildPreviewData() {
    switch (_selectedType) {
      case AvatarType.icon:
        return AvatarData.icon(
          iconKey: _selectedIconKey,
          bgColorHex: _selectedColorHex,
        );
      case AvatarType.image:
        if (_localPickedBytes != null) {
          // Si hay bytes locales elegidos, en preview usaremos icono con color
          // mientras se sube a Storage
          return widget.profileController.currentProfile?.avatarData ??
              const AvatarData.initials();
        }
        return widget.profileController.currentProfile?.avatarData ??
            const AvatarData.initials();
      case AvatarType.initials:
        return const AvatarData.initials();
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final xFile = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (xFile != null) {
        final bytes = await xFile.readAsBytes();
        final ext = xFile.name.split('.').last.toLowerCase();

        setState(() {
          _localPickedBytes = bytes;
          _localPickedExtension = ext.isEmpty ? 'jpg' : ext;
          _selectedType = AvatarType.image;
          _localError = null;
        });
      }
    } catch (e) {
      setState(() {
        _localError = 'Error al seleccionar la imagen: $e';
      });
    }
  }

  Future<void> _handleSave() async {
    setState(() => _localError = null);
    final controller = widget.profileController;

    bool ok = false;
    if (_selectedType == AvatarType.icon) {
      ok = await controller.selectAvatarIcon(_selectedIconKey, _selectedColorHex);
    } else if (_selectedType == AvatarType.image) {
      if (_localPickedBytes != null) {
        ok = await controller.uploadAvatarImage(
          _localPickedBytes!,
          _localPickedExtension ?? 'jpg',
        );
      } else {
        // Ya tenía imagen o no se seleccionó ninguna nueva
        ok = true;
      }
    } else {
      ok = await controller.resetToInitials();
    }

    if (ok && mounted) {
      Navigator.pop(context);
    } else if (!ok && mounted) {
      setState(() {
        _localError = controller.errorMessage ?? 'Error al guardar avatar';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = widget.profileController.isUpdatingAvatar;
    final username = widget.profileController.currentProfile?.username ?? 'Usuario';

    return Container(
      decoration: BoxDecoration(
        color: LiquidTheme.surfaceDark.withValues(alpha: 0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: LiquidTheme.glassBorderColor,
          width: 1.5,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            left: 20,
            right: 20,
            top: 12,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Barra de arrastre superior
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: LiquidTheme.textSecondary.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // Cabecera
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Personalizar Avatar',
                    style: TextStyle(
                      color: LiquidTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: LiquidTheme.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Vista Previa Central
              _buildLivePreview(username),
              const SizedBox(height: 18),

              // Pestañas Selectoras
              TabBar(
                controller: _tabController,
                indicatorColor: LiquidTheme.primaryCyan,
                labelColor: LiquidTheme.primaryCyan,
                unselectedLabelColor: LiquidTheme.textSecondary,
                indicatorWeight: 3,
                tabs: const [
                  Tab(icon: Icon(Icons.palette_rounded, size: 20), text: 'Icono & Color'),
                  Tab(icon: Icon(Icons.photo_camera_rounded, size: 20), text: 'Subir Foto'),
                  Tab(icon: Icon(Icons.text_fields_rounded, size: 20), text: 'Iniciales'),
                ],
              ),
              const SizedBox(height: 16),

              // Contenido de cada pestaña
              SizedBox(
                height: 260,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildIconAndColorTab(),
                    _buildUploadPhotoTab(),
                    _buildInitialsTab(username),
                  ],
                ),
              ),

              if (_localError != null) ...[
                const SizedBox(height: 10),
                LiquidBanner(
                  message: _localError!,
                  type: BannerType.error,
                  onClose: () => setState(() => _localError = null),
                ),
              ],

              const SizedBox(height: 16),

              // Botón Guardar
              LiquidButton(
                text: 'Guardar Avatar',
                isLoading: isSaving,
                icon: Icons.check_rounded,
                onPressed: isSaving ? null : _handleSave,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLivePreview(String username) {
    if (_selectedType == AvatarType.image && _localPickedBytes != null) {
      return Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: LiquidTheme.primaryCyan, width: 2),
          boxShadow: [
            BoxShadow(
              color: LiquidTheme.primaryCyan.withValues(alpha: 0.35),
              blurRadius: 20,
            ),
          ],
        ),
        child: ClipOval(
          child: Image.memory(
            _localPickedBytes!,
            fit: BoxFit.cover,
            width: 84,
            height: 84,
          ),
        ),
      );
    }

    return UserAvatar(
      avatarData: _buildPreviewData(),
      username: username,
      size: 84,
      showGlow: true,
      showBorder: true,
    );
  }

  Widget _buildIconAndColorTab() {
    return ListView(
      children: [
        Text(
          '1. Selecciona un Icono',
          style: TextStyle(
            color: LiquidTheme.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: AvatarIconCatalog.icons.entries.map((entry) {
            final isSelected = _selectedType == AvatarType.icon &&
                _selectedIconKey == entry.key;

            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedType = AvatarType.icon;
                  _selectedIconKey = entry.key;
                  _localPickedBytes = null;
                });
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? LiquidTheme.primaryLiquid.withValues(alpha: 0.25)
                      : LiquidTheme.surfaceDark,
                  border: Border.all(
                    color: isSelected
                        ? LiquidTheme.primaryCyan
                        : LiquidTheme.glassBorderColor,
                    width: isSelected ? 2.0 : 1.0,
                  ),
                ),
                child: Icon(
                  entry.value,
                  color: isSelected
                      ? LiquidTheme.primaryCyan
                      : LiquidTheme.textSecondary,
                  size: 22,
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        Text(
          '2. Selecciona un Color de Fondo',
          style: TextStyle(
            color: LiquidTheme.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: AvatarColorPalette.presetColors.map((colorHex) {
              final color = AvatarColorPalette.parseHex(colorHex);
              final isSelected = _selectedType == AvatarType.icon &&
                  _selectedColorHex.toUpperCase() == colorHex.toUpperCase();

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedType = AvatarType.icon;
                    _selectedColorHex = colorHex;
                  });
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.transparent,
                      width: 2.5,
                    ),
                    boxShadow: [
                      if (isSelected)
                        BoxShadow(
                          color: color.withValues(alpha: 0.5),
                          blurRadius: 10,
                        ),
                    ],
                  ),
                  child: isSelected
                      ? const Icon(Icons.check_rounded, color: Colors.black, size: 20)
                      : null,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildUploadPhotoTab() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (_localPickedBytes != null) ...[
          Text(
            '¡Imagen lista para subir!',
            style: TextStyle(
              color: LiquidTheme.accentEmerald,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Se guardará de forma segura en Supabase Storage al pulsar "Guardar Avatar".',
            textAlign: TextAlign.center,
            style: TextStyle(color: LiquidTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 16),
        ] else ...[
          Icon(
            Icons.add_a_photo_outlined,
            size: 48,
            color: LiquidTheme.textSecondary.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 10),
          Text(
            'Elige una imagen desde tu dispositivo',
            style: TextStyle(color: LiquidTheme.textPrimary, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Formatos compatibles: PNG, JPG, WEBP',
            style: TextStyle(color: LiquidTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 16),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            NeumorphicContainer(
              borderRadius: 14,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              baseColor: LiquidTheme.surfaceDark,
              child: TextButton.icon(
                onPressed: () => _pickImage(ImageSource.gallery),
                icon: Icon(Icons.photo_library_rounded, color: LiquidTheme.primaryLiquid),
                label: Text(
                  'Galería',
                  style: TextStyle(color: LiquidTheme.textPrimary, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(width: 14),
            NeumorphicContainer(
              borderRadius: 14,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              baseColor: LiquidTheme.surfaceDark,
              child: TextButton.icon(
                onPressed: () => _pickImage(ImageSource.camera),
                icon: Icon(Icons.camera_alt_rounded, color: LiquidTheme.primaryCyan),
                label: Text(
                  'Cámara',
                  style: TextStyle(color: LiquidTheme.textPrimary, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInitialsTab(String username) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          UserAvatar(
            avatarData: const AvatarData.initials(),
            username: username,
            size: 68,
          ),
          const SizedBox(height: 14),
          Text(
            'Modo Iniciales Predeterminado',
            style: TextStyle(
              color: LiquidTheme.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Utiliza la inicial de tu nombre con el gradiente líquido de la aplicación.',
            textAlign: TextAlign.center,
            style: TextStyle(color: LiquidTheme.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
