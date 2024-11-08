import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'album_add.dart';
import 'album_babyphoto.dart';
import 'album_fullscreenviewer.dart';

class QuickFilter {
  final String id;
  final IconData icon;
  final String label;
  bool isActive;

  QuickFilter({
    required this.id,
    required this.icon,
    required this.label,
    this.isActive = false,
  });
}

class BabyAlbumPage extends StatefulWidget {
  final int userID;

  const BabyAlbumPage({super.key, required this.userID});

  @override
  _BabyAlbumPageState createState() => _BabyAlbumPageState();
}

class _BabyAlbumPageState extends State<BabyAlbumPage> {
  bool _isPlayingSlideshow = false;
  bool _isLoading = true;
  int _currentIndex = 0;
  final PageController _pageController = PageController();
  List<BabyPhoto> photos = [];
  List<BabyPhoto> filteredPhotos = [];
  String? _albumId;
  String? _albumName;
  String? _coverPhotoUrl;
  final FilterOptions _filterOptions = FilterOptions();
  final List<String> _availableTags = [];

  final List<QuickFilter> _quickFilters = [
    QuickFilter(
      id: 'recent',
      icon: Icons.access_time,
      label: 'Recent',
    ),
    QuickFilter(
      id: 'favorites',
      icon: Icons.favorite,
      label: 'Favorites',
    ),
    QuickFilter(
      id: 'milestones',
      icon: Icons.stars,
      label: 'Milestones',
    ),
  ];

  List<String> _activeFilters = [];

  @override
  void initState() {
    super.initState();
    _fetchPhotos();
  }

