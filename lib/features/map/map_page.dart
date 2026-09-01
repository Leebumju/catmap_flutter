import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/models/coordinate.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/location_repository.dart';
import '../../domain/repositories/sighting_repository.dart';
import '../../domain/repositories/storage_repository.dart';
import '../upload/bloc/upload_bloc.dart';
import '../upload/bloc/upload_event.dart';
import '../upload/bloc/upload_gate_bloc.dart';
import '../upload/upload_page.dart';
import 'bloc/map_bloc.dart';
import 'bloc/map_event.dart';
import 'bloc/map_state.dart';
import 'widgets/address_search_sheet.dart';
import 'widgets/osm_map.dart';
import 'widgets/sighting_popup.dart';

/// 지도 화면. iOS 의 `MapMainView` 와 같은 배치다 —
/// 위쪽에 검색바와 재검색 버튼, 오른쪽 아래에 내 위치 버튼과 카메라 버튼.
class MapPage extends StatefulWidget {
  const MapPage({
    super.key,
    required this.authRepository,
    required this.locationRepository,
    required this.sightingRepository,
    required this.storageRepository,
    required this.onLoginRequired,
  });

  final AuthRepository authRepository;
  final LocationRepository locationRepository;
  final SightingRepository sightingRepository;
  final StorageRepository storageRepository;

  /// 로그인이 필요할 때 부른다. 로그인 화면을 띄우는 건 앱 껍데기의 일이다.
  final VoidCallback onLoginRequired;

  /// 아직 내 위치를 모를 때 지도가 처음 보여줄 자리. iOS 기본값과 같은 서울시청.
  static const defaultCenter =
      Coordinate(latitude: 37.5666, longitude: 126.9784);

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final _mapController = MapController();
  int _handledMoveSequence = 0;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _openSearch() async {
    final mapBloc = context.read<MapBloc>();
    final place = await showAddressSearchSheet(
      context: context,
      locationRepository: widget.locationRepository,
      around: mapBloc.state.userLocation,
    );
    if (place == null) return;
    mapBloc.add(MapPlaceSelected(place.coordinate, place.name));
  }

