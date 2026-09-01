import 'package:collection/collection.dart';
import 'package:flutter/material.dart' hide Badge;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/models/badge.dart';
import 'bloc/profile_edit_bloc.dart';
import 'profile_page.dart' show BadgeChip;

/// 프로필 편집 — 닉네임과 대표 칭호.
/// iOS 의 `ProfileEditView` + `BadgeEditView` 를 한 화면에 합쳤다.
class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({super.key});

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        TextEditingController(text: context.read<ProfileEditBloc>().state.nickname);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ProfileEditBloc, ProfileEditState>(
      listenWhen: (prev, curr) =>
          prev.savedUser != curr.savedUser ||
          prev.errorMessage != curr.errorMessage,
      listener: (context, state) {
        if (state.savedUser != null) {
          Navigator.of(context).pop(true);
          return;
        }
        final message = state.errorMessage;
        if (message == null) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      },
      builder: (context, state) {
        final bloc = context.read<ProfileEditBloc>();
        return Scaffold(
          appBar: AppBar(
            title: const Text('프로필 편집'),
            actions: [
              TextButton(
                onPressed: state.canSave
                    ? () => bloc.add(const ProfileEditSaved())
                    : null,
                child: Text(
                  state.isSaving ? '저장 중...' : '저장',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: state.canSave
                        ? const Color(0xFFE8734A)
                        : const Color(0xFFCCCCCC),
                  ),
                ),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                '닉네임',
                style: TextStyle(fontSize: 13, color: Color(0xFF888888)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _controller,
                maxLength: ProfileEditState.nicknameMaxLength,
                onChanged: (value) =>
                    bloc.add(ProfileEditNicknameChanged(value)),
                decoration: InputDecoration(
                  hintText: '닉네임을 입력하세요',
                  counterText:
                      '${state.nickname.characters.length}/${ProfileEditState.nicknameMaxLength}',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                '대표 칭호',
                style: TextStyle(fontSize: 13, color: Color(0xFF888888)),
              ),
              const SizedBox(height: 8),
              _BadgePicker(state: state),
            ],
          ),
        );
      },
    );
  }
}

class _BadgePicker extends StatelessWidget {
  const _BadgePicker({required this.state});

  final ProfileEditState state;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<ProfileEditBloc>();

    // 등급별로 묶어서 보여준다. iOS 의 BadgeEditView 와 같은 구성이다.
    final byGrade = groupBy(Badge.values, (Badge b) => b.grade);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: _SelectionMark(selected: state.selectedBadge == null),
          title: const Text('칭호 없음'),
          onTap: () => bloc.add(const ProfileEditBadgeSelected(null)),
        ),
        for (final grade in BadgeGrade.values)
          if (byGrade[grade] != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Text(
                grade.displayName,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: grade.headerColor,
                ),
              ),
            ),
            for (final badge in byGrade[grade]!)
              _BadgeRow(
                badge: badge,
                owned: state.myBadges.contains(badge),
                selected: state.selectedBadge == badge,
                onSelected: () => bloc.add(ProfileEditBadgeSelected(badge)),
              ),
          ],
      ],
    );
  }
}

class _BadgeRow extends StatelessWidget {
  const _BadgeRow({
    required this.badge,
    required this.owned,
    required this.selected,
    required this.onSelected,
  });

  final Badge badge;
  final bool owned;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      // 아직 못 딴 칭호는 흐리게 보여주고 고를 수 없게 한다.
      opacity: owned ? 1 : 0.4,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: _SelectionMark(selected: selected),
        title: BadgeChip(badge: badge),
        subtitle: Text(
          owned ? badge.conditionDescription : badge.lockedConditionDisplay,
          style: const TextStyle(fontSize: 11, color: Color(0xFF999999)),
        ),
        onTap: owned ? onSelected : null,
      ),
    );
  }
}

/// 고른 항목 표시. 라디오 버튼 대신 동그라미/체크로 보여준다.
class _SelectionMark extends StatelessWidget {
  const _SelectionMark({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Icon(
      selected ? Icons.check_circle : Icons.circle_outlined,
      size: 22,
      color: selected ? const Color(0xFFE8734A) : const Color(0xFFCCCCCC),
    );
  }
}
