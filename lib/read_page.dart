import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:photo_view/photo_view.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';



////////// DO NOT DELETE THE COMMENTS LINE
// uncomment this line to show video but only work for PC (AKA WEB)

class ReadPage extends StatefulWidget {
  final int articleId;
  final int userId;

  const ReadPage({
    Key? key,
    required this.articleId,
    required this.userId,
  }) : super(key: key);

  @override
  _ReadPageState createState() => _ReadPageState();
}

class _ReadPageState extends State<ReadPage> {
  Article? _article;
  bool _showAllComments = false;
  final TextEditingController _commentController = TextEditingController();
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _combinedComments = [];

  double kDesktopBreakpoint = 1024.0;
  double kTabletBreakpoint = 768.0;

  final TextEditingController _reportReasonController = TextEditingController();
  final TextEditingController _banReasonController = TextEditingController();

  YoutubePlayerController? _controller;
  bool _isVideoReady = false;

  final TextEditingController _otherReasonController = TextEditingController();
  ReportReason? _selectedReportReason;

  bool _showReferences = false;

  @override
  void initState() {
    super.initState();
    _fetchArticle();
    _fetchComments();
}

  Future<void> _fetchArticle() async {
  setState(() {
    _isLoading = true;
    _error = null;
  });

  try {
    final response = await Supabase.instance.client
        .from('article2')
        .select('''
          *,
          userAdmin:author_id(
            name
          )
        ''')
        .eq('id', widget.articleId)
        .single();

    if (mounted) {
      setState(() {
        _article = Article.fromJson(response);
        _isLoading = false;
      });

      if (_article?.videoUrl != null && _article!.videoUrl.isNotEmpty) {
          _initializeYoutubePlayer(_article!.videoUrl);
        }
    }
  } catch (e) {
    if (mounted) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }
}

