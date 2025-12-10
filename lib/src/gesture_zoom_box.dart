import 'package:flutter/material.dart';

/// 手势缩放盒子
/// 支持双击缩放功能
class GestureZoomBox extends StatefulWidget {
  final Widget child;

  const GestureZoomBox({super.key, required this.child});

  @override
  State<GestureZoomBox> createState() => _GestureZoomBoxState();
}

class _GestureZoomBoxState extends State<GestureZoomBox>
    with SingleTickerProviderStateMixin {
  final TransformationController _transformationController =
      TransformationController();
  late AnimationController _animationController;
  Animation<Matrix4>? _animation;
  TapDownDetails? _doubleTapDetails;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..addListener(() {
        _transformationController.value = _animation!.value;
      });
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _handleDoubleTapDown(TapDownDetails details) {
    _doubleTapDetails = details;
  }

  void _handleDoubleTap() {
    if (_animationController.isAnimating) {
      return;
    }

    final Matrix4 endMatrix;
    final Offset position = _doubleTapDetails!.localPosition;

    if (_transformationController.value != Matrix4.identity()) {
      // 如果已经缩放，恢复到原始大小
      endMatrix = Matrix4.identity();
    } else {
      // 缩放到2倍
      endMatrix = Matrix4.identity()
        ..translate(-position.dx, -position.dy)
        ..scale(2.0);
    }

    _animation = Matrix4Tween(
      begin: _transformationController.value,
      end: endMatrix,
    ).animate(
      CurveTween(curve: Curves.easeOut).animate(_animationController),
    );

    _animationController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: _handleDoubleTapDown,
      onDoubleTap: _handleDoubleTap,
      child: InteractiveViewer(
        transformationController: _transformationController,
        minScale: 1.0,
        maxScale: 4.0,
        child: widget.child,
      ),
    );
  }
}
