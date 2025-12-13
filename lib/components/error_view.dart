import 'package:flutter/material.dart';

/// 错误视图组件
/// 支持堆栈信息折叠/展开，以及刷新功能
class ErrorView extends StatefulWidget {
  final String error;
  final VoidCallback onRetry;

  const ErrorView({
    super.key,
    required this.error,
    required this.onRetry,
  });

  @override
  State<ErrorView> createState() => _ErrorViewState();
}

class _ErrorViewState extends State<ErrorView> {
  bool _showStack = false;

  /// 解析错误信息，分离主要错误和堆栈信息
  Map<String, String> _parseError(String error) {
    // 查找堆栈信息的开始位置（按优先级排序）
    final stackStartPatterns = [
      'Stack backtrace:',
      '\nStack backtrace:',
      'Stack:',
      '\nStack:',
      '\n  0:',
      '\n   0:',
      '\nat ',
    ];

    String mainError = error;
    String stackTrace = '';

    // 优先查找 "Stack backtrace:"
    int stackIndex = error.indexOf('Stack backtrace:');
    if (stackIndex == -1) {
      stackIndex = error.indexOf('\nStack backtrace:');
    }
    
    if (stackIndex != -1) {
      mainError = error.substring(0, stackIndex).trim();
      stackTrace = error.substring(stackIndex).trim();
    } else {
      // 查找其他堆栈模式
      for (final pattern in stackStartPatterns) {
        final index = error.indexOf(pattern);
        if (index != -1) {
          mainError = error.substring(0, index).trim();
          stackTrace = error.substring(index).trim();
          break;
        }
      }
    }

    return {
      'main': mainError,
      'stack': stackTrace,
    };
  }

  @override
  Widget build(BuildContext context) {
    final parsed = _parseError(widget.error);
    final hasStack = parsed['stack']?.isNotEmpty ?? false;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              '加载失败',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            // 主要错误信息
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                parsed['main'] ?? widget.error,
                textAlign: TextAlign.left,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 14,
                ),
              ),
            ),
            // 堆栈信息（可折叠）
            if (hasStack) ...[
              const SizedBox(height: 12),
              InkWell(
                onTap: () {
                  setState(() {
                    _showStack = !_showStack;
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _showStack ? '隐藏详情' : '查看详情',
                        style: const TextStyle(
                          color: Colors.blue,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _showStack
                            ? Icons.expand_less
                            : Icons.expand_more,
                        size: 20,
                        color: Colors.blue,
                      ),
                    ],
                  ),
                ),
              ),
              if (_showStack) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    parsed['stack'] ?? '',
                    textAlign: TextAlign.left,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 24),
            // 刷新按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: widget.onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('刷新'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}



