import 'dart:convert';

class Item {
  final String id;
  final String userId; // Firebase user ID
  final String title;
  final String body;
  final List<String> imagePaths; // Paths to local images
  final DateTime createdAt;
  final bool favorite;

  Item({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.imagePaths,
    required this.createdAt,
    this.favorite = false,
  });

  /// Convert Item to Map for SQLite storage
  Map<String, dynamic> toMap() {
    return {
      'item_id': id,
      'user_id': userId,
      'title': title,
      'body': body,
      'image_paths': jsonEncode(imagePaths), // Store as JSON string
      'created_at': createdAt.toIso8601String(),
      'favorite': favorite ? 1 : 0,
    };
  }

  /// Create Item from SQLite Map
  factory Item.fromMap(Map<String, dynamic> map) {
    return Item(
      id: map['item_id'],
      userId: map['user_id'],
      title: map['title'],
      body: map['body'],
      imagePaths: List<String>.from(jsonDecode(map['image_paths'])),
      createdAt: DateTime.parse(map['created_at']),
      favorite: map['favorite'] == 1,
    );
  }

  /// Create a copy with some fields changed
  Item copyWith({
    String? id,
    String? userId,
    String? title,
    String? body,
    List<String>? imagePaths,
    DateTime? createdAt,
    bool? favorite,
  }) {
    return Item(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      body: body ?? this.body,
      imagePaths: imagePaths ?? this.imagePaths,
      createdAt: createdAt ?? this.createdAt,
      favorite: favorite ?? this.favorite,
    );
  }
}
