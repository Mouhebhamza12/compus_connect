import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:compus_connect/utilities/friendly_error.dart';

class NotificationsState {
  final AsyncValue<List<Map<String, dynamic>>> items;
  final bool markingAll;

  const NotificationsState({
    this.items = const AsyncValue.loading(),
    this.markingAll = false,
  });

  NotificationsState copyWith({
    AsyncValue<List<Map<String, dynamic>>>? items,
    bool? markingAll,
  }) {
    return NotificationsState(
      items: items ?? this.items,
      markingAll: markingAll ?? this.markingAll,
    );
  }
}

class NotificationsNotifier extends StateNotifier<NotificationsState> {
  NotificationsNotifier() : super(const NotificationsState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(items: const AsyncValue.loading());
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      state = state.copyWith(
        items: AsyncValue.error(
          Exception("Not signed in"),
          StackTrace.current,
        ),
      );
      return;
    }

    try {
      final res = await Supabase.instance.client
          .from('notifications')
          .select('id, title, body, type, read, created_at')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);
      final list = (res as List).cast<Map<String, dynamic>>();
      state = state.copyWith(items: AsyncValue.data(list));
    } on PostgrestException catch (e, st) {
      if (e.code == '42P01') {
        state = state.copyWith(items: const AsyncValue.data([]));
        return;
      }
      state = state.copyWith(items: AsyncValue.error(e, st));
    } catch (e, st) {
      state = state.copyWith(items: AsyncValue.error(e, st));
    }
  }

  Future<void> refresh() async {
    await load();
  }

  Future<void> markRead(String id) async {
    final items = _currentItems();
    final index = items.indexWhere((n) => n['id'].toString() == id);
    if (index == -1) return;

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final updated = [...items];
    updated[index] = {...updated[index], 'read': true};
    state = state.copyWith(items: AsyncValue.data(updated));

    try {
      await Supabase.instance.client
          .from('notifications')
          .update({'read': true})
          .eq('id', id)
          .eq('user_id', userId);
    } catch (_) {
      // Best-effort: we already updated the local state.
    }
  }

  Future<void> markAllRead() async {
    if (state.markingAll) return;
    final items = _currentItems();
    final hasUnread = items.any((n) => !(n['read'] as bool? ?? false));
    if (!hasUnread) return;

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    state = state.copyWith(markingAll: true);

    try {
      await Supabase.instance.client
          .from('notifications')
          .update({'read': true})
          .eq('read', false)
          .eq('user_id', userId);
      final updated =
          items.map((n) => {...n, 'read': true}).toList(growable: false);
      state = NotificationsState(
        items: AsyncValue.data(updated),
        markingAll: false,
      );
    } catch (_) {
      state = state.copyWith(
        markingAll: false,
        items: AsyncValue.data(items),
      );
    }
  }

  Future<bool> deleteNotification(String id) async {
    final items = _currentItems();
    final index = items.indexWhere((n) => n['id'].toString() == id);
    if (index == -1) return false;

    final removed = items[index];
    final updated = [...items]..removeAt(index);
    state = state.copyWith(items: AsyncValue.data(updated));

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      state = state.copyWith(
        items: AsyncValue.error(Exception("Not signed in"), StackTrace.current),
      );
      return false;
    }

    try {
      await Supabase.instance.client
          .from('notifications')
          .delete()
          .eq('id', id)
          .eq('user_id', userId);
      return true;
    } catch (_) {
      state = state.copyWith(items: AsyncValue.data(items));
      return false;
    }
  }

  List<Map<String, dynamic>> _currentItems() {
    return List<Map<String, dynamic>>.from(
      state.items.asData?.value ?? const [],
    );
  }
}

final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, NotificationsState>(
  (ref) => NotificationsNotifier(),
);

class AlertsPage extends ConsumerWidget {
  const AlertsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        title: const Text("Notifications"),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F2A44),
        elevation: 0.5,
        actions: [
          state.items.when(
            data: (items) {
              final hasUnread =
                  items.any((n) => !(n['read'] as bool? ?? false));
              return IconButton(
                tooltip: "Mark all as read",
                onPressed: !state.markingAll && hasUnread
                    ? () =>
                        ref.read(notificationsProvider.notifier).markAllRead()
                    : null,
                icon: state.markingAll
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.done_all, color: Color(0xFF1F4E79)),
              );
            },
            loading: () => const IconButton(
              onPressed: null,
              icon: Icon(Icons.done_all, color: Color(0xFF1F4E79)),
            ),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(notificationsProvider.notifier).refresh(),
        child: state.items.when(
          loading: () => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
          ),
          error: (err, _) => _error(err),
          data: (list) {
            if (list.isEmpty) return _empty();
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _dismissibleCard(context, ref, list[i]),
            );
          },
        ),
      ),
    );
  }

  Widget _dismissibleCard(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> n,
  ) {
    return Dismissible(
      key: ValueKey(n['id']),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFE94E77).withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline, color: Color(0xFFE94E77)),
      ),
      confirmDismiss: (_) async {
        final ok = await ref
            .read(notificationsProvider.notifier)
            .deleteNotification(n['id'].toString());
        if (!ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Could not delete notification.")),
          );
          return false;
        }
        return true;
      },
      child: _card(ref, n),
    );
  }

  Widget _card(WidgetRef ref, Map<String, dynamic> n) {
    final isRead = n['read'] as bool? ?? false;
    final type = (n['type'] ?? 'info').toString();
    final created = (n['created_at'] ?? '').toString();

    Color color;
    IconData icon;
    switch (type) {
      case 'course':
        color = const Color(0xFF4F8EF7);
        icon = Icons.menu_book;
        break;
      case 'exam':
        color = const Color(0xFFE94E77);
        icon = Icons.assignment;
        break;
      case 'assignment':
        color = const Color(0xFF7B61FF);
        icon = Icons.task_alt;
        break;
      case 'request':
        color = const Color(0xFF50C2C9);
        icon = Icons.request_page;
        break;
      default:
        color = const Color(0xFF1F4E79);
        icon = Icons.notifications;
    }

    return InkWell(
      onTap: () async {
        if (!isRead) {
          await ref
              .read(notificationsProvider.notifier)
              .markRead(n['id'].toString());
        }
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE0E6ED)),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          n['title']?.toString() ?? 'Notification',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F2A44),
                            decoration: isRead
                                ? TextDecoration.none
                                : TextDecoration.none,
                          ),
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFFE94E77),
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    n['body']?.toString() ?? '',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF4B5A6B),
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    created.split('.').first.replaceFirst('T', ' '),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF7A8CA3),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty() {
    return ListView(
      padding: const EdgeInsets.all(24),
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(height: 40),
        Icon(
          Icons.notifications_off_outlined,
          size: 48,
          color: Color(0xFF7A8CA3),
        ),
        SizedBox(height: 12),
        Center(
          child: Text(
            'No notifications yet.',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F2A44),
            ),
          ),
        ),
        SizedBox(height: 6),
        Center(
          child: Text(
            'New courses, exams, and assignments will show up here.',
            style: TextStyle(fontSize: 13, color: Color(0xFF7A8CA3)),
          ),
        ),
      ],
    );
  }

  Widget _error(Object? error) {
    final message = friendlyError(error ?? Exception('Unknown error'), fallback: 'Please try again.');
    return ListView(
      padding: const EdgeInsets.all(24),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 40),
        const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
        const SizedBox(height: 12),
        const Center(
          child: Text(
            'Could not load notifications.',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F2A44),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Color(0xFF7A8CA3)),
          ),
        ),
      ],
    );
  }
}
