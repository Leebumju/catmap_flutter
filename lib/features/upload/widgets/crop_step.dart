import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/upload_bloc.dart';
import '../bloc/upload_event.dart';
import '../crop_geometry.dart';

/// 사진 자르기 단계. 정사각형 창 안에서 끌고 확대해 원하는 부분을 고른다.
/// iOS 의 `PhotoCropView`(UIScrollView 기반)와 같은 조작이다.
class CropStep extends StatefulWidget {
  const CropStep({
    super.key,
    required this.bytes,
    required this.index,
    required this.totalCount,
    required this.onBack,
  });

  final Uint8List bytes;
  final int index;
  final int totalCount;
  final VoidCallback onBack;

  @override
  State<CropStep> createState() => _CropStepState();
}

class _CropStepState extends State<CropStep> {
  final _transformationController = TransformationController();
  Size? _sourceSize;
  bool _isCropping = false;
  bool _didCenter = false;

  /// 크롭 창과 화면 사이 여백. iOS 는 짧은 변에서 32 를 뺐다.
  static const _padding = 32.0;

  @override
  void initState() {
    super.initState();
    _loadSize();
  }

  @override
  void didUpdateWidget(CropStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 다음 사진으로 넘어가면 확대·이동을 처음 상태로 되돌린다.
    if (oldWidget.index != widget.index) {
      _transformationController.value = Matrix4.identity();
      _sourceSize = null;
      _didCenter = false;
      _loadSize();
    }
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  Future<void> _loadSize() async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(widget.bytes);
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    final size = Size(
      descriptor.width.toDouble(),
      descriptor.height.toDouble(),
    );
    descriptor.dispose();
    buffer.dispose();
    if (!mounted) return;
    setState(() => _sourceSize = size);
  }

  /// 사진을 크롭 창 가운데에 놓는다. 창 크기를 알아야 계산되므로 첫 배치 뒤에 부른다.
  void _centerImage(Size source, double cropSide) {
    final fitted = CropGeometry.fittedSize(source: source, cropSide: cropSide);
    _transformationController.value = CropGeometry.initialTransform(
      fitted: fitted,
      cropSide: cropSide,
    );
  }

  Future<void> _done(double cropSide) async {
    final source = _sourceSize;
    if (source == null || _isCropping) return;
    setState(() => _isCropping = true);

    final fitted = CropGeometry.fittedSize(source: source, cropSide: cropSide);
    final rect = CropGeometry.visibleSourceRect(
      transform: _transformationController.value,
      source: source,
      fitted: fitted,
      cropSide: cropSide,
    );

    try {
      final cropped = await cropImageBytes(widget.bytes, rect);
      if (!mounted) return;
      context.read<UploadBloc>().add(UploadCropCompleted(widget.index, cropped));
    } catch (_) {
      // 자르기에 실패하면 원본 그대로 넘긴다 — 사용자를 막지 않는다.
      if (!mounted) return;
      context.read<UploadBloc>().add(const UploadCropSkipped());
    } finally {
      if (mounted) setState(() => _isCropping = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final source = _sourceSize;
    final title = widget.totalCount > 1
        ? '크롭 (${widget.index + 1}/${widget.totalCount})'
        : '크롭';

    return LayoutBuilder(
      builder: (context, constraints) {
        final cropSide =
            (constraints.maxWidth < constraints.maxHeight
                    ? constraints.maxWidth
                    : constraints.maxHeight) -
                _padding;

        // 사진 크기를 처음 알게 된 프레임에서 가운데로 맞춘다.
        if (source != null && !_didCenter) {
          _didCenter = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _centerImage(source, cropSide);
          });
        }

        return Stack(
          children: [
            Center(
              child: SizedBox(
                width: cropSide,
                height: cropSide,
                child: source == null
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white))
                    : ClipRect(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            InteractiveViewer(
                              transformationController: _transformationController,
                              constrained: false,
                              minScale: 1,
                              maxScale: 5,
                              child: SizedBox.fromSize(
                                size: CropGeometry.fittedSize(
                                  source: source,
                                  cropSide: cropSide,
                                ),
                                child: Image.memory(
                                  widget.bytes,
                                  fit: BoxFit.fill,
                                ),
                              ),
                            ),
                            const IgnorePointer(child: _RuleOfThirdsGrid()),
                          ],
                        ),
                      ),
              ),
            ),
            _TopBar(
              title: title,
              onBack: widget.onBack,
              onSkip: () =>
                  context.read<UploadBloc>().add(const UploadCropSkipped()),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 32,
              child: Center(
                child: FilledButton(
                  onPressed: source == null || _isCropping
                      ? null
                      : () => _done(cropSide),
                  child: Text(_isCropping ? '자르는 중...' : '완료'),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.onBack,
    required this.onSkip,
  });

  final String title;
  final VoidCallback onBack;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.chevron_left, color: Colors.white),
          ),
          const Spacer(),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: onSkip,
            child: const Text(
              '건너뛰기',
              style: TextStyle(fontSize: 14, color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}

/// 3분할 안내선. iOS 크롭 오버레이와 같다.
class _RuleOfThirdsGrid extends StatelessWidget {
  const _RuleOfThirdsGrid();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _GridPainter(), child: const SizedBox.expand());
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..strokeWidth = 0.5;
    final border = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (var i = 1; i < 3; i++) {
      final x = size.width / 3 * i;
      final y = size.height / 3 * i;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
    canvas.drawRect(Offset.zero & size, border);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
