import 'package:equatable/equatable.dart';

enum SyncStatus { idle, syncing, success, offline, error }

class SyncState extends Equatable {
  final SyncStatus status;
  final String? message;
  final DateTime? lastSyncedAt;
  final int itemsPushed;
  final int itemsPulled;

  const SyncState({
    required this.status,
    this.message,
    this.lastSyncedAt,
    this.itemsPushed = 0,
    this.itemsPulled = 0,
  });

  factory SyncState.initial() {
    return const SyncState(
      status: SyncStatus.idle,
    );
  }

  SyncState copyWith({
    SyncStatus? status,
    String? message,
    DateTime? lastSyncedAt,
    int? itemsPushed,
    int? itemsPulled,
  }) {
    return SyncState(
      status: status ?? this.status,
      message: message ?? this.message,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      itemsPushed: itemsPushed ?? this.itemsPushed,
      itemsPulled: itemsPulled ?? this.itemsPulled,
    );
  }

  @override
  List<Object?> get props => [status, message, lastSyncedAt, itemsPushed, itemsPulled];
}

class SyncResult {
  final bool success;
  final int itemsCount;
  final String message;

  const SyncResult({
    required this.success,
    required this.itemsCount,
    required this.message,
  });
}
