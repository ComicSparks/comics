import 'package:flutter/material.dart';
import 'package:comics/src/rust/api/module_api.dart';
import 'package:comics/src/rust/modules/types.dart';
import 'package:comics/components/comics_view.dart';

/// 嵌入式模块浏览视图（带分类选择）
class HomeModuleView extends StatefulWidget {
  final ModuleInfo module;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onHistoryChanged;

  const HomeModuleView({
    super.key,
    required this.module,
    this.onOpenSettings,
    this.onHistoryChanged,
  });

  @override
  State<HomeModuleView> createState() => _HomeModuleViewState();
}

class _HomeModuleViewState extends State<HomeModuleView> {
  List<Category> _categories = [];
  Category? _selectedCategory;
  bool _loading = true;
  String? _error;
  List<SortOption> _sortOptions = [];
  String _currentSort = '';

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void didUpdateWidget(covariant HomeModuleView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.module.id != widget.module.id) {
      _categories = [];
      _selectedCategory = null;
      _error = null;
      _loading = true;
      _sortOptions = [];
      _currentSort = '';
      _loadCategories();
    }
  }

  Future<void> _loadCategories() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      await loadModule(moduleId: widget.module.id);
      final categories = await getCategories(moduleId: widget.module.id);
      final sorts = await getSortOptions(moduleId: widget.module.id);

      if (!mounted) return;
      setState(() {
        _categories = categories;
        if (categories.isNotEmpty) {
          _selectedCategory = categories.first;
        }
        _sortOptions = sorts;
        _currentSort = sorts.isNotEmpty ? sorts.first.value : '';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _showCategoryPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text('选择分类', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final isSelected = _selectedCategory?.id == cat.id;
                  return ListTile(
                    leading: isSelected
                        ? const Icon(Icons.check, color: Colors.deepPurple)
                        : const SizedBox(width: 24),
                    title: Text(cat.title),
                    selected: isSelected,
                    onTap: () {
                      setState(() => _selectedCategory = cat);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              if (_categories.isNotEmpty)
                TextButton.icon(
                  onPressed: _showCategoryPicker,
                  icon: const Icon(Icons.category, size: 20),
                  label: Text(
                    _selectedCategory?.title ?? '选择分类',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              const SizedBox(width: 8),
              if (_sortOptions.isNotEmpty)
                DropdownButton<String>(
                  value: _currentSort.isNotEmpty ? _currentSort : null,
                  hint: const Text('选择排序'),
                  items: _sortOptions
                      .map((s) => DropdownMenuItem<String>(
                            value: s.value,
                            child: Text(s.name),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _currentSort = value);
                  },
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: Colors.red),
            const SizedBox(height: 16),
            Text('加载失败', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadCategories,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_categories.isEmpty) {
      return const Center(child: Text('暂无分类'));
    }

    if (_selectedCategory != null) {
      return ComicsView(
        key: ValueKey('${widget.module.id}_${_selectedCategory!.id}'),
        moduleId: widget.module.id,
        moduleName: widget.module.name,
        categorySlug: _selectedCategory!.id,
        categoryTitle: _selectedCategory!.title,
        onHistoryChanged: widget.onHistoryChanged,
        sortOptions: _sortOptions,
        sortValue: _currentSort,
        onSortChanged: (value) {
          setState(() => _currentSort = value);
        },
        showSortControls: false,
      );
    }

    return const Center(child: Text('请选择分类'));
  }
}
