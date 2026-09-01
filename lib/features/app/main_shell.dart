import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/location_repository.dart';
import '../../domain/repositories/sighting_repository.dart';
import '../../domain/repositories/storage_repository.dart';
import '../auth/auth_page.dart';
import '../auth/bloc/auth_bloc.dart';
import '../auth/bloc/auth_event.dart';
import '../feed/bloc/feed_bloc.dart';
import '../feed/bloc/feed_event.dart';
import '../feed/feed_page.dart';
import '../map/bloc/map_bloc.dart';
import '../map/bloc/map_event.dart';
import '../map/map_page.dart';
import '../upload/bloc/upload_gate_bloc.dart';

/// 탭 두 개(피드 / 지도)를 담는 껍데기.
///
/// iOS 는 탭이 넷(피드·지도·둘러보기·내 정보)이다. 이번 이식 범위가 지도·업로드까지라
/// 옮긴 화면만 탭으로 둔다 — 빈 화면으로 이어지는 탭을 만들지 않는다.
class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.authRepository,
    required this.locationRepository,
    required this.sightingRepository,
    required this.storageRepository,
  });

  final AuthRepository authRepository;
  final LocationRepository locationRepository;
  final SightingRepository sightingRepository;
  final StorageRepository storageRepository;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tabIndex = 0;

  void _openLogin() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => BlocProvider(
          create: (_) => AuthBloc(authRepository: widget.authRepository)
            ..add(const AuthStarted()),
          child: const AuthPage(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tabIndex,
        children: [
          BlocProvider(
            create: (_) => FeedBloc(
              sightingRepository: widget.sightingRepository,
              authRepository: widget.authRepository,
            )..add(const FeedStarted()),
            child: const FeedPage(),
          ),
          MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (_) => MapBloc(
                  locationRepository: widget.locationRepository,
                  sightingRepository: widget.sightingRepository,
                )..add(const MapStarted()),
              ),
              BlocProvider(
                create: (_) => UploadGateBloc(
                  authRepository: widget.authRepository,
                  sightingRepository: widget.sightingRepository,
                ),
              ),
            ],
            child: MapPage(
              authRepository: widget.authRepository,
              locationRepository: widget.locationRepository,
              sightingRepository: widget.sightingRepository,
              storageRepository: widget.storageRepository,
              onLoginRequired: _openLogin,
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (index) => setState(() => _tabIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dynamic_feed_outlined),
            selectedIcon: Icon(Icons.dynamic_feed),
            label: '피드',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: '지도',
          ),
        ],
      ),
    );
  }
}
