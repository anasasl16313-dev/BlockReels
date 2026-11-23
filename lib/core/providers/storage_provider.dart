import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/preferences_storage.dart';
import '../storage/storage_repository.dart';

/// Provider for the singleton [StorageRepository] instance.
/// Overridden in main or tests with an initialized [HiveStorageRepository] or mock.
final storageRepositoryProvider = Provider<StorageRepository>((ref) {
  throw UnimplementedError(
    'storageRepositoryProvider must be initialized with an instance of StorageRepository.',
  );
});

/// Provider for the [PreferencesStorage] bootstrap key-value service.
final preferencesStorageProvider = Provider<PreferencesStorage?>((ref) => null);