 Future<void> _fetchComments() async {
    try {
      // Fetch user comments
      final List<dynamic> userComments = await Supabase.instance.client
          .from('commentsUsers')
          .select('''
            id,
            created,
            response,
            articleID,
            users!userID ( 
              id, 
              parentName
            )
          ''')
          .eq('articleID', widget.articleId)
          .order('created', ascending: false);

      // Fetch admin comments
      final List<dynamic> adminComments = await Supabase.instance.client
          .from('commentsAdmin')
          .select('''
            id,
            created,
            response,
            articleID,
            userAdmin!inner (
              id,
              name
            )
          ''')
          .eq('articleID', widget.articleId)
          .order('created', ascending: false);

      // Transform the comments to have a consistent structure
      List<Map<String, dynamic>> combined = [
        ...userComments.map((comment) => {
              'id': comment['id'],
              'created': comment['created'],
              'response': comment['response'],
              'isAdmin': false,
              'author': {
                'id': comment['users']?['id'],
                'name': comment['users']?['parentName'] ?? 'Anonymous User',
              },
            }),
        ...adminComments.map((comment) => {
              'id': comment['id'],
              'created': comment['created'],
              'response': comment['response'],
              'isAdmin': true,
              'author': {
                'id': comment['userAdmin']['id'],
                'name': comment['userAdmin']['name'],
              },
            }),
      ];

      // Sort by creation date
      combined.sort((a, b) =>
          DateTime.parse(b['created']).compareTo(DateTime.parse(a['created'])));

      if (mounted) {
        setState(() {
          _combinedComments = combined;
        });
      }
    } catch (e) {
      print('Error fetching comments: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching comments: $e')),
        );
      }
    }
  }

  Future<void> _submitComment() async {
    if (_commentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a comment')),
      );
      return;
    }

    try {
      await Supabase.instance.client.from('commentsUsers').insert({
        'userID': widget.userId,
        'articleID': widget.articleId,
        'response': _commentController.text,
        'created': DateTime.now().toIso8601String(),
      });

      _commentController.clear();
      await _fetchComments(); // Refresh comments
      FocusScope.of(context).unfocus();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comment added successfully!')),
        );
      }
    } catch (e) {
      print('Error submitting comment: $e'); // Debug print
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting comment: $e')),
        );
      }
    }
  }

  Future<void> _submitReport(Map<String, dynamic> comment) async {
  if (_selectedReportReason == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please select a reason for reporting')),
    );
    return;
  }

  if (_selectedReportReason == ReportReason.other &&
      _otherReasonController.text.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please specify the reason for reporting')),
    );
    return;
  }

  try {
    // First, verify that the current user is not an admin
    final adminCheck = await Supabase.instance.client
        .from('userAdmin')
        .select('id')
        .eq('id', widget.userId)
        .maybeSingle();

    if (adminCheck != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Admins cannot report comments'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Verify that the comment author exists in the users table (is not an admin)
    final userCheck = await Supabase.instance.client
        .from('users')
        .select('id')
        .eq('id', comment['author']['id'])
        .maybeSingle();

    if (userCheck == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot report admin comments'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    String reportReason = _selectedReportReason == ReportReason.other
        ? _otherReasonController.text
        : getReportReasonText(_selectedReportReason!);

    await Supabase.instance.client.from('reported_comments_article').insert({
      'comment_id': comment['id'],
      'user_id': comment['author']['id'],
      'reporter_id': widget.userId,
      'reason': reportReason,
      'report_type': _selectedReportReason.toString().split('.').last,
      'reported_at': DateTime.now().toIso8601String(),
      'status': 'pending',
      'comment_text': comment['response'],
      'report_category' : 'Read page comment',
    });

    Navigator.pop(context);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Comment reported successfully'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error reporting comment: $e'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    _controller?.dispose();
    _commentController.dispose();
    _reportReasonController.dispose();
    _banReasonController.dispose();
    super.dispose();
  }

  Widget _buildArticleContent() {
     return LayoutBuilder(
       builder: (context, constraints) {
         double contentWidth = constraints.maxWidth > 1200 
             ? 1000  // max width for very large screens
             : constraints.maxWidth > 600 
                 ? constraints.maxWidth * 0.8  // 80% width for medium screens
                 : constraints.maxWidth * 0.95;  // 95% width for small screens

         return SingleChildScrollView(
           child: Center(
             child: Container(
               width: contentWidth,
               padding: EdgeInsets.symmetric(
                 horizontal: constraints.maxWidth > 600 ? 32.0 : 16.0,
                 vertical: 24.0,
               ),
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                  // Hero Image
                  if (_article!.images.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: _buildResponsiveImage(_article!.images[0]),
                    ),                    
                  const SizedBox(height: 24),

                  // Category
                  if (_article!.category.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFA91B60).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _article!.category,
                        style: GoogleFonts.lato(
                          fontSize: 16,
                          color: const Color(0xFFA91B60),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Title
                  Text(
                    _article!.title,
                    style: GoogleFonts.merriweather(
                      fontSize: constraints.maxWidth > 600 ? 36 : 24,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFA91B60),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Author and Date
                  _buildAuthorDateSection(),

                  const SizedBox(height: 24),

                 // Main Image
                  if (_article!.imageUrl.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: _buildResponsiveImage(_article!.imageUrl),
                    ),

                  const SizedBox(height: 24),

                  // Main Content
                  Text(
                    _article!.detail,
                    style: GoogleFonts.lato(
                      fontSize: constraints.maxWidth > 600 ? 18 : 16,
                      height: 1.6,
                    ),
                  ),

                  // Subtitles
                  ..._buildSubtitleSections(constraints),

                 // Video section
                  if (_article!.videoUrl.isNotEmpty) ...[
                    const SizedBox(height: 32.0),
                    Text(
                      'Related Video',
                      style: GoogleFonts.merriweather(
                        fontSize: 24.0,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFA91B60),
                      ),
                    ),
                    const SizedBox(height: 16.0),
                   _buildResponsiveVideoPlayer(constraints),
                  ],

                  const SizedBox(height: 24.0),
                  _buildReferencesSection(),

                  const SizedBox(height: 20),

                  // Comments Section
                  _buildCommentsSection(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _initializeYoutubePlayer(String url) {
    if (url.isEmpty) return;

    String? videoId = YoutubePlayer.convertUrlToId(url);
    if (videoId == null) return;

    _controller = YoutubePlayerController(
      initialVideoId: videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: false,
        mute: false,
        enableCaption: true,
        hideControls: false,
        hideThumbnail: false,
        disableDragSeek: false,
        useHybridComposition: true, // Important for proper fullscreen on Android
      ),
    );
    setState(() {
      _isVideoReady = true;
    });
  }

   Widget _buildResponsiveVideoPlayer(BoxConstraints constraints) {
    if (!_isVideoReady || _controller == null) return Container();

    // Calculate dimensions while maintaining 16:9 aspect ratio
    double videoWidth = constraints.maxWidth > 800 
        ? 800  // max width for large screens
        : constraints.maxWidth * 0.9;  // 90% width for smaller screens
    
    double videoHeight = videoWidth * 9 / 16;  // 16:9 aspect ratio

    return YoutubePlayerBuilder(
      onExitFullScreen: () {
        // The player forces portraitUp after exiting fullscreen. This overrides it.
        SystemChrome.setPreferredOrientations(DeviceOrientation.values);
      },
      onEnterFullScreen: () {
        // You can add custom behavior when entering fullscreen if needed
      },
      player: YoutubePlayer(
        controller: _controller!,
        showVideoProgressIndicator: true,
        progressIndicatorColor: const Color(0xFFA91B60),
        progressColors: const ProgressBarColors(
          playedColor: Color(0xFFA91B60),
          handleColor: Color(0xFFA91B60),
        ),
        onReady: () {
          setState(() {
            _isVideoReady = true;
          });
        },
        bottomActions: [
          CurrentPosition(),
          ProgressBar(
            isExpanded: true,
            colors: const ProgressBarColors(
              playedColor: Color(0xFFA91B60),
              handleColor: Color(0xFFA91B60),
            ),
          ),
          RemainingDuration(),
          const PlaybackSpeedButton(),
          FullScreenButton(),
        ],
        topActions: [
          const SizedBox(width: 8.0),
          Expanded(
            child: Text(
              _controller!.metadata.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18.0,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.settings,
              color: Colors.white,
              size: 25.0,
            ),
            onPressed: () {
              // Add settings functionality if needed
            },
          ),
        ],
      ),
      builder: (context, player) {
        return Container(
          width: videoWidth,
          height: videoHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: player,
          ),
        );
      },
    );
  }

  Widget _buildReferencesSection() {
  if (_article!.references.isEmpty) {
    return const SizedBox.shrink();
  }

  return Container(
    margin: const EdgeInsets.only(bottom: 32.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _showReferences = !_showReferences),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
            decoration: BoxDecoration(
              color: const Color(0xFFA91B60).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'References',
                  style: GoogleFonts.merriweather(
                    fontSize: 20.0,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFA91B60),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  _showReferences ? Icons.expand_less : Icons.expand_more,
                  color: const Color(0xFFA91B60),
                ),
              ],
            ),
          ),
        ),
        if (_showReferences) ...[
          const SizedBox(height: 16),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _article!.references.asMap().entries.map((entry) {
                  final index = entry.key;
                  final reference = entry.value;
                  
                  // Handle both string URLs and map references
                  if (reference is String) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '[${index + 1}] ',
                            style: GoogleFonts.lato(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFA91B60),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final Uri uri = Uri.parse(reference);
                                try {
                                  if (await canLaunchUrl(uri)) {
                                    await launchUrl(uri);
                                  } else {
                                    throw 'Could not launch $reference';
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Could not open URL: $e')),
                                    );
                                  }
                                }
                              },
                              child: Text(
                                reference,
                                style: GoogleFonts.lato(
                                  color: Colors.blue,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  } else if (reference is Map<String, dynamic>) {
                    // Handle the original map format
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '[${index + 1}] ',
                            style: GoogleFonts.lato(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFA91B60),
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (reference['title'] != null)
                                  Text(
                                    reference['title'],
                                    style: GoogleFonts.lato(fontWeight: FontWeight.bold),
                                  ),
                                if (reference['authors'] != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    reference['authors'],
                                    style: GoogleFonts.lato(fontStyle: FontStyle.italic),
                                  ),
                                ],
                                if (reference['source'] != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    reference['source'],
                                    style: GoogleFonts.lato(color: Colors.grey[600]),
                                  ),
                                ],
                                if (reference['url'] != null) ...[
                                  const SizedBox(height: 4),
                                  InkWell(
                                    onTap: () async {
                                      final Uri uri = Uri.parse(reference['url']);
                                      try {
                                        if (await canLaunchUrl(uri)) {
                                          await launchUrl(uri);
                                        } else {
                                          throw 'Could not launch ${reference['url']}';
                                        }
                                      } catch (e) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Could not open URL: $e')),
                                          );
                                        }
                                      }
                                    },
                                    child: Text(
                                      reference['url'],
                                      style: GoogleFonts.lato(
                                        color: Colors.blue,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return const SizedBox.shrink(); // Return empty widget for unsupported types
                }).toList(),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

  List<Widget> _buildSubtitleSections(BoxConstraints constraints) {
    return _article!.subtitles.map((subtitle) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          Text(
            subtitle['subTitle'] ?? '',
            style: GoogleFonts.merriweather(
              fontSize: constraints.maxWidth > 600 ? 28 : 22,
              fontWeight: FontWeight.bold,
              color: const Color(0xFFA91B60),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            subtitle['subDetail'] ?? '',
            style: GoogleFonts.lato(
              fontSize: constraints.maxWidth > 600 ? 18 : 16,
              height: 1.6,
            ),
          ),
          if (subtitle['imageUrl'] != null && subtitle['imageUrl'].isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: _buildResponsiveImage(subtitle['imageUrl']),
            ),
        ],
      );
    }).toList();
  }

  Widget _buildCommentsSection() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Comments',
            style: GoogleFonts.merriweather(
              fontSize: 24.0,
              fontWeight: FontWeight.bold,
              color: const Color(0xFFA91B60),
            ),
          ),
          const SizedBox(height: 16.0),

          // Comments List with Admin Actions
          _combinedComments.isEmpty
              ? Text(
                  'No comments yet. Be the first to comment!',
                  style: GoogleFonts.lato(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey,
                  ),
                )
              : Column(
                  children: [
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _showAllComments
                          ? _combinedComments.length
                          : (_combinedComments.length > 3 ? 3 : _combinedComments.length),
                      itemBuilder: (context, index) {
                        final comment = _combinedComments[index];
                        final bool isAdminComment = comment['isAdmin'];
                        final String authorName = comment['author']['name'];
                        //final int authorId = comment['author']['id'];

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: isAdminComment ? const Color(0xFFA91B60) : Colors.blue,
                                      child: Text(
                                        authorName[0].toUpperCase(),
                                        style: GoogleFonts.lato(color: Colors.white),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            authorName,
                                            style: GoogleFonts.lato(
                                              fontWeight: FontWeight.bold,
                                              color: isAdminComment ? const Color(0xFFA91B60) : Colors.black87,
                                            ),
                                          ),
                                          Text(
                                            DateFormat('MMM d, yyyy').format(DateTime.parse(comment['created'])),
                                            style: GoogleFonts.lato(
                                              color: Colors.grey,
                                              fontSize: 12.0,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isAdminComment)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFA91B60),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          'Admin',
                                          style: GoogleFonts.lato(
                                            color: Colors.white,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    if (!isAdminComment) // Only show admin actions for non-admin comments
                                      PopupMenuButton<String>(
                                        icon: const Icon(Icons.more_vert),
                                        onSelected: (String value) {
                                          if (value == 'report') {
                                            _showReportDialog(comment);
                                          } else if (value == 'ban') {
                                            //_showBanDialog(authorId, authorName);
                                          }
                                        },
                                        itemBuilder: (BuildContext context) => [
                                          const PopupMenuItem(
                                            value: 'report',
                                            child: Row(
                                              children: [
                                                Icon(Icons.flag, color: Colors.orange),
                                                SizedBox(width: 8),
                                                Text('Report Comment'),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8.0),
                                Text(
                                  comment['response'],
                                  style: GoogleFonts.lato(fontSize: 16.0),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    if (_combinedComments.length > 3 && !_showAllComments)
                      TextButton(
                        onPressed: () => setState(() => _showAllComments = true),
                        child: Text(
                          'View all comments',
                          style: GoogleFonts.lato(color: const Color(0xFFA91B60)),
                        ),
                      ),
                  ],
                ),

          // Comment Input
          const SizedBox(height: 16.0),
          TextField(
            controller: _commentController,
            decoration: InputDecoration(
              hintText: 'Write a comment...',
              hintStyle: GoogleFonts.lato(),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFA91B60)),
              ),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 8.0),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: _submitComment,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFA91B60),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text('Submit', style: GoogleFonts.lato()),
            ),
          ),
        ],
      ),
    );
  }

  String getReportReasonText(ReportReason reason) {
    switch (reason) {
      case ReportReason.improperContent:
        return 'Improper Words/Emoji';
      case ReportReason.harassment:
        return 'Harassment';
      case ReportReason.spam:
        return 'Spam';
      case ReportReason.hateSpeech:
        return 'Hate Speech';
      case ReportReason.inappropriate:
        return 'Inappropriate Content';
      case ReportReason.threatening:
        return 'Threatening Behavior';
      case ReportReason.other:
        return 'Other';
    }
  }

  void _showReportDialog(Map<String, dynamic> comment) async {
  // Check if the comment is from the current user
  if (comment['author']['id'] == widget.userId) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('You cannot report your own comment'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }

  // Check if the current user is an admin
  final adminCheck = await Supabase.instance.client
      .from('userAdmin')
      .select('id')
      .eq('id', widget.userId)
      .maybeSingle();

  if (adminCheck != null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Admins cannot report comments'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }

  // Check if the comment is from an admin
  if (comment['isAdmin']) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cannot report admin comments'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }

  _selectedReportReason = null;
  _otherReasonController.clear();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                'Report Comment',
                style: GoogleFonts.merriweather(
                  color: const Color(0xFFA91B60),
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Comment by: ${comment['author']['name']}',
                      style: GoogleFonts.lato(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Select a reason for reporting:',
                      style: GoogleFonts.lato(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...ReportReason.values.map((reason) {
                      return RadioListTile<ReportReason>(
                        title: Text(
                          getReportReasonText(reason),
                          style: GoogleFonts.lato(),
                        ),
                        value: reason,
                        groupValue: _selectedReportReason,
                        activeColor: const Color(0xFFA91B60),
                        onChanged: (ReportReason? value) {
                          setState(() {
                            _selectedReportReason = value;
                          });
                        },
                      );
                    }).toList(),
                    if (_selectedReportReason == ReportReason.other)
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: TextField(
                          controller: _otherReasonController,
                          decoration: InputDecoration(
                            labelText: 'Please specify the reason',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFFA91B60)),
                            ),
                          ),
                          maxLines: 3,
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.lato(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  onPressed: _selectedReportReason == null
                      ? null
                      : () => _submitReport(comment),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFA91B60),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey,
                  ),
                  child: Text('Submit Report', style: GoogleFonts.lato()),
                ),
              ],
            );
          },
        );
      },
    );
  }

