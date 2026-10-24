import 'json_helpers.dart';

class Notice {
  const Notice({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.publishDate,
    required this.status,
    required this.createdBy,
    required this.createdAt,
    this.expiryDate,
    this.imagePath,
    this.imageUrl,
    this.createdByName,
  });

  final String id;
  final String title;
  final String description;
  final String category;
  final String? imagePath;
  final String? imageUrl; // short-lived signed URL
  final DateTime publishDate;
  final DateTime? expiryDate;
  final String status;
  final String createdBy;
  final String? createdByName;
  final DateTime createdAt;

  bool get isExpired =>
      expiryDate != null &&
      expiryDate!.isBefore(DateTime.now().subtract(const Duration(days: 1)));

  Notice copyWith({String? imageUrl}) => Notice(
        id: id,
        title: title,
        description: description,
        category: category,
        publishDate: publishDate,
        status: status,
        createdBy: createdBy,
        createdAt: createdAt,
        expiryDate: expiryDate,
        imagePath: imagePath,
        imageUrl: imageUrl ?? this.imageUrl,
        createdByName: createdByName,
      );

  factory Notice.fromMap(Map<String, dynamic> m) {
    final creator = m['creator'];
    return Notice(
      id: m['id'] as String,
      title: m['title'] as String,
      description: str(m['description']),
      category: str(m['category'], 'General'),
      imagePath: m['image_path'] as String?,
      publishDate: DateTime.parse(m['publish_date'] as String),
      expiryDate: m['expiry_date'] == null
          ? null
          : DateTime.parse(m['expiry_date'] as String),
      status: m['status'] as String,
      createdBy: m['created_by'] as String,
      createdByName: creator is Map ? creator['full_name'] as String? : null,
      createdAt: parseDt(m['created_at']),
    );
  }
}
