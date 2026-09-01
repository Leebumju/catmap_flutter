import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/models/cat_type.dart';
import '../bloc/upload_bloc.dart';
import '../bloc/upload_event.dart';
import '../bloc/upload_state.dart';
import 'upload_colors.dart';

/// 게시물 작성 단계. iOS 의 `MemoInputView` 와 같은 구성이다.
class MemoStep extends StatefulWidget {
  const MemoStep({super.key, required this.onOpenLocationPicker});

  final VoidCallback onOpenLocationPicker;

  @override
  State<MemoStep> createState() => _MemoStepState();
}

class _MemoStepState extends State<MemoStep> {
  late final TextEditingController _memoController;

  @override
  void initState() {
    super.initState();
    _memoController =
        TextEditingController(text: context.read<UploadBloc>().state.memo);
  }

  @override
  void dispose() {
    _memoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<UploadBloc, UploadState>(
      builder: (context, state) {
        final bloc = context.read<UploadBloc>();
        return Stack(
          children: [
            Column(
              children: [
                _Header(
                  isUploading: state.isUploading,
                  canSubmit: state.canSubmit,
                  onBack: () => bloc.add(const UploadBackToCamera()),
                  onSubmit: () => bloc.add(const UploadSubmitted()),
                ),
                const Divider(height: 1, color: Colors.white12),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    children: [
                      _PhotoStrip(
                        state: state,
                        onRemove: (i) => bloc.add(UploadPhotoRemoved(i)),
                      ),
                      const SizedBox(height: 16),
                      _CatTypeSelector(
                        catType: state.catType,
                        onChanged: (type) => bloc.add(UploadCatTypeChanged(type)),
                      ),
                      if (state.catType == CatType.domestic) ...[
                        const SizedBox(height: 8),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            '집냥이는 지도에 표시되지 않고 피드에만 노출되며, 위치는 저장되지 않습니다',
                            style: TextStyle(fontSize: 12, color: Colors.white38),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      _MemoField(
                        controller: _memoController,
                        length: state.memo.length,
                        onChanged: (value) => bloc.add(UploadMemoChanged(value)),
                      ),
                      if (state.catType == CatType.stray) ...[
                        const SizedBox(height: 16),
                        _LocationRow(
                          address: state.locationAddress,
                          source: state.locationSource,
                          onAdjust: widget.onOpenLocationPicker,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (state.isUploading) const _UploadingOverlay(),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.isUploading,
    required this.canSubmit,
    required this.onBack,
    required this.onSubmit,
  });

  final bool isUploading;
  final bool canSubmit;
  final VoidCallback onBack;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            onPressed: isUploading ? null : onBack,
            icon: const Icon(Icons.chevron_left, color: Colors.white),
          ),
          const Spacer(),
          const Text(
            '게시물 작성',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: canSubmit ? onSubmit : null,
            child: Text(
              '등록',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: canSubmit ? UploadColors.accent : Colors.white24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoStrip extends StatelessWidget {
  const _PhotoStrip({required this.state, required this.onRemove});

  final UploadState state;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: state.photos.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          return Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  state.photos[index],
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: -6,
                right: -6,
                child: GestureDetector(
                  onTap: () => onRemove(index),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.remove_circle,
                        size: 20, color: Colors.red),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CatTypeSelector extends StatelessWidget {
  const _CatTypeSelector({required this.catType, required this.onChanged});

  final CatType catType;
  final ValueChanged<CatType> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget button(CatType type, String label) {
      final isSelected = catType == type;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(type),
          child: Container(
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? UploadColors.accent : UploadColors.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? Colors.white : Colors.white54,
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          button(CatType.stray, '🐱 길냥이'),
          button(CatType.domestic, '🏠 집냥이'),
        ],
      ),
    );
  }
}

class _MemoField extends StatelessWidget {
  const _MemoField({
    required this.controller,
    required this.length,
    required this.onChanged,
  });

  final TextEditingController controller;
  final int length;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          TextField(
            controller: controller,
            onChanged: onChanged,
            maxLines: 5,
            minLines: 3,
            maxLength: UploadState.memoMaxLength,
            style: const TextStyle(fontSize: 14, color: Colors.white),
            decoration: InputDecoration(
              counterText: '',
              hintText: '메모를 입력하세요 (선택사항)',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: UploadColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$length/${UploadState.memoMaxLength}',
            style: const TextStyle(fontSize: 11, color: Colors.white30),
          ),
        ],
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({
    required this.address,
    required this.source,
    required this.onAdjust,
  });

  final String address;
  final UploadLocationSource source;
  final VoidCallback onAdjust;

  @override
  Widget build(BuildContext context) {
    final sourceLabel = switch (source) {
      UploadLocationSource.photo => '📸 사진 촬영 위치로 설정됨',
      UploadLocationSource.current => '📍 현재 위치로 설정됨',
      UploadLocationSource.manual => '🗺️ 직접 선택한 위치',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: UploadColors.accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  address.isEmpty ? '위치 확인 중...' : address,
                  style: const TextStyle(fontSize: 13, color: Colors.white70),
                ),
              ),
              TextButton(
                onPressed: onAdjust,
                child: const Text(
                  '위치 조정',
                  style: TextStyle(fontSize: 12, color: UploadColors.accent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Text(
              sourceLabel,
              style: const TextStyle(fontSize: 11, color: Colors.white38),
            ),
          ),
        ],
      ),
    );
  }
}

class _UploadingOverlay extends StatelessWidget {
  const _UploadingOverlay();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black54,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: UploadColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 12),
              Text('등록 중...',
                  style: TextStyle(fontSize: 14, color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}
