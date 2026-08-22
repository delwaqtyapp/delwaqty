import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:delwaqty/features/driver/domain/entities/wallet_detail.dart';
import 'package:delwaqty/features/driver/driver_module.dart';

final driverWalletDetailProvider =
    FutureProvider.family<WalletDetail, String>((ref, driverId) {
      return ref.watch(driverRepositoryProvider).getWalletDetail(driverId);
    });
