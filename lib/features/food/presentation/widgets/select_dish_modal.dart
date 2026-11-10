import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/dish_model.dart';
import '../../domain/models/weekly_menu_slot_model.dart';
import 'edit_dish_modal.dart';

class SelectDishModal extends StatefulWidget {
  final DateTime date;
  final MealType mealType;
  final List<DishModel> dishes;
  final WeeklyMenuSlotModel? currentSlot;
  final Function(
    DishModel? dish,
    String? customDishName,
    String? servingsNote,
    bool syncIngredients,
    List<DateTime> repeatDates,
  ) onSelect;
  final Function(
    String name,
    int defaultServings,
    List<String> ingredients, {
    String? cuisine,
    String? servingTemperature,
  }) onCreateNewDish;

  const SelectDishModal({
    super.key,
    required this.date,
    required this.mealType,
    required this.dishes,
    this.currentSlot,
    required this.onSelect,
    required this.onCreateNewDish,
  });

  static Future<void> show(
    BuildContext context, {
    required DateTime date,
    required MealType mealType,
    required List<DishModel> dishes,
    WeeklyMenuSlotModel? currentSlot,
    required Function(
      DishModel? dish,
      String? customDishName,
      String? servingsNote,
      bool syncIngredients,
      List<DateTime> repeatDates,
    ) onSelect,
    required Function(
      String name,
      int defaultServings,
      List<String> ingredients, {
      String? cuisine,
      String? servingTemperature,
    }) onCreateNewDish,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SelectDishModal(
        date: date,
        mealType: mealType,
        dishes: dishes,
        currentSlot: currentSlot,
        onSelect: onSelect,
        onCreateNewDish: onCreateNewDish,
      ),
    );
  }

  @override
  State<SelectDishModal> createState() => _SelectDishModalState();
}

class _SelectDishModalState extends State<SelectDishModal> {
  late TextEditingController _searchController;
  String _searchQuery = '';
  String _selectedCuisine = 'Todas';
  String _selectedTemperature = 'Todos'; // 'Todos', 'frío', 'caliente'
  String _selectedAppliance = 'Todos';   // 'Todos', 'airfryer', 'oven', 'microwave', 'stovetop'

  DishModel? _selectedDish;
  String? _servingsNote;
  bool _syncIngredients = true;
  final Set<DateTime> _repeatDates = {};

  late List<DateTime> _weekDays;

  // Culturas principales para filtros rápidos
  final List<String> _cuisines = [
    'Todas',
    'Española',
    'Italiana',
    'Mexicana',
    'Turca',
    'Asiática',
    'Árabe / Oriente Medio',
    'Peruana',
    'Americana',
    'Francesa',
    'Griega',
    'Internacional',
  ];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _selectedDish = widget.currentSlot?.dish;
    _servingsNote = widget.currentSlot?.servingsNote ??
        (_selectedDish != null ? '${_selectedDish!.defaultServings} rac.' : null);

    final clean = DateTime(widget.date.year, widget.date.month, widget.date.day);
    final monday = clean.subtract(Duration(days: clean.weekday - 1));
    _weekDays = List.generate(7, (i) => monday.add(Duration(days: i)));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatDayName(DateTime d) {
    const days = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
    return '${days[d.weekday - 1]} ${d.day}';
  }

