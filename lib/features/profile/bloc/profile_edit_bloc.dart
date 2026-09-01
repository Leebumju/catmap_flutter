import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/models/app_user.dart';
import '../../../domain/models/badge.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../../domain/repositories/profile_repository.dart';

sealed class ProfileEditEvent extends Equatable {
  const ProfileEditEvent();

  @override
  List<Object?> get props => [];
}

final class ProfileEditStarted extends ProfileEditEvent {
  const ProfileEditStarted();
}

final class ProfileEditNicknameChanged extends ProfileEditEvent {
  const ProfileEditNicknameChanged(this.nickname);

  final String nickname;

  @override
  List<Object?> get props => [nickname];
}

/// 대표 칭호 선택. null 은 "칭호 없음".
final class ProfileEditBadgeSelected extends ProfileEditEvent {
  const ProfileEditBadgeSelected(this.badge);

  final Badge? badge;

  @override
  List<Object?> get props => [badge];
}

final class ProfileEditSaved extends ProfileEditEvent {
  const ProfileEditSaved();
}

class ProfileEditState extends Equatable {
  const ProfileEditState({
    required this.nickname,
    required this.originalNickname,
    this.selectedBadge,
    this.originalBadge,
    this.myBadges = const [],
    this.isSaving = false,
    this.savedUser,
    this.errorMessage,
  });

  /// 닉네임 최대 길이. iOS 와 같은 20자.
  static const nicknameMaxLength = 20;

  final String nickname;
  final String originalNickname;
  final Badge? selectedBadge;
  final Badge? originalBadge;
  final List<Badge> myBadges;
  final bool isSaving;

  /// 저장이 끝나면 갱신된 사용자가 담긴다. 화면은 이걸 보고 닫는다.
  final AppUser? savedUser;

  final String? errorMessage;

  bool get hasChanges =>
      nickname != originalNickname || selectedBadge != originalBadge;

  bool get isNicknameValid {
    final trimmed = nickname.trim();
    return trimmed.isNotEmpty && trimmed.length <= nicknameMaxLength;
  }

  bool get canSave => hasChanges && isNicknameValid && !isSaving;

  ProfileEditState copyWith({
    String? nickname,
    Badge? selectedBadge,
    List<Badge>? myBadges,
    bool? isSaving,
    AppUser? savedUser,
    String? errorMessage,
    bool clearSelectedBadge = false,
    bool clearError = false,
  }) {
    return ProfileEditState(
      nickname: nickname ?? this.nickname,
      originalNickname: originalNickname,
      selectedBadge: clearSelectedBadge ? null : (selectedBadge ?? this.selectedBadge),
      originalBadge: originalBadge,
      myBadges: myBadges ?? this.myBadges,
      isSaving: isSaving ?? this.isSaving,
      savedUser: savedUser ?? this.savedUser,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
        nickname,
        originalNickname,
        selectedBadge,
        originalBadge,
        myBadges,
        isSaving,
        savedUser,
        errorMessage,
      ];
}

/// 프로필 편집(닉네임 · 대표 칭호). iOS 의 `ProfileEditFeature` 와 같다.
class ProfileEditBloc extends Bloc<ProfileEditEvent, ProfileEditState> {
  ProfileEditBloc({
    required AuthRepository authRepository,
    required BadgeRepository badgeRepository,
    required AppUser user,
  })  : _auth = authRepository,
        _badges = badgeRepository,
        super(ProfileEditState(
          nickname: user.nickname ?? '',
          originalNickname: user.nickname ?? '',
          selectedBadge: user.representativeBadge,
          originalBadge: user.representativeBadge,
        )) {
    on<ProfileEditStarted>(_onStarted);
    on<ProfileEditNicknameChanged>((e, emit) =>
        emit(state.copyWith(nickname: e.nickname, clearError: true)));
    on<ProfileEditBadgeSelected>(_onBadgeSelected);
    on<ProfileEditSaved>(_onSaved, transformer: droppable());
  }

  final AuthRepository _auth;
  final BadgeRepository _badges;

  Future<void> _onStarted(
    ProfileEditStarted event,
    Emitter<ProfileEditState> emit,
  ) async {
    try {
      final badges = await _badges.fetchMyBadges();
      emit(state.copyWith(myBadges: badges));
    } catch (_) {
      // 칭호를 못 읽어도 닉네임은 고칠 수 있어야 한다.
    }
  }

  void _onBadgeSelected(
    ProfileEditBadgeSelected event,
    Emitter<ProfileEditState> emit,
  ) {
    final badge = event.badge;
    // 가지고 있지 않은 칭호는 고를 수 없다. iOS 와 같은 가드다.
    if (badge != null && !state.myBadges.contains(badge)) return;
    emit(state.copyWith(
      selectedBadge: badge,
      clearSelectedBadge: badge == null,
      clearError: true,
    ));
  }

  Future<void> _onSaved(
    ProfileEditSaved event,
    Emitter<ProfileEditState> emit,
  ) async {
    if (!state.canSave) return;
    emit(state.copyWith(isSaving: true, clearError: true));

    try {
      if (state.nickname != state.originalNickname) {
        await _auth.updateNickname(state.nickname.trim());
      }
      if (state.selectedBadge != state.originalBadge) {
        final badge = state.selectedBadge;
        if (badge == null) {
          await _badges.unsetRepresentative();
        } else {
          await _badges.setRepresentative(badge);
        }
      }

      // 둘 다 반영된 최신 사용자를 다시 읽는다. iOS 와 같은 순서다.
      final user = await _auth.currentUser();
      if (user == null) {
        emit(state.copyWith(isSaving: false, errorMessage: '프로필을 가져올 수 없습니다.'));
        return;
      }
      emit(state.copyWith(isSaving: false, savedUser: user));
    } catch (_) {
      emit(state.copyWith(
        isSaving: false,
        errorMessage: '저장에 실패했습니다. 잠시 후 다시 시도해주세요.',
      ));
    }
  }
}
