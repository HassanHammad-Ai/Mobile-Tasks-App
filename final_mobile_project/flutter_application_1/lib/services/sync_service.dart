import '../models/item.dart';
import '../database/items_database.dart';
import 'firestore_service.dart';
import 'connectivity_service.dart';

/// Handles synchronization between local SQLite and Firebase Firestore
class SyncService {
  static final SyncService instance = SyncService._internal();
  SyncService._internal();

  final _localDb = ItemsDatabase.instance;
  final _firestore = FirestoreService.instance;
  final _connectivity = ConnectivityService.instance;

  // ─── ADD ITEM: Save to BOTH local and cloud ──────────────────────────────

  Future<void> addItem(Item item) async {
    // ALWAYS save to local database FIRST (instant)
    await _localDb.insertItem(item);
    print('✅ Item saved to local database');

    // Then try to sync to Firestore in background
    _syncItemToCloud(item);
  }

  // Background sync (doesn't block UI)
  Future<void> _syncItemToCloud(Item item) async {
    final hasInternet = await _connectivity.hasConnection();
    if (hasInternet) {
      try {
        await _firestore.addItem(item);
        print('✅ Item synced to Firestore');
      } catch (e) {
        print('⚠️ Failed to sync to Firestore: $e');
      }
    } else {
      print('📱 Offline: Item saved locally only');
    }
  }

  // ─── GET ITEMS: ALWAYS from local, sync in background ────────────────────

  Future<List<Item>> getItems(String userId) async {
    // ALWAYS get from local database first (instant display)
    final localItems = await _localDb.getItemsByUserId(userId);
    print('📱 Loaded ${localItems.length} items from local database');

    // Then sync from cloud in background
    _syncFromCloud(userId);

    return localItems;
  }

  // Background sync from cloud
  Future<void> _syncFromCloud(String userId) async {
    final hasInternet = await _connectivity.hasConnection();

    if (hasInternet) {
      try {
        print('🌐 Syncing from Firestore in background...');
        final cloudItems = await _firestore.getItemsByUserId(userId);

        // Update local database with cloud data
        for (var item in cloudItems) {
          await _localDb.insertItem(item);
        }

        print('✅ Synced ${cloudItems.length} items from Firestore');
      } catch (e) {
        print('⚠️ Background sync failed: $e');
      }
    }
  }

  // ─── GET FAVORITES: ALWAYS from local, sync in background ────────────────

  Future<List<Item>> getFavorites(String userId) async {
    // ALWAYS get from local database first
    final localFavorites = await _localDb.getFavoriteItems(userId);
    print('📱 Loaded ${localFavorites.length} favorites from local database');

    // Sync from cloud in background
    _syncFavoritesFromCloud(userId);

    return localFavorites;
  }

  // Background sync favorites
  Future<void> _syncFavoritesFromCloud(String userId) async {
    final hasInternet = await _connectivity.hasConnection();

    if (hasInternet) {
      try {
        final cloudFavorites = await _firestore.getFavoriteItems(userId);

        for (var item in cloudFavorites) {
          await _localDb.insertItem(item);
        }

        print('✅ Synced favorites from Firestore');
      } catch (e) {
        print('⚠️ Failed to sync favorites: $e');
      }
    }
  }

  // ─── UPDATE ITEM: Update BOTH ─────────────────────────────────────────────

  Future<void> updateItem(Item item) async {
    // Update local first
    await _localDb.updateItem(item);
    print('✅ Item updated in local database');

    // Sync to cloud in background
    _updateItemInCloud(item);
  }

  Future<void> _updateItemInCloud(Item item) async {
    final hasInternet = await _connectivity.hasConnection();
    if (hasInternet) {
      try {
        await _firestore.updateItem(item);
        print('✅ Item update synced to Firestore');
      } catch (e) {
        print('⚠️ Failed to sync update: $e');
      }
    }
  }

  // ─── TOGGLE FAVORITE: Update BOTH ────────────────────────────────────────
  // Update local first
  Future<void> toggleFavorite(String itemId, bool isFavorite) async {
    await _localDb.toggleFavorite(itemId, isFavorite);
    print('✅ Favorite toggled in local database');

    // Sync to cloud in background
    _toggleFavoriteInCloud(itemId, isFavorite);
  }

  Future<void> _toggleFavoriteInCloud(String itemId, bool isFavorite) async {
    final hasInternet = await _connectivity.hasConnection();
    if (hasInternet) {
      try {
        await _firestore.toggleFavorite(itemId, isFavorite);
        print('✅ Favorite status synced to Firestore');
      } catch (e) {
        print('⚠️ Failed to sync favorite: $e');
      }
    }
  }

  // ─── DELETE ITEM: Delete from BOTH ───────────────────────────────────────

  Future<void> deleteItem(String itemId) async {
    // Delete from local first
    await _localDb.deleteItem(itemId);
    print('✅ Item deleted from local database');

    // Delete from cloud in background
    _deleteItemFromCloud(itemId);
  }

  Future<void> _deleteItemFromCloud(String itemId) async {
    final hasInternet = await _connectivity.hasConnection();
    if (hasInternet) {
      try {
        await _firestore.deleteItem(itemId);
        print('✅ Item deletion synced to Firestore');
      } catch (e) {
        print('⚠️ Failed to sync deletion: $e');
      }
    }
  }

  // ─── GET ITEM COUNT ───────────────────────────────────────────────────────

  Future<int> getItemCount(String userId) async {
    // Always use local count for instant display
    return await _localDb.getItemCount(userId);
  }

  // ─── FORCE SYNC: Manually sync all local data to cloud ───────────────────

  Future<void> syncAllToCloud(String userId) async {
    final hasInternet = await _connectivity.hasConnection();
    if (!hasInternet) {
      print('📱 Cannot sync: No internet connection');
      return;
    }

    try {
      final localItems = await _localDb.getItemsByUserId(userId);
      print('🔄 Syncing ${localItems.length} items to Firestore...');

      for (var item in localItems) {
        try {
          await _firestore.addItem(item);
        } catch (e) {
          print('⚠️ Failed to sync item ${item.id}: $e');
        }
      }

      print('✅ All items synced to Firestore');
    } catch (e) {
      print('⚠️ Sync failed: $e');
    }
  }

  // ─── PULL FROM CLOUD: Force refresh from Firestore ───────────────────────

  Future<List<Item>> pullFromCloud(String userId) async {
    final hasInternet = await _connectivity.hasConnection();
    if (!hasInternet) {
      print('📱 No internet: Using local data');
      return await _localDb.getItemsByUserId(userId);
    }

    try {
      print('🌐 Pulling latest data from Firestore...');
      final cloudItems = await _firestore.getItemsByUserId(userId);

      // Clear local and replace with cloud data
      await _localDb.deleteAllUserItems(userId);
      for (var item in cloudItems) {
        await _localDb.insertItem(item);
      }

      print('✅ Pulled ${cloudItems.length} items from Firestore');
      return cloudItems;
    } catch (e) {
      print('⚠️ Failed to pull from cloud: $e');
      return await _localDb.getItemsByUserId(userId);
    }
  }
}
