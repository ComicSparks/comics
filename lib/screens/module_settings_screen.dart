import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:comics/src/rust/api/module_api.dart';
import 'package:comics/src/rust/modules/types.dart';

/// 模块设置页面
class ModuleSettingsScreen extends StatefulWidget {
  final ModuleInfo module;
  
  const ModuleSettingsScreen({super.key, required this.module});

  @override
  State<ModuleSettingsScreen> createState() => _ModuleSettingsScreenState();
}

class _ModuleSettingsScreenState extends State<ModuleSettingsScreen> {
  bool _loading = false;
  bool _obscurePassword = true;
  String? _message;
  bool _isSuccess = false;
  Map<String, dynamic>? _authForm;
  final Map<String, String> _formValues = {};
  final Map<String, TextEditingController> _fieldControllers = {};

  @override
  void initState() {
    super.initState();
    _loadAuthForm();
    _loadAuthValues();
  }

  Future<void> _loadAuthForm() async {
    try {
      final jsonStr = await callModuleFunction(
        moduleId: widget.module.id,
        funcName: 'getAuthForm',
        argsJson: '{}',
      );
      if (jsonStr.isNotEmpty) {
        final obj = jsonDecode(jsonStr) as Map<String, dynamic>;
        setState(() {
          _authForm = obj;
        });
      }
    } catch (e) {
      debugPrint('No auth form for module ${widget.module.id}: $e');
    }
  }

  Future<void> _loadAuthValues() async {
    try {
      final jsonStr = await callModuleFunction(
        moduleId: widget.module.id,
        funcName: 'getAuthValues',
        argsJson: '{}',
      );
      if (jsonStr.isNotEmpty) {
        final obj = jsonDecode(jsonStr) as Map<String, dynamic>;
        obj.forEach((k, v) {
          if (v is String) {
            _formValues[k] = v;
          } else if (v != null) {
            _formValues[k] = v.toString();
          }
        });
        // 同步到已有文本控制器，确保回显
        _formValues.forEach((k, v) {
          if (_fieldControllers.containsKey(k)) {
            final c = _fieldControllers[k]!;
            if (c.text != v) c.text = v;
          }
        });
        if (mounted) setState(() {});
      }
    } catch (e) {
      debugPrint('No auth values for module ${widget.module.id}: $e');
    }
  }

  Future<void> _submitAuthForm() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final argsJson = jsonEncode(_formValues);
      final rsp = await callModuleFunction(
        moduleId: widget.module.id,
        funcName: 'submitAuthForm',
        argsJson: argsJson,
      );
      final obj = jsonDecode(rsp);
      final success = (obj is Map && (obj['success'] == true));
      setState(() {
        _message = success ? '保存成功' : '保存失败';
        _isSuccess = success;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _message = '保存失败: $e';
        _isSuccess = false;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    for (final c in _fieldControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasDynamicForm = _authForm != null && _authForm!['fields'] is List;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.module.name} 设置'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 模块信息
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.extension, size: 40),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.module.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'ID: ${widget.module.id}',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // 动态模块设置表单（若模块提供）
          if (hasDynamicForm) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.settings_suggest),
                        const SizedBox(width: 8),
                        Text(
                          '模块配置',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ...(_authForm!['fields'] as List).map((f) {
                      final field = f as Map<String, dynamic>;
                      final key = field['key'] as String? ?? '';
                      final type = field['type'] as String? ?? 'text';
                      final label = field['label'] as String? ?? key;
                      final placeholder = field['placeholder'] as String? ?? '';
                      Widget w;
                      if (type == 'password') {
                        // 绑定控制器以支持回显
                        final controller = _fieldControllers.putIfAbsent(
                          key,
                          () => TextEditingController(text: _formValues[key] ?? ''),
                        );
                        w = TextField(
                          controller: controller,
                          onChanged: (v) => _formValues[key] = v,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: label,
                            hintText: placeholder,
                            prefixIcon: const Icon(Icons.lock),
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              ),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                          enabled: !_loading,
                        );
                      } else if (type == 'select') {
                        final options = (field['options'] as List?)?.cast<Map<String, dynamic>>() ?? [];
                        final allowCustom = field['allowCustom'] == true;
                        final customKey = field['customKey'] as String? ?? key;
                        final items = options.map((o) => DropdownMenuItem<String>(
                          value: o['value'] as String,
                          child: Text(o['label'] as String? ?? o['value'] as String),
                        )).toList();
                        // Add a custom option
                        if (allowCustom) {
                          items.add(const DropdownMenuItem<String>(
                            value: '__CUSTOM__',
                            child: Text('自定义'),
                          ));
                        }
                        // Determine selected value safely
                        String? selected = _formValues[key];
                        final itemValues = items.map((e) => e.value).toList();
                        if (selected == null || selected.isEmpty) {
                          selected = null;
                        } else if (!itemValues.contains(selected)) {
                          // If not in list and custom allowed, choose custom
                          selected = allowCustom ? '__CUSTOM__' : null;
                        }
                        w = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DropdownButtonFormField<String>(
                              decoration: InputDecoration(
                                labelText: label,
                                border: const OutlineInputBorder(),
                              ),
                              // use initialValue to avoid deprecated warnings
                              initialValue: selected,
                              items: items,
                              onChanged: (v) {
                                setState(() {
                                  _formValues[key] = v ?? '';
                                });
                              },
                            ),
                            if (allowCustom && (selected == '__CUSTOM__' || _formValues[key] == '__CUSTOM__'))
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: TextField(
                                  decoration: InputDecoration(
                                    labelText: '自定义 $label',
                                    hintText: placeholder,
                                    border: const OutlineInputBorder(),
                                  ),
                                  onChanged: (v) => _formValues[customKey] = v,
                                  enabled: !_loading,
                                ),
                              ),
                          ],
                        );
                      } else {
                        // 普通文本字段
                        final controller = _fieldControllers.putIfAbsent(
                          key,
                          () => TextEditingController(text: _formValues[key] ?? ''),
                        );
                        w = TextField(
                          controller: controller,
                          onChanged: (v) => _formValues[key] = v,
                          decoration: InputDecoration(
                            labelText: label,
                            hintText: placeholder,
                            prefixIcon: const Icon(Icons.person),
                            border: const OutlineInputBorder(),
                          ),
                          enabled: !_loading,
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: w,
                      );
                    }).cast<Widget>(),
                    const SizedBox(height: 16),
                    
                    // 提示消息
                    if (_message != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: _isSuccess 
                              ? Colors.green[50] 
                              : Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _isSuccess 
                                ? Colors.green 
                                : Colors.red,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isSuccess 
                                  ? Icons.check_circle 
                                  : Icons.error,
                              color: _isSuccess 
                                  ? Colors.green 
                                  : Colors.red,
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_message!)),
                          ],
                        ),
                      ),
                    
                    // 按钮
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _submitAuthForm,
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('保存'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(Icons.info_outline, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text(
                      '此模块无需配置',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
