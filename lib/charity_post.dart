import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:youbaby/charity_page.dart';
import 'dart:async';

// display one post when clicked
class CharityPost extends StatefulWidget {
  final int postId;
  final int userId;
  final String title;
  final String content;
  final String? imageUrl;
  final String status;

  const CharityPost({
    Key? key,
    required this.postId,
    required this.userId,
    required this.title,
    required this.content,
    this.imageUrl,
    required this.status,
  }) : super(key: key);

  @override
  _CharityPostState createState() => _CharityPostState();
}

class _CharityPostState extends State<CharityPost> {
  List<Map<String, dynamic>> _qna = [];
  final TextEditingController _qnaController = TextEditingController();
  final TextEditingController _answerController = TextEditingController();
  int? postAuthor;
  int? _editingQuestionId;
  bool _showAllQnA = false;
  String? postAuthorName;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _fetchQuestions();
    _fetchPostAuthor();
  }

  Future<void> _fetchPostAuthor() async {
    try {
      final response = await Supabase.instance.client
          .from('charity_posts')
          .select('user_id, users(parentName)')
          .eq('id', widget.postId)
          .single();

      setState(() {
        postAuthor = response['user_id'];
        postAuthorName = response['users']['parentName'];
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching charity post author: $e')),
      );
    }
  }

  Future<void> _fetchQuestions() async {
    try {
      final response = await Supabase.instance.client
          .from('qna_charity')
          .select('*, users(parentName)')
          .eq('postID', widget.postId)
          .order('created_at', ascending: false);

      setState(() {
        _qna = List<Map<String, dynamic>>.from(response);
        // _isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching question: $e')),
      );
    }
  }

  Future<Map<int, int>> _fetchQnACounts() async {
    try {
      final response = await Supabase.instance.client
          .from('qna_charity')
          .select('postID, question, answer');

      Map<int, int> qnaCounts = {};

      for (var item in response as List<dynamic>) {
        int postId = item['postID'];
        int count = 0;
        if (item['question'] != null) count++;
        if (item['answer'] != null) count++;

        qnaCounts[postId] = (qnaCounts[postId] ?? 0) + count;
      }

      // If you want to update the counts in the UI or a specific state variable
      await _updateQnACount(qnaCounts);

      return qnaCounts;
    } catch (e) {
      print('Error fetching QnA counts: $e');
      return {};
    }
  }

  Future<void> _updateQnACount(Map<int, int> qnaCounts) async {
    // Accepting qnaCounts as a parameter
    try {
      // Fetch the current QnA count
      Map<int, int> qnaCounts = await _fetchQnACounts();

      // Update the charity_posts table with the new count
      await Supabase.instance.client.from('charity_posts').update({
        'qna_count': qnaCounts[widget.postId] ??
            0, // Assuming qna_count is the column name
      }).eq('id', widget.postId);
    } catch (e) {
      print('Error updating QnA count: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating QnA count: $e')),
      );
    }
  }

  Future<void> _submitQuestion() async {
    if (_qnaController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a Question')),
      );
      return;
    }

    try {
      await Supabase.instance.client.from('qna_charity').insert({
        'userID': widget.userId,
        'postID': widget.postId,
        'question': _qnaController.text,
        'is_answered': false,
        'created_at': DateTime.now().toIso8601String(),
      });

      _qnaController.clear();
      await _fetchQuestions();
      await _fetchQnACounts();

      FocusScope.of(context).unfocus();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Question added successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting question: $e')),
      );
    }
  }

  Future<void> _submitAnswer(int questionId) async {
    if (_answerController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an answer')),
      );
      return;
    }

    try {
      await Supabase.instance.client.from('qna_charity').update({
        'answer': _answerController.text,
        'is_answered': true,
      }).eq('id', questionId);

      setState(() {
        _answerController.clear();
        _editingQuestionId = null;
      });

      await _fetchQuestions();
      await _fetchQnACounts();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Answer submitted successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting answer: $e')),
      );
    }
  }

  Future<void> _submitPostReport() async {
  final reportResult = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (context) => ReportPostDialog(),
  );

  if (reportResult == null) return; // User cancelled the report dialog

  try {
    final adminCheck = await Supabase.instance.client
        .from('userAdmin')
        .select('id')
        .eq('id', widget.userId)
        .maybeSingle();

    if (adminCheck != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Admins cannot report posts')),
      );
      return;
    }

    final postDetails = await Supabase.instance.client
        .from('charity_posts')
        .select('user_id')
        .eq('id', widget.postId)
        .single();
    final int authorUserId = postDetails['user_id'];

    final ReportReason reason = reportResult['reason'];
    final String? customReason = reportResult['customReason'];

    await Supabase.instance.client.from('reported_post_charity').insert({
      'post_id': widget.postId,
      'user_id': authorUserId,
      'reporter_id': widget.userId,
      'reason': reason == ReportReason.other 
        ? customReason 
        : getReportReasonText(reason),
      'report_type': reason.toString().split('.').last,
      'reported_at': DateTime.now().toIso8601String(),
      'status': 'pending',
      'post_title': widget.title,
      'post_content': widget.content,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Post reported successfully'),
        backgroundColor: Color(0xFFA91B60),
      ),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error reporting post: $e')),
    );
  }
}
  

  @override
  void dispose() {
    _qnaController.dispose();
    _answerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'Charity Post',
          style: TextStyle(
            color: Color(0xFFEBE0D0),
            fontSize: 24.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFFA91B60),
        actions: [
          IconButton(
            icon: const Icon(Icons.report_outlined, color: Color(0xFFEBE0D0)),
            onPressed: _submitPostReport,
            tooltip: 'Report Post',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Hero Image Section
            if (widget.imageUrl != null)
              Container(
                height: MediaQuery.of(context).size.height * 0.35,
                width: double.infinity,
                child: Stack(
                  children: [
                    Image.network(
                      widget.imageUrl!,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.7),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 16,
                      left: 16,
                      right: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: const TextStyle(
                              fontSize: 28.0,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          if (postAuthorName != null)
                            Text(
                              'Posted by: $postAuthorName',
                              style: const TextStyle(
                                fontSize: 16.0,
                                color: Colors.white70,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Content Section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.imageUrl == null) ...[
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 28.0,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                    ),
                    if (postAuthorName != null)
                      Text(
                        'Posted by: $postAuthorName',
                        style: const TextStyle(
                          fontSize: 16.0,
                          color: Color(0xFFA91B60),
                        ),
                      ),
                  ],
                  const SizedBox(height: 16.0),
                  
                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                    decoration: BoxDecoration(
                      color: widget.status == 'Available' 
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFFE57373),
                      borderRadius: BorderRadius.circular(20.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      widget.status,
                      style: const TextStyle(
                        fontSize: 14.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24.0),
                  
                  // Content Card
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Description',
                            style: TextStyle(
                              fontSize: 18.0,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF333333),
                            ),
                          ),
                          const SizedBox(height: 8.0),
                          Text(
                            widget.content,
                            style: const TextStyle(
                              fontSize: 16.0,
                              color: Color(0xFF666666),
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24.0),

                  // Q&A Section
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.question_answer, 
                                color: Color(0xFFA91B60)),
                              SizedBox(width: 8.0),
                              Text(
                                'Questions & Answers',
                                style: TextStyle(
                                  fontSize: 20.0,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF333333),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24.0),
                          
                          // Q&A List
                          if (_qna.isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24.0),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.chat_bubble_outline,
                                      size: 48,
                                      color: Color(0xFFBDBDBD),
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'No questions yet. Be the first to ask!',
                                      style: TextStyle(
                                        fontSize: 16.0,
                                        fontStyle: FontStyle.italic,
                                        color: Color(0xFF9E9E9E),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            ListView.separated(
                              physics: const NeverScrollableScrollPhysics(),
                              shrinkWrap: true,
                              itemCount: _showAllQnA ? _qna.length : min(2, _qna.length),
                              separatorBuilder: (context, index) => const Divider(height: 32.0),
                              itemBuilder: (context, index) {
                                final question = _qna[index];
                                bool isPostAuthor = postAuthor != null && 
                                    postAuthor == widget.userId;

                                return _buildQuestionCard(
                                  question, 
                                  isPostAuthor,
                                );
                              },
                            ),

                          if (_qna.length > 2 && !_showAllQnA)
                            Center(
                              child: TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _showAllQnA = true;
                                  });
                                },
                                icon: const Icon(
                                  Icons.expand_more,
                                  color: Color(0xFFA91B60),
                                ),
                                label: const Text(
                                  'Show More Questions',
                                  style: TextStyle(
                                    color: Color(0xFFA91B60),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),

                          if (widget.status == 'Available') ...[
                            const SizedBox(height: 24.0),
                            _buildQuestionInput(),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard(Map<String, dynamic> question, bool isPostAuthor) {
    return Card(
      elevation: 0,
      color: const Color(0xFFF5F5F5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFFA91B60),
                  child: Icon(Icons.question_mark, color: Colors.white),
                ),
                const SizedBox(width: 12.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        question['question'],
                        style: const TextStyle(
                          fontSize: 16.0,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF333333),
                        ),
                      ),
                      const SizedBox(height: 4.0),
                      Text(
                        'Asked by ${question['users']['parentName']} • ${DateFormat('MMM d, yyyy').format(DateTime.parse(question['created_at']))}',
                        style: const TextStyle(
                          fontSize: 12.0,
                          color: Color(0xFF757575),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (question['answer'] != null) ...[
              const SizedBox(height: 16.0),
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(
                    color: const Color(0xFFE0E0E0),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      question['answer'],
                      style: const TextStyle(
                        fontSize: 15.0,
                        color: Color(0xFF424242),
                      ),
                    ),
                    if (isPostAuthor)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _editingQuestionId = _editingQuestionId == question['id']
                                  ? null
                                  : question['id'];
                              _answerController.text = question['answer'];
                            });
                          },
                          icon: const Icon(
                            Icons.edit,
                            size: 16,
                          ),
                          label: const Text('Edit'),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFA91B60),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ] else if (isPostAuthor) ...[
              const SizedBox(height: 12.0),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _editingQuestionId = _editingQuestionId == question['id']
                          ? null
                          : question['id'];
                    });
                  },
                  icon: const Icon(Icons.reply),
                  label: const Text('Answer'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFA91B60),
                  ),
                ),
              ),
            ],

            if (_editingQuestionId == question['id'])
              _buildAnswerInput(question['id']),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _qnaController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Ask a question about this item...',
            hintStyle: const TextStyle(color: Color(0xFFBDBDBD)),
            prefixIcon: const Padding(
              padding: EdgeInsets.all(12.0),
              child: Icon(Icons.chat_bubble_outline, color: Color(0xFFA91B60)),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: const BorderSide(color: Color(0xFFBDBDBD)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: const BorderSide(color: Color(0xFFA91B60), width: 2.0),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
        const SizedBox(height: 16.0),
        ElevatedButton.icon(
          onPressed: _submitQuestion,
          icon: const Icon(Icons.send_rounded),
          label: const Text('Submit Question'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFA91B60),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnswerInput(int questionId) {
    return Container(
      margin: const EdgeInsets.only(top: 16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: const Color(0xFFE0E0E0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _answerController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Write your answer here...',
              hintStyle: TextStyle(color: Colors.grey[400]),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: const BorderSide(color: Color(0xFFA91B60), width: 2.0),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 16.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _editingQuestionId = null;
                    _answerController.clear();
                  });
                },
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              const SizedBox(width: 12.0),
              ElevatedButton.icon(
                onPressed: () => _submitAnswer(questionId),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Submit Answer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFA91B60),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 12.0,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Enum for report reasons
enum ReportReason {
  inappropriateContent,
  spam,
  misleadingInformation,
  other,
}

// Helper function to get the reason text
String getReportReasonText(ReportReason reason) {
  switch (reason) {
    case ReportReason.inappropriateContent:
      return 'Inappropriate Content';
    case ReportReason.spam:
      return 'Spam';
    case ReportReason.misleadingInformation:
      return 'Misleading Information';
    case ReportReason.other:
      return 'Other';
    default:
      return '';
  }
}

class ReportPostDialog extends StatefulWidget {
  @override
  _ReportPostDialogState createState() => _ReportPostDialogState();
}

class _ReportPostDialogState extends State<ReportPostDialog> {
  ReportReason? _selectedReason;
  final TextEditingController _otherReasonController = TextEditingController();

  @override
  void dispose() {
    _otherReasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: const [
          Icon(Icons.report_problem, color: Color(0xFFA91B60)),
          SizedBox(width: 8),
          Text('Report Post', 
            style: TextStyle(
              color: Color(0xFFA91B60),
              fontWeight: FontWeight.bold
            )
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'Please select a reason for reporting:',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
            ),
            const Divider(),
            ...ReportReason.values.map((reason) {
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _selectedReason == reason 
                      ? const Color(0xFFA91B60) 
                      : Colors.grey.shade300,
                  ),
                ),
                child: RadioListTile<ReportReason>(
                  title: Text(
                    getReportReasonText(reason),
                    style: TextStyle(
                      color: _selectedReason == reason 
                        ? const Color(0xFFA91B60) 
                        : Colors.black87,
                    ),
                  ),
                  value: reason,
                  groupValue: _selectedReason,
                  activeColor: const Color(0xFFA91B60),
                  onChanged: (ReportReason? value) {
                    setState(() {
                      _selectedReason = value;
                    });
                  },
                ),
              );
            }).toList(),
            if (_selectedReason == ReportReason.other)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: TextField(
                  controller: _otherReasonController,
                  decoration: InputDecoration(
                    hintText: 'Please specify your reason...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: Color(0xFFA91B60),
                        width: 2,
                      ),
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
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Cancel',
            style: TextStyle(color: Colors.grey),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFA91B60),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () {
            if (_selectedReason != null) {
              if (_selectedReason == ReportReason.other && 
                  _otherReasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please specify your reason'),
                    backgroundColor: Color(0xFFA91B60),
                  ),
                );
                return;
              }
              // Return a map containing both the reason and the custom text if applicable
              Navigator.of(context).pop({
                'reason': _selectedReason,
                'customReason': _selectedReason == ReportReason.other 
                  ? _otherReasonController.text 
                  : null,
              });
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please select a report reason'),
                  backgroundColor: Color(0xFFA91B60),
                ),
              );
            }
          },
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('Submit Report'),
          ),
        ),
      ],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}
