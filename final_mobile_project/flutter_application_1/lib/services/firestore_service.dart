import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/item.dart';

/// Handles all Firestore operations for cloud storage
class FirestoreService {
  static final FirestoreService instance = FirestoreService._internal();
  FirestoreService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection reference
  CollectionReference get _itemsCollection => _firestore.collection('items');

  // ─── CREATE: Add item to Firestore ───────────────────────────────────────

  Future<void> addItem(Item item) async {
    try {
      await _itemsCollection.doc(item.id).set({
        'item_id': item.id,
        'user_id': item.userId,
        'title': item.title,
        'body': item.body,
        'image_paths': item.imagePaths,
        'created_at': item.createdAt.toIso8601String(),
        'favorite': item.favorite,
      });
    } catch (e) {
      print('Error adding item to Firestore: $e');
      rethrow;
    }
  }

  // ─── READ: Get all items for user ─────────────────────────────────────────

  Future<List<Item>> getItemsByUserId(String userId) async {
    try {
      print('🔍 Querying Firestore for user_id: $userId');

      // Use .get() instead of real-time listener
      final querySnapshot =
          await _itemsCollection
              .where('user_id', isEqualTo: userId)
              .get(); // REMOVED .orderBy() to avoid index requirement

      print('📊 Found ${querySnapshot.docs.length} documents in Firestore');

      // Sort in memory instead
      final items =
          querySnapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return Item(
              id: data['item_id'],
              userId: data['user_id'],
              title: data['title'],
              body: data['body'],
              imagePaths: List<String>.from(data['image_paths'] ?? []),
              createdAt: DateTime.parse(data['created_at']),
              favorite: data['favorite'] ?? false,
            );
          }).toList();

      // Sort by date in memory (newest first)
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return items;
    } catch (e) {
      print('❌ Error getting items from Firestore: $e');
      return [];
    }
  }

  // ─── READ: Get favorite items ─────────────────────────────────────────────

  Future<List<Item>> getFavoriteItems(String userId) async {
    try {
      // Use .get() and filter in memory
      final querySnapshot =
          await _itemsCollection
              .where('user_id', isEqualTo: userId)
              .get(); // REMOVED .where('favorite') and .orderBy()

      final items =
          querySnapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return Item(
              id: data['item_id'],
              userId: data['user_id'],
              title: data['title'],
              body: data['body'],
              imagePaths: List<String>.from(data['image_paths'] ?? []),
              createdAt: DateTime.parse(data['created_at']),
              favorite: data['favorite'] ?? false,
            );
          }).toList();

      // Filter favorites in memory
      final favorites = items.where((item) => item.favorite).toList();

      // Sort by date
      favorites.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return favorites;
    } catch (e) {
      print('❌ Error getting favorites from Firestore: $e');
      return [];
    }
  }

  // ─── UPDATE: Update item ──────────────────────────────────────────────────

  Future<void> updateItem(Item item) async {
    try {
      await _itemsCollection.doc(item.id).update({
        'title': item.title,
        'body': item.body,
        'image_paths': item.imagePaths,
        'favorite': item.favorite,
      });
    } catch (e) {
      print('Error updating item in Firestore: $e');
      rethrow;
    }
  }

  // ─── UPDATE: Toggle favorite ──────────────────────────────────────────────

  Future<void> toggleFavorite(String itemId, bool isFavorite) async {
    try {
      await _itemsCollection.doc(itemId).update({'favorite': isFavorite});
    } catch (e) {
      print('Error toggling favorite in Firestore: $e');
      rethrow;
    }
  }

  // ─── DELETE: Remove item ──────────────────────────────────────────────────

  Future<void> deleteItem(String itemId) async {
    try {
      await _itemsCollection.doc(itemId).delete();
    } catch (e) {
      print('Error deleting item from Firestore: $e');
      rethrow;
    }
  }

  // ─── DELETE: Remove all user items ────────────────────────────────────────

  Future<void> deleteAllUserItems(String userId) async {
    try {
      final querySnapshot =
          await _itemsCollection.where('user_id', isEqualTo: userId).get();
      final batch = _firestore.batch();
      for (var doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      print('Error deleting all user items from Firestore: $e');
      rethrow;
    }
  }

  // ─── COUNT: Get item count ────────────────────────────────────────────────

  Future<int> getItemCount(String userId) async {
    try {
      final querySnapshot =
          await _itemsCollection.where('user_id', isEqualTo: userId).get();
      return querySnapshot.docs.length;
    } catch (e) {
      print('Error counting items in Firestore: $e');
      return 0;
    }
  }
}
