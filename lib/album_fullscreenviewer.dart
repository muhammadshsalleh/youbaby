import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'album_babyphoto.dart';

class FullScreenViewer extends StatefulWidget {
  final List<BabyPhoto> photos;
  final int initialIndex;
  final Function(int) onPhotoChanged;
  final Function(BabyPhoto) onToggleFavorite;

  const FullScreenViewer({
    super.key,
    required this.photos,
    required this.initialIndex,
    required this.onPhotoChanged,
    required this.onToggleFavorite,
  });

  @override
  FullScreenViewerState createState() => FullScreenViewerState();
}

class FullScreenViewerState extends State<FullScreenViewer> {
  late PageController _pageController;
  late int _currentIndex;
  bool _isZoomed = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildPhotoDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.photos[_currentIndex].milestone != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 20),
                const SizedBox(width: 8),
                Text(
                  widget.photos[_currentIndex].milestone!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        if (widget.photos[_currentIndex].caption != null)
          Text(
            widget.photos[_currentIndex].caption!,
            style: const TextStyle(color: Colors.white),
          ),
        const SizedBox(height: 8),
        Text(
          widget.photos[_currentIndex].formattedDate,
          style: TextStyle(color: Colors.white.withOpacity(0.7)),
        ),
        if (widget.photos[_currentIndex].tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: widget.photos[_currentIndex].tags.map((tag) {
                return Chip(
                  label: Text(
                    tag,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                  backgroundColor: Colors.white.withOpacity(0.2),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.5),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(
              widget.photos[_currentIndex].isFavorite
                  ? Icons.favorite
                  : Icons.favorite_border,
              color: Colors.white,
            ),
            onPressed: () =>
                widget.onToggleFavorite(widget.photos[_currentIndex]),
          ),
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: () {
              Share.share(
                'Check out this photo: ${widget.photos[_currentIndex].photoUrl}',
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          PhotoViewGallery.builder(
            pageController: _pageController,
            itemCount: widget.photos.length,
            builder: (context, index) {
              return PhotoViewGalleryPageOptions(
                imageProvider: CachedNetworkImageProvider(
                  widget.photos[index].photoUrl,
                ),
                heroAttributes: PhotoViewHeroAttributes(
                  tag: 'photo_${widget.photos[index].id}',
                ),
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 3,
                initialScale: PhotoViewComputedScale.contained,
                onScaleEnd: (context, details, controllerValue) {
                  setState(() {
                    // Check if the current scale is greater than the minimum scale
                    _isZoomed = controllerValue.scale! >
                        PhotoViewComputedScale.contained.multiplier;
                  });
                },
              );
            },
            loadingBuilder: (context, event) => const Center(
              child: CircularProgressIndicator(),
            ),
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
                _isZoomed = false;
              });
              widget.onPhotoChanged(index);
            },
            scrollPhysics: _isZoomed
                ? const NeverScrollableScrollPhysics()
                : const BouncingScrollPhysics(),
            backgroundDecoration: const BoxDecoration(color: Colors.black),
          ),
          if (!_isZoomed)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
                padding: const EdgeInsets.all(16),
                child: _buildPhotoDetails(),
              ),
            ),
        ],
      ),
    );
  }
} //for full screen
