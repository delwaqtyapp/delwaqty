import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/data/datasources/local/biometric_auth_store.dart';

class DeviceLockState {
  const DeviceLockState({
    required this.unlocked,
    required this.hasDeviceAccount,
  });

  final bool unlocked;
  final bool hasDeviceAccount;

  DeviceLockState copyWith({
    bool? unlocked,
    bool? hasDeviceAccount,
  }) {
    return DeviceLockState(
      unlocked: unlocked ?? this.unlocked,
      hasDeviceAccount: hasDeviceAccount ?? this.hasDeviceAccount,
    );
  }
}

final deviceLockProvider =
    NotifierProvider<DeviceLockNotifier, DeviceLockState>(
  DeviceLockNotifier.new,
);

class DeviceLockNotifier extends Notifier<DeviceLockState> {
  @override
  DeviceLockState build() {
    return const DeviceLockState(unlocked: false, hasDeviceAccount: false);
  }

  /// Called once at cold start to detect whether a device account
  /// (locally stored credentials) exists so the App Lock gate can be shown.
  Future<void> init() async {
    final hasCreds =
        await ref.read(biometricAuthStoreProvider).hasAnyCredentials();
    state = DeviceLockState(
      unlocked: false,
      hasDeviceAccount: hasCreds,
    );
  }

  /// Marks the app as unlocked. Called after a successful device-credential
  /// verification OR a manual password sign-in.
  void markUnlocked() {
    state = state.copyWith(unlocked: true);
  }
}
