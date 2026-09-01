import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/models/coordinate.dart';
import '../../domain/repositories/location_repository.dart';
import 'bloc/upload_bloc.dart';
import 'bloc/upload_event.dart';
import 'bloc/upload_state.dart';
import 'location_picker_page.dart';
import 'widgets/camera_step.dart';
import 'widgets/crop_step.dart';
import 'widgets/memo_step.dart';
import 'widgets/upload_colors.dart';

/// 사진 등록 화면. iOS 의 `CameraView` 처럼 한 화면 안에서 단계만 바꾼다.
///
/// 등록이 끝나면 true 를 돌려주며 닫힌다 — 지도는 그 신호로 목록을 다시 받는다.
class UploadPage extends StatelessWidget {
  const UploadPage({super.key, required this.locationRepository});

  final LocationRepository locationRepository;

  /// 위치를 못 잡았을 때 위치 조정 화면이 처음 보여줄 자리. iOS 와 같은 서울시청.
  static const _defaultCoordinate =
      Coordinate(latitude: 37.5666, longitude: 126.9784);

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<UploadBloc, UploadState>(
      listenWhen: (prev, curr) =>
          prev.signal != curr.signal ||
          prev.isCompleted != curr.isCompleted ||
          prev.isLocationPickerOpen != curr.isLocationPickerOpen,
      listener: (context, state) async {
        if (state.isCompleted) {
          Navigator.of(context).pop(true);
          return;
        }

        if (state.isLocationPickerOpen) {
          final picked = await Navigator.of(context).push<Coordinate>(
            MaterialPageRoute(
              builder: (_) => LocationPickerPage(
                initialCoordinate: state.location ?? _defaultCoordinate,
                locationRepository: locationRepository,
              ),
            ),
          );
          if (!context.mounted) return;
          final bloc = context.read<UploadBloc>();
          if (picked == null) {
            bloc.add(const UploadLocationPickerDismissed());
          } else {
            bloc.add(UploadLocationAdjusted(picked));
          }
          return;
        }

        final signal = state.signal;
        if (signal == null) return;
        final message = switch (signal) {
          UploadSignal.photoLimitReached => '사진은 3장까지 올릴 수 있어요.',
          UploadSignal.notLoggedIn => '로그인이 필요합니다.',
          UploadSignal.uploadFailed => '업로드에 실패했습니다. 잠시 후 다시 시도해주세요.',
        };
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
        context.read<UploadBloc>().add(const UploadSignalConsumed());
      },
      builder: (context, state) {
        return PopScope(
          // 등록 중에는 뒤로 나가지 못하게 막는다. 중간에 나가면 사진만 올라가고
          // 게시물은 안 만들어진 상태가 서버에 남는다.
          canPop: !state.isUploading,
          child: Scaffold(
            backgroundColor: UploadColors.background,
            body: SafeArea(child: _body(context, state)),
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, UploadState state) {
    switch (state.step) {
      case UploadStep.camera:
        return CameraStep(onClose: () => Navigator.of(context).pop(false));
      case UploadStep.crop:
        final index = state.cropPhotoIndex.clamp(0, state.photos.length - 1);
        return CropStep(
          key: ValueKey(index),
          bytes: state.photos[index],
          index: index,
          totalCount: state.photos.length,
          onBack: () => context.read<UploadBloc>().add(const UploadBackToCamera()),
        );
      case UploadStep.memo:
        return MemoStep(
          onOpenLocationPicker: () => context
              .read<UploadBloc>()
              .add(const UploadAdjustLocationRequested()),
        );
    }
  }
}
