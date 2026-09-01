import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/models/coordinate.dart';
import '../../../domain/repositories/location_repository.dart';
import '../bloc/address_search_bloc.dart';

/// 주소 검색 시트를 띄우고, 고른 장소를 돌려준다(취소하면 null).
Future<SearchedPlace?> showAddressSearchSheet({
  required BuildContext context,
  required LocationRepository locationRepository,
  Coordinate? around,
}) {
  return Navigator.of(context).push<SearchedPlace>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => BlocProvider(
        create: (_) => AddressSearchBloc(
          locationRepository: locationRepository,
          around: around,
        ),
        child: const _AddressSearchPage(),
      ),
    ),
  );
}

/// iOS 의 `AddressSearchView` 와 같은 화면이다.
class _AddressSearchPage extends StatefulWidget {
  const _AddressSearchPage();

  @override
  State<_AddressSearchPage> createState() => _AddressSearchPageState();
}

class _AddressSearchPageState extends State<_AddressSearchPage> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('주소 검색'),
        leading: TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('닫기'),
        ),
        leadingWidth: 64,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _controller,
              autofocus: true,
              autocorrect: false,
              onChanged: (value) {
                // 지우기 버튼은 입력값 유무로 나타났다 사라지므로 여기서도 다시 그린다.
                setState(() {});
                context
                    .read<AddressSearchBloc>()
                    .add(AddressSearchQueryChanged(value));
              },
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search,
                    size: 18, color: Color(0xFFAAAAAA)),
                hintText: '주소 또는 장소 검색',
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.cancel,
                            size: 18, color: Color(0xFFCCCCCC)),
                        onPressed: () {
                          _controller.clear();
                          context
                              .read<AddressSearchBloc>()
                              .add(const AddressSearchQueryChanged(''));
                        },
                      ),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: BlocBuilder<AddressSearchBloc, AddressSearchState>(
              builder: (context, state) {
                if (state.isSearching) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state.results.isEmpty && !state.isQueryTooShort) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.location_off,
                            size: 32, color: Color(0xFFCCCCCC)),
                        SizedBox(height: 8),
                        Text('검색 결과가 없습니다',
                            style: TextStyle(
                                fontSize: 14, color: Color(0xFFAAAAAA))),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: state.results.length,
                  itemBuilder: (context, index) {
                    final place = state.results[index];
                    return ListTile(
                      leading: const Icon(Icons.place,
                          size: 20, color: Color(0xFFE8734A)),
                      title: Text(
                        place.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF222222),
                        ),
                      ),
                      subtitle: Text(
                        place.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF999999)),
                      ),
                      onTap: () => Navigator.of(context).pop(place),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
