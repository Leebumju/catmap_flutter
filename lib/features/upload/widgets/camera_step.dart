import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../bloc/upload_bloc.dart';
import '../bloc/upload_event.dart';
import '../bloc/upload_state.dart';
import 'upload_colors.dart';

/// 촬영 단계. iOS 의 `CameraContentView` 와 같은 배치다.
///
/// iOS 와 마찬가지로 셔터는 사진이 하나도 없을 때만 보이고, 한 장이라도 찍으면
/// 그 자리가 "다음" 버튼으로 바뀐다. 두 장째부터는 갤러리에서 고른다.
class CameraStep extends StatefulWidget {
  const CameraStep({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  State<CameraStep> createState() => _CameraStepState();
}

class _CameraStepState extends State<CameraStep> with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  bool _isInitializing = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setUpCamera(useFront: false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 앱이 내려가면 카메라를 놓아준다. 안 놓으면 다른 앱이 카메라를 못 쓰고,
    // 돌아왔을 때 미리보기가 검은 화면으로 굳는다.
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      controller.dispose();
      _controller = null;
    } else if (state == AppLifecycleState.resumed) {
      _setUpCamera(useFront: context.read<UploadBloc>().state.isUsingFrontCamera);
    }
  }

  Future<void> _setUpCamera({required bool useFront}) async {
    setState(() {
      _isInitializing = true;
      _error = null;
    });
    try {
      if (_cameras.isEmpty) _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() {
          _isInitializing = false;
          _error = '사용할 수 있는 카메라가 없습니다.';
        });
        return;
      }

      final description = _cameras.firstWhere(
        (c) =>
            c.lensDirection ==
            (useFront ? CameraLensDirection.front : CameraLensDirection.back),
        orElse: () => _cameras.first,
      );

      final controller = CameraController(
        description,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      await _applyFlash(controller);
      setState(() {
        _controller = controller;
        _isInitializing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _error = '카메라를 열 수 없습니다. 권한을 확인해주세요.';
      });
    }
  }

  Future<void> _applyFlash(CameraController controller) async {
    final isFlashOn = context.read<UploadBloc>().state.isFlashOn;
    try {
      await controller.setFlashMode(isFlashOn ? FlashMode.torch : FlashMode.off);
    } catch (_) {
      // 전면 카메라 등 플래시가 없는 기기에서는 무시한다.
    }
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isTakingPicture) return;
    try {
      final file = await controller.takePicture();
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      context.read<UploadBloc>().add(UploadPhotoCaptured(bytes));
    } catch (_) {
      // 촬영 실패는 조용히 넘긴다 — 다시 누르면 된다.
    }
  }

  Future<void> _pickFromGallery(int remaining) async {
    final picker = ImagePicker();
    final files = await picker.pickMultiImage(limit: remaining);
    if (files.isEmpty || !mounted) return;
    final photos = <Uint8List>[];
    for (final file in files.take(remaining)) {
      photos.add(await file.readAsBytes());
    }
    if (!mounted || photos.isEmpty) return;
    context.read<UploadBloc>().add(UploadGalleryPhotosSelected(photos));
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<UploadBloc, UploadState>(
      builder: (context, state) {
        return Column(
          children: [
            _TopBar(
              isFlashOn: state.isFlashOn,
              onClose: widget.onClose,
              onFlashToggle: () async {
                context.read<UploadBloc>().add(const UploadFlashToggled());
                final controller = _controller;
                if (controller == null) return;
                try {
                  await controller.setFlashMode(
                    state.isFlashOn ? FlashMode.off : FlashMode.torch,
                  );
                } catch (_) {
                  // 플래시가 없는 카메라
                }
              },
            ),
            Expanded(child: _preview()),
            const SizedBox(height: 16),
            _PhotoThumbnails(
              photos: state.photos,
              onRemove: (index) =>
                  context.read<UploadBloc>().add(UploadPhotoRemoved(index)),
            ),
            const SizedBox(height: 20),
            _Controls(
              hasPhotos: state.photos.isNotEmpty,
              canTakeMore: state.canTakeMore,
              remaining: UploadState.maxPhotos - state.photoCount,
              onShutter: _capture,
              onGallery: _pickFromGallery,
              onFlip: () {
                context.read<UploadBloc>().add(const UploadCameraFlipped());
                _setUpCamera(useFront: !state.isUsingFrontCamera);
              },
              onNext: () =>
                  context.read<UploadBloc>().add(const UploadNextRequested()),
            ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  Widget _preview() {
    final error = _error;
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            error,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ),
      );
    }

    final controller = _controller;
    if (_isInitializing || controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: controller.value.previewSize?.height ?? 1,
            height: controller.value.previewSize?.width ?? 1,
            child: CameraPreview(controller),
          ),
        ),
        const _ViewfinderOverlay(),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.isFlashOn,
    required this.onClose,
    required this.onFlashToggle,
  });

  final bool isFlashOn;
  final VoidCallback onClose;
  final VoidCallback onFlashToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _CircleButton(icon: Icons.close, onPressed: onClose),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              '발견한 길고양이를 찍어주세요 🐱',
              style: TextStyle(fontSize: 12, color: Colors.white),
            ),
          ),
          const Spacer(),
          _CircleButton(
            icon: isFlashOn ? Icons.flash_on : Icons.flash_off,
            color: isFlashOn ? Colors.yellow : Colors.white,
            onPressed: onFlashToggle,
          ),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.onPressed,
    this.color = Colors.white,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}

