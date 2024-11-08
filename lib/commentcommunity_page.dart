import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';



///// Page UI and fetching comments
class CommentsPage extends StatefulWidget {
  final int postId;
  final int userId;
  final String postTitle;
  final String postContent;
  final String postAuthor;
  final String? postImage;

  const CommentsPage({
    super.key,
    required this.postId,
    required this.userId,
    required this.postTitle,
    required this.postContent,
    required this.postAuthor,
    this.postImage,
  });

  @override
  _CommentsPageState createState() => _CommentsPageState();
}

class _CommentsPageState extends State<CommentsPage> {
  List<Map<String, dynamic>> _comments = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  ReportReason? _selectedReportReason;
  final TextEditingController _otherReasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchComments();
  }

  Future<void> _fetchComments() async {
    try {
      final response = await Supabase.instance.client
          .from('comments_community')
          .select('*, users(parentName)')
          .eq('postID', widget.postId)
          .order('created', ascending: false);

      setState(() {
        _comments = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      _showSnackBar('Error fetching comments: $e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _submitComment() async {
    if (_commentController.text.isEmpty) {
      _showSnackBar('Please enter a comment');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await Supabase.instance.client.from('comments_community').insert({
        'userID': widget.userId,
        'postID': widget.postId,
        'comment': _commentController.text,
        'created': DateTime.now().toIso8601String(),
      });

      final post = await Supabase.instance.client
          .from('community_posts')
          .select('comments_count')
          .eq('id', widget.postId)
          .single();

      int currentCount = post['comments_count'] ?? 0;

      await Supabase.instance.client
          .from('community_posts')
          .update({'comments_count': currentCount + 1}).eq('id', widget.postId);

      _commentController.clear();
      await _fetchComments();
      FocusScope.of(context).unfocus();

      // Scroll to the top where the new comment will appear
      if (_scrollController.hasClients) {
        await _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }

      _showSnackBar('Comment added successfully!');
    } catch (e) {
      _showSnackBar('Error submitting comment: $e');
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submitPostReport() async {
  if (_selectedReportReason == null) {
    _showSnackBar('Please select a reason for reporting');
    return;
  }

  if (_selectedReportReason == ReportReason.other &&
      _otherReasonController.text.isEmpty) {
    _showSnackBar('Please specify the reason for reporting');
    return;
  }

  try {
    // Check if reporter is an admin
    final adminCheck = await Supabase.instance.client
        .from('userAdmin')
        .select('id')
        .eq('id', widget.userId)
        .maybeSingle();

    if (adminCheck != null) {
      _showSnackBar('Admins cannot report posts');
      return;
    }

    // Get the author's user ID from the community_posts table
    final postDetails = await Supabase.instance.client
        .from('community_posts')
        .select('user_Id')
        .eq('id', widget.postId)
        .single();
    
    final int authorUserId = postDetails['user_Id'];

    String reportReason = _selectedReportReason == ReportReason.other
        ? _otherReasonController.text
        : getReportReasonText(_selectedReportReason!);

    await Supabase.instance.client.from('reported_post_community').insert({
      'post_id': widget.postId, // Integer FK to community_posts.id
      'user_id': authorUserId, // Integer FK to users.id (post author)
      'reporter_id': widget.userId, // Integer FK to users.id (person reporting)
      'reason': reportReason,
      'report_type': _selectedReportReason.toString().split('.').last,
      'reported_at': DateTime.now().toIso8601String(),
      'status': 'pending',
      'post_title': widget.postTitle,
      'post_content': widget.postContent,
      'report_category': 'Community Post',
    });

    _showSnackBar('Post reported successfully');
  } catch (e) {
    _showSnackBar('Error reporting post: $e');
  }
}

  // Add method to submit comment reports
  Future<void> _submitCommentReport(Map<String, dynamic> comment) async {
  if (_selectedReportReason == null) {
    _showSnackBar('Please select a reason for reporting');
    return;
  }

  if (_selectedReportReason == ReportReason.other &&
      _otherReasonController.text.isEmpty) {
    _showSnackBar('Please specify the reason for reporting');
    return;
  }

  try {
    // Check if the comment is made by the current user
    if (comment['userID'] == widget.userId) {
      _showSnackBar('You cannot report your own comment');
      return;
    }

    // Check if reporter is an admin
    final adminCheck = await Supabase.instance.client
        .from('userAdmin')
        .select('id')
        .eq('id', widget.userId)
        .maybeSingle();

    if (adminCheck != null) {
      _showSnackBar('Admins cannot report comments');
      return;
    }

    String reportReason = _selectedReportReason == ReportReason.other
        ? _otherReasonController.text
        : getReportReasonText(_selectedReportReason!);

    await Supabase.instance.client.from('reported_comments_community').insert({
      'comment_id': comment['id'],
      'user_id': comment['userID'],
      'reporter_id': widget.userId,
      'reason': reportReason,
      'report_type': _selectedReportReason.toString().split('.').last,
      'reported_at': DateTime.now().toIso8601String(),
      'status': 'pending',
      'comment_text': comment['comment'],
      'report_category': 'Community Comment',
    });

    _showSnackBar('Comment reported successfully');
  } catch (e) {
    _showSnackBar('Error reporting comment: $e');
  }
}

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }


  void _showReportPostDialog() {
    _selectedReportReason = null;
    _otherReasonController.clear();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Report Post'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Why are you reporting this post?'),
                    const SizedBox(height: 16),
                    ...ReportReason.values.map((reason) => RadioListTile<ReportReason>(
                      title: Text(getReportReasonText(reason)),
                      value: reason,
                      groupValue: _selectedReportReason,
                      onChanged: (ReportReason? value) {
                        setState(() => _selectedReportReason = value);
                      },
                    )),
                    if (_selectedReportReason == ReportReason.other)
                      TextField(
                        controller: _otherReasonController,
                        decoration: const InputDecoration(
                          hintText: 'Please specify the reason',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    _submitPostReport();
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFA91B60),
                  ),
                  child: const Text('Submit Report'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Add method to show report dialog for comments
  void _showReportCommentDialog(Map<String, dynamic> comment) {
    _selectedReportReason = null;
    _otherReasonController.clear();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Report Comment'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Why are you reporting this comment?'),
                    const SizedBox(height: 16),
                    ...ReportReason.values.map((reason) => RadioListTile<ReportReason>(
                      title: Text(getReportReasonText(reason)),
                      value: reason,
                      groupValue: _selectedReportReason,
                      onChanged: (ReportReason? value) {
                        setState(() => _selectedReportReason = value);
                      },
                    )),
                    if (_selectedReportReason == ReportReason.other)
                      TextField(
                        controller: _otherReasonController,
                        decoration: const InputDecoration(
                          hintText: 'Please specify the reason',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    _submitCommentReport(comment);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFA91B60),
                  ),
                  child: const Text('Submit Report'),
                ),
              ],
            );
          },
        );
      },
    );
  }

   Widget _buildPostCard() {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.postTitle,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.person_outline, 
                            size: 16, 
                            color: Color(0xFFA91B60)
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.postAuthor,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFFA91B60),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.flag_outlined),
                  onPressed: _showReportPostDialog,
                  tooltip: 'Report Post',
                  color: Colors.grey[600],
                ),
              ],
            ),
          ),
          if (widget.postImage != null && widget.postImage!.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.network(
                widget.postImage!,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const SizedBox(
                    height: 200,
                    child: Center(child: Icon(Icons.error_outline)),
                  );
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              widget.postContent,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF666666),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Modify the CommentCard widget to include the report button
  Widget _buildCommentCard({required Map<String, dynamic> comment}) {
  final DateTime commentDate = DateTime.parse(comment['created']);
  final String formattedDate = DateFormat('d MMM yyyy, h:mm a').format(commentDate);

  return Card(
    elevation: 1,
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFA91B60).withOpacity(0.1),
                radius: 16,
                child: Text(
                  comment['users']['parentName'][0].toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFFA91B60),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comment['users']['parentName'],
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      formattedDate,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              // Check if the current user is the comment author
              if (comment['userID'] != widget.userId)
                IconButton(
                  icon: const Icon(Icons.flag_outlined),
                  onPressed: () => _showReportCommentDialog(comment),
                  tooltip: 'Report Comment',
                  color: Colors.grey[600],
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            comment['comment'],
            style: const TextStyle(
              fontSize: 15,
              height: 1.5,
              color: Color(0xFF333333),
            ),
          ),
        ],
      ),
    ),
  );
}

 @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'Discussion',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFA91B60),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFA91B60)),
              ),
            )
          : CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverToBoxAdapter(
                  child: _buildPostCard(),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Comments (${_comments.length})',
                          style: const TextStyle(
                            fontSize: 18.0,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF333333),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _fetchComments,
                          icon: const Icon(Icons.refresh, size: 20),
                          label: const Text('Refresh'),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFA91B60),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (_comments.isEmpty) {
                        return const EmptyCommentsPlaceholder();
                      }
                      return _buildCommentCard(comment: _comments[index]);
                    },
                    childCount: _comments.isEmpty ? 1 : _comments.length,
                  ),
                ),
                const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
              ],
            ),
      bottomSheet: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          top: 16,
          left: 16,
          right: 16,
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _commentController,
                maxLines: null,
                decoration: InputDecoration(
                  hintText: 'Share your thoughts...',
                  hintStyle: const TextStyle(color: Color(0xFFBDBDBD)),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF5F5F5),
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submitComment,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFA91B60),
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(16),
                elevation: 0,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.send, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

//// For report function 
enum ReportReason {
  spam,
  inappropriate,
  harassment,
  misinformation,
  other,
}

String getReportReasonText(ReportReason reason) {
  switch (reason) {
    case ReportReason.spam:
      return 'Spam';
    case ReportReason.inappropriate:
      return 'Inappropriate content';
    case ReportReason.harassment:
      return 'Harassment';
    case ReportReason.misinformation:
      return 'Misinformation';
    case ReportReason.other:
      return 'Other';
  }
}


class EmptyCommentsPlaceholder extends StatelessWidget {
  const EmptyCommentsPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No comments yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Be the first to share your thoughts!',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}