  Future<void> _openUpload() async {
    final mapBloc = context.read<MapBloc>();
    final uploaded = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) => UploadBloc(
            authRepository: widget.authRepository,
            locationRepository: widget.locationRepository,
            sightingRepository: widget.sightingRepository,
            storageRepository: widget.storageRepository,
          )..add(const UploadStarted()),
          child: UploadPage(locationRepository: widget.locationRepository),
        ),
      ),
    );
    if (uploaded == true) mapBloc.add(const MapUploadCompleted());
  }

  void _handleGateState(BuildContext context, UploadGateState state) {
    final gate = context.read<UploadGateBloc>();

    final signal = state.signal;
    if (signal != null) {
      gate.add(const UploadGateSignalConsumed());
      switch (signal) {
        case UploadGateSignal.openCamera:
          _openUpload();
        case UploadGateSignal.loginRequired:
          widget.onLoginRequired();
        case UploadGateSignal.accountBanned:
          _showSnack('이용이 제한된 계정입니다.');
        case UploadGateSignal.checkFailed:
          _showSnack('잠시 후 다시 시도해주세요.');
      }
      return;
    }

    switch (state.alert) {
      case UploadGateAlert.limitReached:
        _showAlert(
          title: '게시물 제한',
          message: '게시물은 최대 30개까지 등록할 수 있어요.\n기존 게시물을 삭제한 후 다시 시도해주세요.',
          confirmLabel: '확인',
          onConfirm: () => gate.add(const UploadGateAlertDismissed()),
        );
      case UploadGateAlert.guide:
        _showAlert(
          title: '안내',
          message: '길고양이 사진만 올려주세요.\n관련 없거나 선정적인 사진은 신고 누적 시 계정이 제한될 수 있어요.',
          confirmLabel: '확인',
          cancelLabel: '취소',
          onConfirm: () => gate.add(const UploadGateGuideConfirmed()),
          onCancel: () => gate.add(const UploadGateAlertDismissed()),
        );
      case null:
        break;
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showAlert({
    required String title,
    required String message,
    required String confirmLabel,
    required VoidCallback onConfirm,
    String? cancelLabel,
    VoidCallback? onCancel,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          if (cancelLabel != null)
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(cancelLabel),
            ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      onConfirm();
    } else {
      (onCancel ?? onConfirm)();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<MapBloc, MapPageState>(
          listenWhen: (prev, curr) =>
              prev.moveRequest != curr.moveRequest || prev.signal != curr.signal,
          listener: (context, state) {
            final move = state.moveRequest;
            if (move != null && move.sequence != _handledMoveSequence) {
              _handledMoveSequence = move.sequence;
              _mapController.move(
                LatLng(move.coordinate.latitude, move.coordinate.longitude),
                15,
              );
            }

            final signal = state.signal;
            if (signal == null) return;
            _showSnack(switch (signal) {
              MapSignal.locationDenied => '위치 권한이 필요합니다. 설정에서 허용해주세요.',
              MapSignal.loadFailed => '목격 기록을 불러오지 못했습니다.',
            });
            context.read<MapBloc>().add(const MapSignalConsumed());
          },
        ),
        BlocListener<UploadGateBloc, UploadGateState>(
          listenWhen: (prev, curr) =>
              prev.signal != curr.signal || prev.alert != curr.alert,
          listener: _handleGateState,
        ),
      ],
      child: BlocBuilder<MapBloc, MapPageState>(
        builder: (context, state) {
          return Scaffold(
            body: Stack(
              children: [
                OsmMap(
                  controller: _mapController,
                  initialCenter: state.userLocation ?? MapPage.defaultCenter,
                  markers: _markers(context, state),
                  onPositionChanged: (center, hasGesture) {
                    if (!hasGesture) return;
                    context.read<MapBloc>().add(MapMoved(center));
                  },
                ),
                SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: _SearchBar(
                          text: state.searchText,
                          onTap: _openSearch,
                        ),
                      ),
                      if (state.showResearchButton)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: _ResearchButton(
                            onPressed: () => context
                                .read<MapBloc>()
                                .add(const MapResearchHereRequested()),
                          ),
                        ),
                    ],
                  ),
                ),
                Positioned(
                  right: 16,
                  bottom: state.selectedSighting == null ? 88 : 16,
                  child: _LocateButton(
                    onPressed: () => context
                        .read<MapBloc>()
                        .add(const MapLocateRequested()),
                  ),
                ),
                if (state.selectedSighting != null)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: SightingPopup(
                      sighting: state.selectedSighting!,
                      onDismissed: () => context
                          .read<MapBloc>()
                          .add(const MapPopupDismissed()),
                    ),
                  )
                else
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: _CameraFab(
                      onPressed: () => context
                          .read<UploadGateBloc>()
                          .add(const UploadGateCameraPressed()),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Marker> _markers(BuildContext context, MapPageState state) {
    final markers = <Marker>[];

    final userLocation = state.userLocation;
    if (userLocation != null) {
      markers.add(
        Marker(
          point: LatLng(userLocation.latitude, userLocation.longitude),
          width: 28,
          height: 28,
          child: const _UserLocationMarker(),
        ),
      );
    }

    for (final placed in spreadOverlappingMarkers(state.sightings)) {
      final isSelected = state.selectedSighting?.id == placed.sighting.id;
      markers.add(
        Marker(
          point: LatLng(
            placed.coordinate.latitude,
            placed.coordinate.longitude,
          ),
          width: 52,
          height: 52,
          child: GestureDetector(
            onTap: () =>
                context.read<MapBloc>().add(MapMarkerTapped(placed.sighting)),
            child: _CatMarker(isSelected: isSelected),
          ),
        ),
      );
    }

    return markers;
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.search, size: 16, color: Color(0xFFAAAAAA)),
            const SizedBox(width: 8),
            Text(
              text.isEmpty ? '주소 또는 장소 검색' : text,
              style: const TextStyle(fontSize: 13, color: Color(0xFF999999)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResearchButton extends StatelessWidget {
  const _ResearchButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFE8734A),
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE8734A).withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.refresh, size: 12, color: Colors.white),
            SizedBox(width: 6),
            Text(
              '이 위치에서 검색',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocateButton extends StatelessWidget {
  const _LocateButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(Icons.my_location, size: 18, color: Color(0xFF555555)),
      ),
    );
  }
}

class _CameraFab extends StatelessWidget {
  const _CameraFab({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: const Color(0xFFE8734A),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE8734A).withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.photo_camera, size: 22, color: Colors.white),
      ),
    );
  }
}

class _UserLocationMarker extends StatelessWidget {
  const _UserLocationMarker();

  static const _blue = Color(0xFF4A90E8);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: _blue.withValues(alpha: 0.2),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: _blue,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
            ),
          ),
        ),
      ),
    );
  }
}

class _CatMarker extends StatelessWidget {
  const _CatMarker({required this.isSelected});

  final bool isSelected;

  static const _selectedBlue = Color(0xFF4A90E8);

  @override
  Widget build(BuildContext context) {
    final size = isSelected ? 46.0 : 38.0;
    return Center(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? _selectedBlue : Colors.white,
            width: isSelected ? 3.5 : 2.5,
          ),
        ),
        child: ClipOval(
          child: Image.asset('assets/cat-marker.png', fit: BoxFit.cover),
        ),
      ),
    );
  }
}
