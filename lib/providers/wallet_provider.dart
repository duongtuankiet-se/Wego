import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/wallet.dart';
import '../models/wallet_transaction.dart';
import '../services/wallet_service.dart';
import 'auth_provider.dart';
import 'mongo_provider.dart';

part 'wallet_provider.g.dart';

@Riverpod(keepAlive: true)
WalletService walletService(Ref ref) =>
    WalletService(ref.watch(mongoServiceProvider));

/// Phase 5Q: current user's wallet doc from Mongo. Auto-creates the
/// wallet on first read so screens never have to worry about a
/// missing wallet (e.g. session restore for accounts that pre-dated
/// the wallet system).
@riverpod
Future<Wallet?> currentUserWallet(Ref ref) async {
  final user = await ref.watch(authStateProvider.future);
  if (user == null) return null;
  final svc = ref.watch(walletServiceProvider);
  return svc.getOrCreate(userId: user.id, userRole: user.role.name);
}

@riverpod
Future<List<WalletTransaction>> walletHistory(Ref ref) async {
  final user = await ref.watch(authStateProvider.future);
  if (user == null) return const [];
  final svc = ref.watch(walletServiceProvider);
  return svc.getHistory(userId: user.id);
}
