import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/core/config/app_mode_provider.dart';
import 'package:delwaqty/features/_shared/auth/domain/auth_state.dart';
import 'package:delwaqty/features/_shared/auth/presentation/auth_provider.dart';
import 'package:delwaqty/services/supabase/supabase_service.dart';

List<AppFlavor> parseAppInvitations(Object? raw) {
  if (raw is! Map || raw['channels'] is! List) return const [];
  final channels = (raw['channels'] as List).whereType<String>().toSet();
  return [
    for (final flavor in [
      AppFlavor.provider,
      AppFlavor.driver,
      AppFlavor.admin,
    ])
      if (channels.contains(flavor.name)) flavor,
  ];
}

final appInvitationsProvider = FutureProvider.autoDispose<List<AppFlavor>>((
  ref,
) async {
  final auth = ref.watch(authStateProvider);
  if (auth is! AuthAuthenticated) return const [];
  return parseAppInvitations(
    await ref.watch(supabaseClientProvider).rpc('get_my_app_invitations'),
  );
});