  void _confirmSelection(DishModel? dish, {String? customName}) {
    widget.onSelect(
      dish,
      customName,
      _servingsNote,
      _syncIngredients,
      _repeatDates.toList(),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    // Filtrar platos localmente con los filtros seleccionados
    final filteredDishes = widget.dishes.where((d) {
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        final matchTitle = d.name.toLowerCase().contains(q);
        final matchCuisine = d.cuisine?.toLowerCase().contains(q) ?? false;
        final matchIng = d.ingredients.any((i) => i.toLowerCase().contains(q));
        if (!matchTitle && !matchCuisine && !matchIng) return false;
      }

      if (_selectedCuisine != 'Todas') {
        if (d.cuisine?.toLowerCase() != _selectedCuisine.toLowerCase()) return false;
      }

      if (_selectedTemperature != 'Todos') {
        if (d.servingTemperature?.toLowerCase() != _selectedTemperature.toLowerCase()) return false;
      }

      if (_selectedAppliance != 'Todos') {
        if (!d.supportedAppliances.contains(_selectedAppliance.toLowerCase())) return false;
      }

      return true;
    }).toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      padding: EdgeInsets.fromLTRB(16, 14, 16, 16 + bottomInset),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppTheme.cardBorderColor, width: 0.8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Cabecera: Día y franja
          Row(
            children: [
              Text(
                '${widget.mealType.iconEmoji} ${widget.mealType.label}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _formatDayName(widget.date),
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
                ),
              ),
              const Spacer(),
              Text(
                '${filteredDishes.length} platos',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
              ),
              const SizedBox(width: 6),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Buscador rápido
          TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val),
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Buscar plato, ingrediente o cultura (ej. paella, tacos)...',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 13),
              prefixIcon: const Icon(Icons.search, color: Colors.white60, size: 18),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white60, size: 16),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.04),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.primaryLiquid, width: 1.2),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Píldoras de Filtros: Temperatura (Frío/Caliente), Electrodoméstico y Cultura
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Filtro Temperatura: Frío / Caliente
                _buildFilterChip(
                  label: _selectedTemperature == 'Todos'
                      ? '🌡️ Temp.'
                      : (_selectedTemperature == 'frío' ? '❄️ Frío' : '🔥 Caliente'),
                  isSelected: _selectedTemperature != 'Todos',
                  onTap: () {
                    setState(() {
                      if (_selectedTemperature == 'Todos') {
                        _selectedTemperature = 'frío';
                      } else if (_selectedTemperature == 'frío') {
                        _selectedTemperature = 'caliente';
                      } else {
                        _selectedTemperature = 'Todos';
                      }
                    });
                  },
                ),
                const SizedBox(width: 6),

                // Filtro Electrodoméstico
                _buildFilterChip(
                  label: _selectedAppliance == 'Todos'
                      ? '♨️ Aparato'
                      : _applianceLabel(_selectedAppliance),
                  isSelected: _selectedAppliance != 'Todos',
                  onTap: () {
                    const cycle = ['Todos', 'airfryer', 'oven', 'microwave', 'stovetop'];
                    final nextIdx = (cycle.indexOf(_selectedAppliance) + 1) % cycle.length;
                    setState(() => _selectedAppliance = cycle[nextIdx]);
                  },
                ),
                const SizedBox(width: 8),
                Container(width: 1, height: 20, color: Colors.white12),
                const SizedBox(width: 8),

                // Chips de Cultura
                ..._cuisines.map((c) {
                  final isSel = _selectedCuisine == c;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InkWell(
                      onTap: () => setState(() => _selectedCuisine = c),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isSel
                              ? AppTheme.primaryLiquid.withValues(alpha: 0.2)
                              : Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSel ? AppTheme.primaryLiquid : Colors.white12,
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          c,
                          style: TextStyle(
                            color: isSel ? AppTheme.primaryLiquid : Colors.white70,
                            fontSize: 12,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Configuración del plato seleccionado (raciones, batch cooking)
          if (_selectedDish != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryLiquid.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primaryLiquid.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.restaurant, color: AppTheme.primaryLiquid, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedDish!.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (_selectedDish!.cuisine != null || _selectedDish!.servingTemperature != null)
                              Text(
                                '${_selectedDish!.cuisine ?? "Internacional"} · ${_selectedDish!.servingTemperature == "frío" ? "❄️ Servir frío" : "🔥 Servir caliente"}',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
                              ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _selectedDish = null),
                        child: Text(
                          'Cambiar',
                          style: TextStyle(
                            color: AppTheme.primaryLiquid.withValues(alpha: 0.9),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Raciones / nota
                  Row(
                    children: [
                      Text(
                        'Raciones:',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
                      ),
                      const SizedBox(width: 8),
                      ...[2, 4, 6].map((r) {
                        final note = '$r rac.';
                        final isSel = _servingsNote == note;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: InkWell(
                            onTap: () => setState(() => _servingsNote = isSel ? null : note),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isSel ? AppTheme.primaryLiquid : Colors.white.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                note,
                                style: TextStyle(
                                  color: isSel ? Colors.black : Colors.white70,
                                  fontSize: 12,
                                  fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Repetir en otros días (Batch cooking)
                  Text(
                    'Poner también este mismo plato en:',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _weekDays.map((d) {
                      final isCurrentDay = d.year == widget.date.year &&
                          d.month == widget.date.month &&
                          d.day == widget.date.day;
                      if (isCurrentDay) return const SizedBox.shrink();

                      final isSelected = _repeatDates.contains(d);
                      return InkWell(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _repeatDates.remove(d);
                            } else {
                              _repeatDates.add(d);
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primaryLiquid.withValues(alpha: 0.2)
                                : Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isSelected ? AppTheme.primaryLiquid : Colors.white12,
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            _formatDayName(d),
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white60,
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  // Sincronizar ingredientes a la compra
                  if (_selectedDish!.ingredients.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: Checkbox(
                            value: _syncIngredients,
                            activeColor: AppTheme.primaryLiquid,
                            checkColor: Colors.black,
                            onChanged: (v) => setState(() => _syncIngredients = v ?? true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Enviar ingredientes a la lista de la compra',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: () => _confirmSelection(_selectedDish),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryLiquid,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Confirmar Plato', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ] else ...[
            // Lista de platos encontrados
            Expanded(
              child: ListView(
                children: [
                  // Opción de crear plato al instante con el texto buscado
                  if (_searchQuery.trim().isNotEmpty) ...[
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      leading: Icon(Icons.add_circle_outline, color: AppTheme.primaryLiquid),
                      title: Text(
                        'Crear plato "${_searchQuery.trim()}"',
                        style: TextStyle(color: AppTheme.primaryLiquid, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      onTap: () {
                        final queryText = _searchQuery.trim();
                        EditDishModal.show(
                          context,
                          initialDish: DishModel(
                            id: '',
                            environmentId: '',
                            name: queryText,
                            defaultServings: 2,
                            ingredients: [],
                            cuisine: _selectedCuisine != 'Todas' ? _selectedCuisine : null,
                            servingTemperature: _selectedTemperature != 'Todos' ? _selectedTemperature : null,
                            createdAt: DateTime.now(),
                          ),
                          onSave: (name, defaultServings, ingredients) {
                            widget.onCreateNewDish(
                              name,
                              defaultServings,
                              ingredients,
                              cuisine: _selectedCuisine != 'Todas' ? _selectedCuisine : null,
                              servingTemperature: _selectedTemperature != 'Todos' ? _selectedTemperature : null,
                            );
                            Navigator.of(context).pop();
                          },
                        );
                      },
                    ),
                    const Divider(color: Colors.white12, height: 1),
                  ],

                  if (filteredDishes.isEmpty && _searchQuery.trim().isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          'No hay platos que coincidan con los filtros seleccionados.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13),
                        ),
                      ),
                    ),

                  ...filteredDishes.map((dish) {
                    final ingCount = dish.ingredients.length;
                    final isCold = dish.servingTemperature == 'frío';

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      leading: Icon(
                        isCold ? Icons.ac_unit : Icons.restaurant_menu,
                        color: isCold ? Colors.lightBlueAccent : Colors.white60,
                        size: 20,
                      ),
                      title: Text(
                        dish.name,
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      subtitle: Row(
                        children: [
                          if (dish.cuisine != null) ...[
                            Text(
                              dish.cuisine!,
                              style: TextStyle(color: AppTheme.primaryLiquid.withValues(alpha: 0.8), fontSize: 11),
                            ),
                            const Text(' · ', style: TextStyle(color: Colors.white30, fontSize: 11)),
                          ],
                          Text(
                            isCold ? '❄️ Frío' : '🔥 Caliente',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
                          ),
                          if (dish.supportedAppliances.contains('airfryer')) ...[
                            const Text(' · ', style: TextStyle(color: Colors.white30, fontSize: 11)),
                            const Text('Airfryer', style: TextStyle(color: Colors.orangeAccent, fontSize: 11)),
                          ] else if (dish.supportedAppliances.contains('oven')) ...[
                            const Text(' · ', style: TextStyle(color: Colors.white30, fontSize: 11)),
                            const Text('Horno', style: TextStyle(color: Colors.amberAccent, fontSize: 11)),
                          ],
                          const Text(' · ', style: TextStyle(color: Colors.white30, fontSize: 11)),
                          Text(
                            '$ingCount ing.',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
                          ),
                        ],
                      ),
                      onTap: () {
                        setState(() {
                          _selectedDish = dish;
                          _servingsNote = '${dish.defaultServings} rac.';
                        });
                      },
                    );
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryLiquid.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppTheme.primaryLiquid : Colors.white12,
            width: 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppTheme.primaryLiquid : Colors.white,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  String _applianceLabel(String app) {
    switch (app) {
      case 'airfryer':
        return '🌀 Airfryer';
      case 'oven':
        return '🔥 Horno';
      case 'microwave':
        return '⚡ Microondas';
      case 'stovetop':
        return '🍳 Fuego';
      default:
        return '♨️ $app';
    }
  }
}