Widget _buildResponsiveImage(String imageUrl, {double? maxHeight}) {
  void showImageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.black.withOpacity(0.9),
                child: PhotoView(
                  imageProvider: CachedNetworkImageProvider(imageUrl),
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 2,
                  backgroundDecoration: const BoxDecoration(
                    color: Colors.transparent,
                  ),
                ),
              ),
              Positioned(
                top: 20,
                right: 20,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  return LayoutBuilder(
    builder: (context, constraints) {
      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: constraints.maxWidth * 1.4,
            maxHeight: maxHeight ?? double.infinity,
          ),
          child: GestureDetector(
            onTap: () => showImageDialog(context),
            child: Hero(
              tag: imageUrl,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                    placeholder: (context, url) => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    errorWidget: (context, url, error) => const Center(
                      child: Icon(Icons.error),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

  Widget _buildAuthorDateSection() {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person, size: 16, color: Colors.grey),
            const SizedBox(width: 4),
            Text(
              _article!.author['name'] ?? 'Unknown Author',
              style: GoogleFonts.lato(
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
            const SizedBox(width: 4),
            Text(
              DateFormat('dd MMMM yyyy').format(_article!.createdAt),
              style: GoogleFonts.lato(color: Colors.grey[600]),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_controller?.value.isFullScreen ?? false) {
          _controller?.toggleFullScreenMode();
          return false;
        }
        return true;
      },
      child: OrientationBuilder(
        builder: (context, orientation) {
          return Scaffold(
            backgroundColor: Colors.white,
            appBar: orientation == Orientation.portrait 
              ? AppBar(
                  backgroundColor: const Color(0xFFA91B60),
                  title: Text(
                    'Read Article',
                    style: GoogleFonts.merriweather(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  centerTitle: true,
                  elevation: 0,
                )
              : null, // Hide AppBar in landscape mode when video is fullscreen
            body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 48),
                        const SizedBox(height: 16),
                        Text('Error: $_error'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _fetchArticle,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : _buildArticleContent(),
          );
        },
      ),
    );
  }
}

class Article {
  final int id;
  final String title;
  final String detail;
  final String category;
  final String videoUrl;
  final List<Map<String, dynamic>> subtitles;
  final List<String> images;
  final String imageUrl;
  final DateTime createdAt;
  final Map<String, dynamic> author;
  final List<dynamic> references; // Add this line

  Article({
    required this.id,
    required this.title,
    required this.detail,
    required this.category,
    required this.videoUrl,
    required this.subtitles,
    required this.images,
    required this.imageUrl,
    required this.createdAt,
    required this.author,
    required this.references,
  });

  factory Article.fromJson(Map<String, dynamic> json) {
    List<dynamic> parseReferences(dynamic referencesData) {
      if (referencesData is List) {
        return referencesData;
      } else if (referencesData is String) {
        try {
          final decoded = jsonDecode(referencesData);
          if (decoded is List) {
            return decoded;
          }
        } catch (_) {}
      }
      return [];
    }

    List<String> parseImages(dynamic imagesData) {
      if (imagesData is List) {
        return imagesData.map((e) => e.toString()).toList();
      } else if (imagesData is String) {
        try {
          final decoded = jsonDecode(imagesData);
          if (decoded is List) {
            return decoded.map((e) => e.toString()).toList();
          }
        } catch (_) {}
      }
      return [];
    }

    return Article(
      id: json['id'],
      title: json['title'] ?? '',
      detail: json['detail'] ?? '',
      category: json['category'] ?? '',
      videoUrl: json['video_url'] ?? '',
      subtitles: parseReferences(json['subtitles']).map((e) => e as Map<String, dynamic>).toList(),
      images: parseImages(json['images']),
      imageUrl: json['images'] ?? '',
      createdAt: DateTime.parse(json['created_at']),
      author: json['userAdmin'] ?? {},
      references: parseReferences(json['references']),
    );
  }
}

enum ReportReason {
  improperContent,
  harassment,
  spam,
  hateSpeech,
  inappropriate,
  threatening,
  other
}