/// 뷰파인더의 네 모서리 괄호. iOS 의 `ViewfinderOverlay` 와 같은 크기(짧은 변의 60%)다.
class _ViewfinderOverlay extends StatelessWidget {
  const _ViewfinderOverlay();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side =
            (constraints.maxWidth < constraints.maxHeight
                    ? constraints.maxWidth
                    : constraints.maxHeight) *
                0.6;
        return Center(
          child: SizedBox(
            width: side,
            height: side,
            child: CustomPaint(painter: _CornerBracketPainter()),
          ),
        );
      },
    );
  }
}

class _CornerBracketPainter extends CustomPainter {
  static const _length = 20.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = UploadColors.accent
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path()
      // 좌상
      ..moveTo(0, _length)
      ..lineTo(0, 0)
      ..lineTo(_length, 0)
      // 우상
      ..moveTo(size.width - _length, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, _length)
      // 좌하
      ..moveTo(0, size.height - _length)
      ..lineTo(0, size.height)
      ..lineTo(_length, size.height)
      // 우하
      ..moveTo(size.width - _length, size.height)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width, size.height - _length);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PhotoThumbnails extends StatelessWidget {
  const _PhotoThumbnails({required this.photos, required this.onRemove});

  final List<Uint8List> photos;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(UploadState.maxPhotos, (index) {
        final child = index < photos.length
            ? GestureDetector(
                onTap: () => onRemove(index),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    photos[index],
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                  ),
                ),
              )
            : Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: UploadColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white24),
                ),
                child: index == photos.length
                    ? const Icon(Icons.add, size: 12, color: Colors.white38)
                    : null,
              );
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: child,
        );
      }),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.hasPhotos,
    required this.canTakeMore,
    required this.remaining,
    required this.onShutter,
    required this.onGallery,
    required this.onFlip,
    required this.onNext,
  });

  final bool hasPhotos;
  final bool canTakeMore;
  final int remaining;
  final VoidCallback onShutter;
  final void Function(int remaining) onGallery;
  final VoidCallback onFlip;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          GestureDetector(
            onTap: remaining > 0 ? () => onGallery(remaining) : null,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: UploadColors.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.photo_library_outlined,
                  size: 20, color: Colors.white54),
            ),
          ),
          const Spacer(),
          if (hasPhotos)
            GestureDetector(
              onTap: onNext,
              child: Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: UploadColors.accent,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_forward,
                    size: 22, color: Colors.white),
              ),
            )
          else
            GestureDetector(
              onTap: canTakeMore ? onShutter : null,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24, width: 4),
                ),
                child: Center(
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          const Spacer(),
          GestureDetector(
            onTap: onFlip,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cameraswitch_outlined,
                  size: 20, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
