import 'package:flutter/material.dart';
import 'package:comics/src/rust/api/image_cache_api.dart' as api;
import 'package:comics/src/image_cache_manager.dart';

/// 图片缓存设置项
class ImageCacheSettingsTile extends StatefulWidget {
  const ImageCacheSettingsTile({super.key});

  @override
  State<ImageCacheSettingsTile> createState() => _ImageCacheSettingsTileState();
}

class _ImageCacheSettingsTileState extends State<ImageCacheSettingsTile> {
  final _cacheManager = ImageCacheManager();
  api.ImageCacheStats? _stats;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    try {
      final stats = await _cacheManager.getCacheStats();
      if (mounted) {
        setState(() {
          _stats = stats;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _clearExpiredCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除过期缓存'),
        content: const Text('确定要清除所有过期的图片缓存吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _loading = true);
    try {
      final count = await _cacheManager.clearExpiredCache();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已清除 $count 个过期缓存')),
        );
        await _loadStats();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('清除失败: $e')),
        );
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _clearAllCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除所有缓存'),
        content: const Text('确定要清除所有图片缓存吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _loading = true);
    try {
      final count = await _cacheManager.clearAllCache();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已清除 $count 个缓存')),
        );
        await _loadStats();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('清除失败: $e')),
        );
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      leading: const Icon(Icons.image),
      title: const Text('图片缓存'),
      subtitle: _loading
          ? const Text('加载中...')
          : _stats != null
              ? Text('${_stats!.validCount} 个有效缓存，${_formatBytes(_stats!.totalSize.toInt())}')
              : const Text('点击查看详情'),
      children: [
        if (_stats != null) ...[
          ListTile(
            dense: true,
            title: const Text('缓存统计'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('总数量: ${_stats!.totalCount}'),
                Text('有效: ${_stats!.validCount}'),
                Text('已过期: ${_stats!.expiredCount}'),
                Text('总大小: ${_formatBytes(_stats!.totalSize.toInt())}'),
              ],
            ),
          ),
        ],
        ListTile(
          dense: true,
          leading: const Icon(Icons.delete_outline),
          title: const Text('清除过期缓存'),
          subtitle: const Text('删除所有已过期的图片缓存'),
          onTap: _clearExpiredCache,
          enabled: !_loading,
        ),
        ListTile(
          dense: true,
          leading: const Icon(Icons.delete_forever),
          title: const Text('清除所有缓存'),
          subtitle: const Text('删除所有图片缓存'),
          onTap: _clearAllCache,
          enabled: !_loading,
        ),
        ListTile(
          dense: true,
          leading: const Icon(Icons.refresh),
          title: const Text('刷新统计'),
          onTap: _loadStats,
          enabled: !_loading,
        ),
      ],
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }
}
