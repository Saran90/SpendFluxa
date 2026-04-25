import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/models/custom_category.dart';
import '../../core/models/transaction.dart';
import '../../core/services/category_service.dart';
import '../../core/theme/app_colors.dart';

/// Shows a modal bottom sheet for adding (or editing) a custom category.
/// Returns the saved [CustomCategory] on success, null on cancel.
Future<CustomCategory?> showAddCategorySheet(
  BuildContext context,
  CategoryService categoryService, {
  TransactionType initialType = TransactionType.expense,
  CustomCategory? editing,
}) {
  return showModalBottomSheet<CustomCategory>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AddCategorySheet(
      categoryService: categoryService,
      initialType: initialType,
      editing: editing,
    ),
  );
}

class _AddCategorySheet extends StatefulWidget {
  final CategoryService categoryService;
  final TransactionType initialType;
  final CustomCategory? editing;

  const _AddCategorySheet({
    required this.categoryService,
    required this.initialType,
    this.editing,
  });

  @override
  State<_AddCategorySheet> createState() => _AddCategorySheetState();
}

class _AddCategorySheetState extends State<_AddCategorySheet> {
  final _nameController = TextEditingController();
  final _nameFocus = FocusNode();

  late TransactionType _type;
  late PickableIcon _selectedIcon;
  late Color _selectedColor;
  String? _nameError;

  // Icon search
  String _iconSearch = '';
  final _iconSearchController = TextEditingController();

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;

    if (_isEditing) {
      final e = widget.editing!;
      _nameController.text = e.label;
      _selectedColor = e.color;
      _type = e.isExpense ? TransactionType.expense : TransactionType.income;
      // Find matching icon in pool, fallback to first
      _selectedIcon = iconPool.firstWhere(
        (p) => p.icon.codePoint == e.iconCodePoint,
        orElse: () => iconPool.first,
      );
    } else {
      _selectedIcon = iconPool.first;
      _selectedColor = categoryColorPalette.first;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocus.dispose();
    _iconSearchController.dispose();
    super.dispose();
  }

  List<PickableIcon> get _filteredIcons {
    if (_iconSearch.isEmpty) return iconPool;
    return iconPool
        .where((p) => p.label.toLowerCase().contains(_iconSearch.toLowerCase()))
        .toList();
  }

  void _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Please enter a category name');
      return;
    }
    setState(() => _nameError = null);

    final id = _isEditing
        ? widget.editing!.id
        : DateTime.now().millisecondsSinceEpoch.toString();

    final cat = CustomCategory(
      id: id,
      label: name,
      iconCodePoint: _selectedIcon.icon.codePoint,
      fontFamily: _selectedIcon.icon.fontFamily ?? 'MaterialIcons',
      color: _selectedColor,
      isExpense: _type == TransactionType.expense,
    );

    if (_isEditing) {
      await widget.categoryService.update(cat);
    } else {
      await widget.categoryService.add(cat);
    }

    if (mounted) Navigator.of(context).pop(cat);
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.only(bottom: viewInsets.bottom),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, bottomPadding + 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Handle ──────────────────────────────────────────────
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.textLight,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),

                // ── Title ────────────────────────────────────────────────
                Text(
                  _isEditing ? 'Edit Category' : 'New Category',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 24),

                // ── Type toggle ──────────────────────────────────────────
                _buildTypeToggle(),
                const SizedBox(height: 24),

                // ── Preview + name row ───────────────────────────────────
                _buildPreviewAndName(),
                const SizedBox(height: 24),

                // ── Color picker ─────────────────────────────────────────
                _buildSectionLabel('Color'),
                const SizedBox(height: 12),
                _buildColorPicker(),
                const SizedBox(height: 24),

                // ── Icon picker ──────────────────────────────────────────
                _buildSectionLabel('Icon'),
                const SizedBox(height: 12),
                _buildIconSearchField(),
                const SizedBox(height: 12),
                _buildIconGrid(),
                const SizedBox(height: 28),

                // ── Save button ──────────────────────────────────────────
                _buildSaveButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Type toggle ───────────────────────────────────────────────────────────

  Widget _buildTypeToggle() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _typeTab('Expense', TransactionType.expense),
          _typeTab('Income', TransactionType.income),
        ],
      ),
    );
  }

  Widget _typeTab(String label, TransactionType type) {
    final isActive = _type == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _type = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.07),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Preview + name ────────────────────────────────────────────────────────

  Widget _buildPreviewAndName() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Live preview circle
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: _selectedColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(_selectedIcon.icon, color: _selectedColor, size: 28),
        ),
        const SizedBox(width: 16),
        // Name field
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameController,
                focusNode: _nameFocus,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Category name',
                  hintStyle: const TextStyle(
                    color: AppColors.textLight,
                    fontWeight: FontWeight.w400,
                  ),
                  errorText: _nameError,
                  filled: true,
                  fillColor: AppColors.background,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.accent, width: 1.5),
                  ),
                ),
                onChanged: (_) {
                  if (_nameError != null) setState(() => _nameError = null);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Color picker ──────────────────────────────────────────────────────────

  Widget _buildColorPicker() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: categoryColorPalette.map((color) {
        final isSelected = _selectedColor.toARGB32() == color.toARGB32();
        return GestureDetector(
          onTap: () => setState(() => _selectedColor = color),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: isSelected
                  ? Border.all(color: Colors.white, width: 3)
                  : null,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.5),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: isSelected
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                : null,
          ),
        );
      }).toList(),
    );
  }

  // ── Icon search ───────────────────────────────────────────────────────────

  Widget _buildIconSearchField() {
    return TextField(
      controller: _iconSearchController,
      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: 'Search icons…',
        hintStyle: const TextStyle(color: AppColors.textLight, fontSize: 14),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: AppColors.textSecondary,
          size: 20,
        ),
        suffixIcon: _iconSearch.isNotEmpty
            ? GestureDetector(
                onTap: () {
                  _iconSearchController.clear();
                  setState(() => _iconSearch = '');
                },
                child: const Icon(
                  Icons.close_rounded,
                  color: AppColors.textSecondary,
                  size: 18,
                ),
              )
            : null,
        filled: true,
        fillColor: AppColors.background,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      onChanged: (v) => setState(() => _iconSearch = v),
    );
  }

  // ── Icon grid ─────────────────────────────────────────────────────────────

  Widget _buildIconGrid() {
    final icons = _filteredIcons;

    if (icons.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            'No icons match "$_iconSearch"',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    }

    // Fixed-height scrollable grid
    return SizedBox(
      height: 220,
      child: GridView.builder(
        physics: const BouncingScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 6,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1,
        ),
        itemCount: icons.length,
        itemBuilder: (context, index) {
          final item = icons[index];
          final isSelected =
              _selectedIcon.icon.codePoint == item.icon.codePoint;

          return GestureDetector(
            onTap: () => setState(() => _selectedIcon = item),
            child: Tooltip(
              message: item.label,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color: isSelected
                      ? _selectedColor.withValues(alpha: 0.15)
                      : AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: isSelected
                      ? Border.all(color: _selectedColor, width: 2)
                      : null,
                ),
                child: Icon(
                  item.icon,
                  size: 22,
                  color: isSelected ? _selectedColor : AppColors.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Save button ───────────────────────────────────────────────────────────

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _save,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          _isEditing ? 'Save Changes' : 'Add Category',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
        letterSpacing: 0.4,
      ),
    );
  }
}
