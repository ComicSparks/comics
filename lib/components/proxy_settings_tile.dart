import 'package:flutter/material.dart';
import 'package:comics/src/rust/api/proxy_api.dart';

/// 代理设置组件
class ProxySettingsTile extends StatefulWidget {
  const ProxySettingsTile({super.key});

  @override
  State<ProxySettingsTile> createState() => _ProxySettingsTileState();
}

class _ProxySettingsTileState extends State<ProxySettingsTile> {
  String? _proxyUrl;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadProxy();
  }

  Future<void> _loadProxy() async {
    setState(() => _loading = true);
    try {
      final url = await getProxy();
      if (mounted) {
        setState(() {
          _proxyUrl = url;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _showProxyDialog() async {
    final controller = TextEditingController(text: _proxyUrl ?? '');
    
    final result = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('代理设置'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '请输入代理地址，支持 http:// 或 socks5:// 协议\n'
              '例如：\n'
              '  http://127.0.0.1:8080\n'
              '  socks5://127.0.0.1:1080',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: '代理地址',
                hintText: 'http://127.0.0.1:8080',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: const Text('清除'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (result == null) return;

    setState(() => _loading = true);
    try {
      if (result.isEmpty) {
        await clearProxy();
      } else {
        await setProxy(url: result);
      }
      
      if (mounted) {
        await _loadProxy();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.isEmpty ? '代理已清除' : '代理设置已保存'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('设置失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.settings_ethernet),
      title: const Text('代理设置'),
      subtitle: _loading
          ? const Text('加载中...')
          : Text(_proxyUrl ?? '未设置代理'),
      onTap: _showProxyDialog,
      enabled: !_loading,
    );
  }
}