  Future<void> _fetchPhotos() async {
    try {
      final albumResponse = await Supabase.instance.client
          .from('albums')
          .select()
          .eq('baby_id', widget.userID)
          .single();

      if (albumResponse == null) {
        setState(() {
          _isLoading = false;
          photos = [];
          filteredPhotos = [];
        });
        return;
      }

      setState(() {
        _albumId = albumResponse['id'] as String;
        _albumName = albumResponse['name'] as String;
        _coverPhotoUrl = albumResponse['cover_photo_url'] as String?;
      });

      final photosResponse = await Supabase.instance.client
          .from('albums_photos')
          .select('''
            *,
            albums_photo_tags (
              albums_tags (
                name
              )
            )
          ''')
          .eq('album_id', _albumId as Object)
          .order('created_at', ascending: false);

      if (photosResponse != null) {
        final List<BabyPhoto> fetchedPhotos = [];
        final Set<String> tags = {};

        for (var photoData in photosResponse) {
          List<String> photoTags = [];
          if (photoData['albums_photo_tags'] != null) {
            for (var tagData in photoData['albums_photo_tags']) {
              if (tagData['albums_tags'] != null) {
                final tagName = tagData['albums_tags']['name'];
                photoTags.add(tagName);
                tags.add(tagName);
              }
            }
          }

          BabyPhoto photo = BabyPhoto(
            id: photoData['id'],
            photoUrl: photoData['photo_url'],
            createdAt: DateTime.parse(photoData['created_at']),
            caption: photoData['caption'],
            milestone: photoData['milestone'],
            tags: photoTags,
            isFavorite: photoData['is_favorite'] ?? false,
          );
          fetchedPhotos.add(photo);
        }

        setState(() {
          photos = fetchedPhotos;
          filteredPhotos = fetchedPhotos;
          _availableTags.clear();
          _availableTags.addAll(tags);
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching photos: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading photos: $e')),
        );
      }
    }
  }

  void _applyFilters() {
    setState(() {
      filteredPhotos = photos.where((photo) {
        // Date range filter
        if (_filterOptions.startDate != null &&
            photo.createdAt.isBefore(_filterOptions.startDate!)) {
          return false;
        }
        if (_filterOptions.endDate != null &&
            photo.createdAt.isAfter(_filterOptions.endDate!)) {
          return false;
        }

        // Tags filter
        if (_filterOptions.selectedTags.isNotEmpty &&
            !photo.tags
                .any((tag) => _filterOptions.selectedTags.contains(tag))) {
          return false;
        }

        // Milestone filter
        if (_filterOptions.showOnlyMilestones && photo.milestone == null) {
          return false;
        }

        // Favorites filter
        if (_filterOptions.showOnlyFavorites && !photo.isFavorite) {
          return false;
        }

        // Caption search
        if (_filterOptions.captionSearch != null &&
            _filterOptions.captionSearch!.isNotEmpty) {
          final searchTerm = _filterOptions.captionSearch!.toLowerCase();
          return photo.caption?.toLowerCase().contains(searchTerm) ?? false;
        }

        return true;
      }).toList();

      // Apply sorting
      switch (_filterOptions.sortBy) {
        case 'oldest':
          filteredPhotos.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          break;
        case 'newest':
          filteredPhotos.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          break;
      }
    });
  }

  void _applyQuickFilter(QuickFilter filter) {
    setState(() {
      switch (filter.id) {
        case 'recent':
          _filterOptions.sortBy = 'newest';
          break;
        case 'favorites':
          _filterOptions.showOnlyFavorites = filter.isActive;
          break;
        case 'milestones':
          _filterOptions.showOnlyMilestones = filter.isActive;
          break;
      }
    });
    _applyFilters();
  }

  void _clearAllFilters() {
    setState(() {
      _filterOptions.reset();
      for (var filter in _quickFilters) {
        filter.isActive = false;
      }
      _activeFilters.clear();
    });
    _applyFilters();
  }

  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Text(
                          'Filter Photos',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        if (_activeFilters.isNotEmpty)
                          TextButton(
                            onPressed: () {
                              _clearAllFilters();
                              Navigator.pop(context);
                            },
                            child: const Text('Clear All'),
                          ),
                      ],
                    ),
                  ),

                  // Date Quick Picks
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _buildQuickDateChip('Today'),
                        _buildQuickDateChip('This Week'),
                        _buildQuickDateChip('This Month'),
                        _buildQuickDateChip('This Year'),
                        TextButton.icon(
                          onPressed: () => _showCustomDatePicker(),
                          icon: const Icon(Icons.calendar_today),
                          label: const Text('Custom Range'),
                        ),
                      ],
                    ),
                  ),

                  const Divider(),

                  // Tags Horizontal Scroll
                  if (_availableTags.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 16, top: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Tags',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                    ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(
                        children: _availableTags.map((tag) {
                          final isSelected =
                              _filterOptions.selectedTags.contains(tag);
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              selected: isSelected,
                              label: Text(tag),
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _filterOptions.selectedTags.add(tag);
                                  } else {
                                    _filterOptions.selectedTags.remove(tag);
                                  }
                                });
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],

                  // Apply Button
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          _applyFilters();
                          Navigator.pop(context);
                        },
                        child: const Text('Show Results'),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showCustomDatePicker() async {
    final now = DateTime.now();
    final pickedDate = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDateRange: DateTimeRange(
        start:
            _filterOptions.startDate ?? now.subtract(const Duration(days: 30)),
        end: _filterOptions.endDate ?? now,
      ),
    );

    if (pickedDate != null) {
      setState(() {
        _filterOptions.startDate = pickedDate.start;
        _filterOptions.endDate = pickedDate.end;
      });
      _applyFilters();
    }
  }

  // Add this method for the quick date chip
  Widget _buildQuickDateChip(String label) {
    final isSelected = _activeFilters.contains(label);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        label: Text(label),
        onSelected: (selected) {
          setState(() {
            if (selected) {
              _activeFilters.add(label);
            } else {
              _activeFilters.remove(label);
            }
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_albumName ?? 'Baby Album'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                ..._quickFilters.map((filter) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        selected: filter.isActive,
                        avatar: Icon(filter.icon, size: 18),
                        label: Text(filter.label),
                        onSelected: (selected) {
                          setState(() {
                            filter.isActive = selected;
                            _applyQuickFilter(filter);
                          });
                        },
                      ),
                    )),
                IconButton(
                  icon: const Icon(Icons.tune),
                  onPressed: _showFilterOptions,
                  tooltip: 'More Filters',
                ),
              ],
            ),
          ),
        ),
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AlbumAddPage(userID: widget.userID),
            ),
          );
          if (result == true) {
            _fetchPhotos();
          }
        },
        child: const Icon(Icons.add_a_photo),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (filteredPhotos.isEmpty) {
      return _buildEmptyState();
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: filteredPhotos.length,
      itemBuilder: (context, index) {
        return _buildPhotoTile(filteredPhotos[index], index);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.photo_library_outlined,
              size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          if (photos.isEmpty) ...[
            const Text(
              'Your Baby Album is Empty',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Start capturing precious moments by adding photos.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AlbumAddPage(userID: widget.userID),
                  ),
                );
                if (result == true) {
                  _fetchPhotos();
                }
              },
              icon: const Icon(Icons.add_a_photo),
              label: const Text('Add First Photo'),
            ),
          ] else ...[
            const Text(
              'No Photos Match Your Filters',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try adjusting your filter settings to see more photos.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: () {
                _filterOptions.reset();
                _applyFilters();
              },
              icon: const Icon(Icons.filter_alt_off),
              label: const Text('Clear Filters'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPhotoTile(BabyPhoto photo, int index) {
    return GestureDetector(
      onTap: () => _openFullScreen(index),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Hero(
            tag: 'photo_${photo.id}',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: photo.photoUrl,
                fit: BoxFit
                    .contain, // Use 'BoxFit.contain' instead of 'BoxFit.cover'
                alignment: Alignment.center,
                placeholder: (context, url) => Container(
                  color: Colors.grey[200],
                  child: const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: Colors.grey[200],
                  child: const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                  ),
                ),
                // Use larger cache size for better quality
                memCacheHeight: 800,
                memCacheWidth: 800,
              ),
            ),
          ),

          // Indicators overlay with improved visibility
          Positioned(
            top: 8,
            right: 8,
            child: Row(
              children: [
                if (photo.milestone != null)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.stars,
                      size: 16,
                      color: Colors.amber,
                    ),
                  ),
                if (photo.isFavorite)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.favorite,
                        size: 16,
                        color: Colors.red,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _toggleSlideshow() {
    setState(() {
      _isPlayingSlideshow = !_isPlayingSlideshow;
    });

    if (_isPlayingSlideshow) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _isPlayingSlideshow) {
          if (_currentIndex < filteredPhotos.length - 1) {
            _pageController.nextPage(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
            );
          } else {
            setState(() => _isPlayingSlideshow = false);
          }
        }
      });
    }
  }

  void _openFullScreen(int index) {
    setState(() => _currentIndex = index);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenViewer(
          photos: filteredPhotos,
          initialIndex: index,
          onPhotoChanged: (index) {
            setState(() => _currentIndex = index);
          },
          onToggleFavorite: _toggleFavorite,
        ),
      ),
    );
  }

  Future<void> _toggleFavorite(BabyPhoto photo) async {
    try {
      // Update locally first for immediate feedback
      setState(() {
        photo.isFavorite = !photo.isFavorite;
      });

      // Update in database
      await Supabase.instance.client
          .from('albums_photos')
          .update({'is_favorite': photo.isFavorite}).eq('id', photo.id);
    } catch (e) {
      // Revert local change if update fails
      setState(() {
        photo.isFavorite = !photo.isFavorite;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating favorite status: $e')),
        );
      }
    }
  }
}
