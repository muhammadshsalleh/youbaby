import 'package:intl/intl.dart';

class BabyPhoto {
  final String id;
  final String photoUrl;
  final DateTime createdAt;
  final String? caption;
  final List<String> tags;
  final String? milestone;
  bool isFavorite;

  BabyPhoto({
    required this.id,
    required this.photoUrl,
    required this.createdAt,
    this.caption,
    this.tags = const [],
    this.milestone,
    this.isFavorite = false,
  });

  factory BabyPhoto.fromJson(Map<String, dynamic> json) {
    return BabyPhoto(
      id: json['id'].toString(),
      photoUrl: json['photo_url'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      caption: json['caption'] as String?,
      milestone: json['milestone'] as String?,
      isFavorite: json['is_favorite'] ?? false,
      tags: [], // We'll populate this separately from photo_tags
    );
  }

  String get formattedDate => DateFormat('MMMM d, y').format(createdAt);
}

class FilterOptions {
  DateTime? startDate;
  DateTime? endDate;
  List<String> selectedTags;
  bool showOnlyMilestones;
  bool showOnlyFavorites;
  String? captionSearch;
  String sortBy;

  FilterOptions({
    this.startDate,
    this.endDate,
    this.selectedTags = const [],
    this.showOnlyMilestones = false,
    this.showOnlyFavorites = false,
    this.captionSearch,
    this.sortBy = 'newest',
  });

  void reset() {
    startDate = null;
    endDate = null;
    selectedTags = [];
    showOnlyMilestones = false;
    showOnlyFavorites = false;
    captionSearch = null;
    sortBy = 'newest';
  }
}