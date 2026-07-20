import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../auth/auth_controller.dart';

class SavedDestinationsState {
  const SavedDestinationsState({
    this.ids = const <int>{},
    this.initialized = false,
    this.loading = false,
  });

  final Set<int> ids;
  final bool initialized;
  final bool loading;

  bool contains(int id) => ids.contains(id);
}

final savedDestinationsProvider =
    NotifierProvider<SavedDestinationsController, SavedDestinationsState>(
      SavedDestinationsController.new,
    );

class SavedDestinationsController extends Notifier<SavedDestinationsState> {
  @override
  SavedDestinationsState build() {
    final authenticated = ref.watch(authProvider).authenticated;
    if (authenticated) Future.microtask(load);
    return const SavedDestinationsState();
  }

  Future<void> load({bool force = false}) async {
    if (!ref.read(authProvider).authenticated) {
      state = const SavedDestinationsState(initialized: true);
      return;
    }
    if (state.loading || (state.initialized && !force)) return;
    state = SavedDestinationsState(
      ids: state.ids,
      initialized: state.initialized,
      loading: true,
    );
    try {
      final response = await ref.read(dioProvider).get('/saved/ids');
      final ids = _destinationIds(response.data);
      state = SavedDestinationsState(ids: ids, initialized: true);
    } catch (_) {
      state = SavedDestinationsState(ids: state.ids, initialized: true);
    }
  }

  Future<void> toggle(int id) async {
    if (id <= 0) return;
    final wasSaved = state.ids.contains(id);
    final optimistic = Set<int>.from(state.ids);
    wasSaved ? optimistic.remove(id) : optimistic.add(id);
    state = SavedDestinationsState(ids: optimistic, initialized: true);
    try {
      await ref.read(dioProvider).post('/saved/destinations/$id/toggle');
      await load(force: true);
    } catch (error) {
      final reverted = Set<int>.from(state.ids);
      wasSaved ? reverted.add(id) : reverted.remove(id);
      state = SavedDestinationsState(ids: reverted, initialized: true);
      rethrow;
    }
  }
}

Set<int> _destinationIds(dynamic body) {
  dynamic value = body;
  if (value is Map && value['data'] != null) value = value['data'];
  if (value is Map && value['data'] != null) value = value['data'];
  if (value is! Map) return <int>{};
  final source =
      value['destinations'] ??
      value['destination_ids'] ??
      value['saved_destinations'];
  if (source is! List) return <int>{};
  return source
      .map((entry) {
        final raw = entry is Map
            ? entry['travel_destination_id'] ??
                  entry['destination_id'] ??
                  entry['id']
            : entry;
        return int.tryParse('$raw') ?? 0;
      })
      .where((id) => id > 0)
      .toSet();
}
