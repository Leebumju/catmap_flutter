import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/location_repository.dart';
import '../../domain/repositories/nearby_repository.dart';
import '../../domain/repositories/profile_repository.dart';
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
import '../nearby/bloc/nearby_bloc.dart';
import '../nearby/bloc/shelter_animal_bloc.dart';
import '../nearby/nearby_page.dart';
import '../profile/bloc/profile_bloc.dart';
import '../profile/bloc/profile_event.dart';
import '../profile/profile_page.dart';
import '../upload/bloc/upload_gate_bloc.dart';

/// 탭 껍데기. iOS 의 `MainTabView` 에 대응한다.
///
/// iOS 와 같은 네 개 — 피드·지도·둘러보기·내 정보.
class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.authRepository,
    required this.locationRepository,
    required this.sightingRepository,
    required this.storageRepository,
    required this.badgeRepository,
    required this.nearbyPlaceRepository,
    required this.shelterAnimalRepository,
    required this.blockRepository,
    required this.notificationSettingsRepository,
  });

  final AuthRepository authRepository;
  final LocationRepository locationRepository;
  final SightingRepository sightingRepository;
  final StorageRepository storageRepository;
  final BadgeRepository badgeRepository;
  final NearbyPlaceRepository nearbyPlaceRepository;
  final ShelterAnimalRepository shelterAnimalRepository;
  final BlockRepository blockRepository;
  final NotificationSettingsRepository notificationSettingsRepository;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tabIndex = 0;

  Future<void> _openLogin() {
    return Navigator.of(context).push<void>(
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
            child: FeedPage(onLoginRequired: _openLogin),
          ),
          MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (_) => MapBloc(
                  locationRepository: widget.locationRepository,
                  sightingRepository: widget.sightingRepository,
                  authRepository: widget.authRepository,
                  badgeRepository: widget.badgeRepository,
                )
                  ..add(const MapStarted())
                  ..add(const MapBadgesChecked()),
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
          MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (_) =>
                    NearbyBloc(locationRepository: widget.locationRepository)
                      ..add(const NearbyStarted()),
              ),
              BlocProvider(
                create: (_) =>
                    HospitalPlaceBloc(repository: widget.nearbyPlaceRepository),
              ),
              BlocProvider(
                create: (_) =>
                    PetShopPlaceBloc(repository: widget.nearbyPlaceRepository),
              ),
              BlocProvider(
                create: (_) => ShelterAnimalBloc(
                  repository: widget.shelterAnimalRepository,
                  locationRepository: widget.locationRepository,
                )..add(const ShelterAnimalStarted()),
              ),
            ],
            child: const NearbyPage(),
          ),
          BlocProvider(
            create: (_) => ProfileBloc(
              authRepository: widget.authRepository,
              sightingRepository: widget.sightingRepository,
            )..add(const ProfileStarted()),
            child: ProfilePage(
              authRepository: widget.authRepository,
              badgeRepository: widget.badgeRepository,
              blockRepository: widget.blockRepository,
              notificationSettingsRepository: widget.notificationSettingsRepository,
              sightingRepository: widget.sightingRepository,
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
          NavigationDestination(
            icon: Icon(Icons.travel_explore_outlined),
            selectedIcon: Icon(Icons.travel_explore),
            label: '둘러보기',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: '내 정보',
          ),
        ],
      ),
    );
  }
}
