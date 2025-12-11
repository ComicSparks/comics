import 'package:flutter/material.dart';
import 'package:comics/src/rust/api/module_api.dart';
import 'package:comics/src/rust/modules/types.dart';
import 'package:comics/screens/module_settings_screen.dart';
import 'package:comics/components/comics_view.dart';

/// 模块页面
class ModuleScreen extends StatefulWidget {
  final ModuleInfo module;
  
  const ModuleScreen({super.key, required this.module});

  @override
  State<ModuleScreen> createState() => _ModuleScreenState();
}

class _ModuleScreenState extends State<ModuleScreen> {
  List<Category> _categories = [];
  Category? _selectedCategory;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });
      
      debugPrint('[ModuleScreen] Loading module: ${widget.module.id}');
      
      // 加载模块
      await loadModule(moduleId: widget.module.id);
      
      debugPrint('[ModuleScreen] Module loaded, getting categories...');
      
      // 获取分类
      final categories = await getCategories(moduleId: widget.module.id);
      
      debugPrint('[ModuleScreen] Got ${categories.length} categories');
      
      setState(() {
        _categories = categories;
        // 默认选中第一个分类
        if (categories.isNotEmpty) {
          _selectedCategory = categories.first;
        }
        _loading = false;
      });
    } catch (e, stackTrace) {
      debugPrint('[ModuleScreen] Error: $e');
      debugPrint('[ModuleScreen] StackTrace: $stackTrace');
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

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ModuleSettingsScreen(module: widget.module),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.module.name),
        actions: [
          // 分类选择器
          if (_categories.isNotEmpty)
            TextButton.icon(
              onPressed: _showCategoryPicker,
              icon: const Icon(Icons.category, size: 20),
              label: Text(
                _selectedCategory?.title ?? '选择分类',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          // 设置按钮
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '模块设置',
            onPressed: _openSettings,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 60, color: Colors.red),
              const SizedBox(height: 20),
              Text(
                '加载失败',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loadCategories,
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }
    
    if (_categories.isEmpty) {
      return const Center(
        child: Text('暂无分类'),
      );
    }

    // 直接显示当前选中分类的漫画列表
    if (_selectedCategory != null) {
      return ComicsView(
        key: ValueKey(_selectedCategory!.id),
        moduleId: widget.module.id,
        moduleName: widget.module.name,
        categorySlug: _selectedCategory!.id,
        categoryTitle: _selectedCategory!.title,
      );
    }
    
    return const Center(child: Text('请选择分类'));
  }
}
