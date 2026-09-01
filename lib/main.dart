import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/geo_location_repository.dart';
import 'data/supabase_auth_repository.dart';
import 'data/supabase_profile_repositories.dart';
import 'data/supabase_sighting_repository.dart';
import 'data/supabase_storage_repository.dart';
import 'features/app/bloc/session_bloc.dart';
import 'features/app/main_shell.dart';

/// 키는 소스에 넣지 않는다. 실행·빌드할 때 넘긴다:
///   ./run.sh            (개발)
///   ./build_android.sh  (배포)
const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

/// 주소·장소 검색에 쓰는 카카오 로컬 REST 키.
/// iOS 는 지도 검색을 MapKit 으로 하지만 안드로이드에는 그게 없어서 필요하다.
const kakaoRestApiKey = String.fromEnvironment('KAKAO_REST_API_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // publishableKey / anonKey 는 SDK 안에서 같은 키로 합쳐진다(effectiveKey).
  // anonKey 는 deprecated 라 새 이름을 쓴다 — 기존 anon 키를 그대로 넘겨도 동작이 같다.
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseAnonKey);
  runApp(const CatMapApp());
}

class CatMapApp extends StatelessWidget {
  const CatMapApp({super.key});

  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;

    final authRepository = SupabaseAuthRepository(client);
    final sightingRepository = SupabaseSightingRepository(client);
    final storageRepository = SupabaseStorageRepository(client);
    final locationRepository =
        GeoLocationRepository(kakaoRestApiKey: kakaoRestApiKey);
    final badgeRepository = SupabaseBadgeRepository(client);
    final blockRepository = SupabaseBlockRepository(client);
    final notificationSettingsRepository =
        SupabaseNotificationSettingsRepository(client);

    return MaterialApp(
      title: '봤냥',
      theme: ThemeData(colorSchemeSeed: Colors.orange, useMaterial3: true),
      // iOS 는 UIUserInterfaceStyle 을 Light 로 고정한다. 여기도 다크 테마를 두지 않아
      // 기기 설정과 무관하게 같은 화면이 나온다.
      home: BlocProvider(
        create: (_) => SessionBloc(authRepository: authRepository)
          ..add(const SessionStarted()),
        child: MainShell(
          authRepository: authRepository,
          locationRepository: locationRepository,
          sightingRepository: sightingRepository,
          storageRepository: storageRepository,
          badgeRepository: badgeRepository,
          blockRepository: blockRepository,
          notificationSettingsRepository: notificationSettingsRepository,
        ),
      ),
    );
  }
}
