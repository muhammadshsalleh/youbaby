import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:youbaby/community_page.dart';
import 'package:youbaby/home_page.dart';
import 'package:youbaby/momlibrary_page.dart';
import 'package:youbaby/shopPage.dart';
import 'package:youbaby/profile_page.dart';
import 'package:youbaby/charity_post.dart';
import 'package:youbaby/text_limit.dart';
import 'package:youbaby/charity_addpost.dart';
import 'dart:async';


class CharityPage extends StatefulWidget {
  final int userID;

  const CharityPage({super.key, required this.userID});

  @override
  _CharityPageState createState() => _CharityPageState();
}

class _CharityPageState extends State<CharityPage> {
  int _selectedIndex = 2;
  List<Map<String, dynamic>> _charityPosts = [];
  List<Map<String, dynamic>> _filteredPosts = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';
  Timer? _debounce;
  String? postAuthorName;

  @override
  void initState() {
    super.initState();
    _fetchCharityPosts();
  }

  Future<void> _fetchCharityPosts() async {
  try {
    final response = await Supabase.instance.client
        .from('charity_posts')
        .select(
            'id, title, content, image_url, created_at, status, user_id, likes_count, qna_count, users!inner(parentName)')
        .order('created_at', ascending: false);

    final likesResponse = await Supabase.instance.client
        .from('charity_post_like')
        .select('post_id')
        .eq('user_id', widget.userID);

    final likedPosts = (likesResponse as List<dynamic>)
        .map((like) => like['post_id'] as int)
        .toList();

    // final qnaCounts = await _fetchQnACounts();

    setState(() {
      _charityPosts = (response as List<dynamic>)
          .map((post) => {
                ...post as Map<String, dynamic>,
                'isLiked': likedPosts.contains(post['id']),
                'authorName': post['users']['parentName'], // Add this line
              })
          .where((post) =>
              post['title'].isNotEmpty || post['content'].isNotEmpty)
          .toList();
      _filterPosts();
      _isLoading = false;
    });
  } catch (e) {
    print('Error fetching charity posts: $e');
    setState(() {
      _isLoading = false;
    });
  }
}

  Future<void> _toggleLike(
      int postId, int currentLikesCount, bool isLiked) async {
    try {
      final newLikesCount =
          isLiked ? currentLikesCount - 1 : currentLikesCount + 1;

      await Supabase.instance.client
          .from('charity_posts')
          .update({'likes_count': newLikesCount}).eq('id', postId);

      if (isLiked) {
        await Supabase.instance.client
            .from('charity_post_like')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', widget.userID);
      } else {
        await Supabase.instance.client.from('charity_post_like').insert(
            {'post_id': postId, 'user_id': widget.userID, 'liked': true});
      }

      setState(() {
        final postIndex =
            _charityPosts.indexWhere((post) => post['id'] == postId);
        if (postIndex != -1) {
          _charityPosts[postIndex]['likes_count'] = newLikesCount;
          _charityPosts[postIndex]['isLiked'] = !isLiked;
        }
        _filterPosts();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating like status: $e')),
      );
    }
  }

  Future<Map<int, int>> _fetchQnACounts() async {
  try {
    // Fetch data directly from the charity_posts table
    final response = await Supabase.instance.client
        .from('charity_posts')
        .select('id, qna_count');

    Map<int, int> qnaCounts = {};

    // Loop through the response and populate the qnaCounts map
    for (var item in response as List<dynamic>) {
      int postId = item['id']; // Assuming 'id' is the primary key in charity_posts
      int count = item['qna_count'] ?? 0; // Get the qna_count, default to 0 if null

      qnaCounts[postId] = count;
    }

    return qnaCounts;
  } catch (e) {
    print('Error fetching QnA counts: $e');
    return {};
  }
}


  Future<void> _updateCharityPostsQnACounts(Map<int, int> qnaCounts) async {
    try {
      final batch = qnaCounts.entries.map((entry) {
        return Supabase.instance.client
            .from('charity_posts')
            .update({'qna_count': entry.value})
            .eq('id', entry.key);
      }).toList();

      await Future.wait(batch);
    } catch (e) {
      print('Error updating charity posts QnA counts: $e');
    }
  }

  void _filterPosts({String? searchTerm}) {
    setState(() {
      _filteredPosts = _charityPosts.where((post) {
        final matchesSearch = searchTerm == null ||
            searchTerm.isEmpty ||
            post['title'].toLowerCase().contains(searchTerm.toLowerCase()) ||
            post['content'].toLowerCase().contains(searchTerm.toLowerCase());

        final isMyPost = post['user_id'] == widget.userID;

        if (_selectedCategory == 'All') {
          return matchesSearch && post['status'] == 'Available';
        } else if (_selectedCategory == 'My Post') {
          return matchesSearch && isMyPost;
        }

        return false; // This line should never be reached
      }).toList();
    });
  }

  Widget _categoryButton(String category) {
    return ElevatedButton(
      onPressed: () {
        setState(() {
          _selectedCategory = category;
        });
        _filterPosts();
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: _selectedCategory == category
            ? const Color(0xFFA91B60)
            : Colors.grey[300],
        foregroundColor:
            _selectedCategory == category ? Colors.white : Colors.black,
      ),
      child: Text(category),
    );
  }

  
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      switch (index) {
        case 0:
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => ProfilePage(userID: widget.userID)),
          );
          break;
        case 1:
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => MomLibraryPage(userID: widget.userID)),
          );
          break;
        case 2:
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) => HomePage(userID: widget.userID)),
          );
          break;
        case 3:
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => CommunityPage(userID: widget.userID)),
          );
          break;
        case 4:
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ShopPage()),
          );
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Charity',
          style: TextStyle(
            color: Color(0xFFF6F2FF),
            fontSize: 24.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFFA91B60),
      ),
      backgroundColor: const Color(0xFFffffff),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search posts...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(30.0)),
                ),
              ),
              onChanged: (value) {
                if (_debounce?.isActive ?? false) _debounce!.cancel();
                _debounce = Timer(const Duration(milliseconds: 500), () {
                  _filterPosts(searchTerm: value);
                });
              },
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                _categoryButton('All'),
                const SizedBox(width: 10),
                _categoryButton('My Post'),
                const SizedBox(width: 10),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: _filteredPosts.length,
                    itemBuilder: (context, index) {
                      final post = _filteredPosts[index];
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CharityPost(
                                postId: post['id'],
                                userId: widget.userID,
                                title: post['title'],
                                content: post['content'],
                                imageUrl: post['image_url'],
                                status: post['status'],
                              ),
                            ),
                          );
                        },
                        child: _buildCharityCard(
                          context,
                          postId: post['id'],
                          title: post['title'],
                          content: post['content'],
                          imageUrl: post['image_url'],
                          status: post['status'],
                          userId: post['user_id'],
                          likesCount: post['likes_count'],
                          qnaCount: post['qna_count'],
                          isLiked: post['isLiked'], // Use the correct field name
                          postAuthorName: post['users']['parentName']
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CharityAddPost(userID: widget.userID),
            ),
          );
          _fetchCharityPosts();
        },
        backgroundColor: const Color(0xFFA91B60),
        child: const Icon(
          Icons.add,
          color: Color(0xFFEBE0D0),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFFA91B60),
        selectedItemColor: const Color(0xFFA91B60),
        unselectedItemColor: const Color(0xFFEC9EC0),
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'You',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.book),
            label: 'Mom`s Library',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.forum),
            label: 'Community',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shop),
            label: 'Shop',
          ),
        ],
      ),
    );
  }

  Future<void> _showConfirmationDialog(String action, int postId) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        String dialogMessage = 'Are you sure you want to $action this post?';
        String buttonText = action;

        if (action == 'mark as unavailable') {
          dialogMessage +=
              ' Post will not appear in the main page after this action.';
          buttonText = 'Mark as Unavailable';
        } else if (action == 'mark as available') {
          buttonText = 'Mark as Available';
        } else if (action == 'archive') {
          dialogMessage +=
              ' Post will not appear in the main page after this action.';
          buttonText = 'Archive';
        } else if (action == 'unarchive') {
          buttonText = 'Unarchive';
        }

        return AlertDialog(
          title: Text('Confirm $action'),
          content: Text(dialogMessage),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text(buttonText),
              onPressed: () async {
                Navigator.of(context).pop();
                if (action == 'delete') {
                  await _deletePost(postId);
                } else if (action == 'mark as unavailable' ||
                    action == 'mark as available') {
                  await _toggleAvailability(
                      postId,
                      action == 'mark as unavailable'
                          ? 'Unavailable'
                          : 'Available');
                } else if (action == 'archive' || action == 'unarchive') {
                  await _toggleArchive(
                      postId, action == 'unarchive' ? 'Unarchive' : 'Archive');
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _deletePost(int postId) async {
    try {
      await Supabase.instance.client
          .from('charity_posts')
          .delete()
          .eq('id', postId);

      await _fetchCharityPosts();
    } catch (e) {
      print('Error deleting post: $e');
    }
  }

  Future<void> _markAsUnavailable(int postId) async {
    try {
      await Supabase.instance.client
          .from('charity_posts')
          .update({'status': 'Unavailable'}).eq('id', postId);

      await _fetchCharityPosts();
    } catch (e) {
      print('Error marking post as unavailable: $e');
    }
  }

  Future<void> _markAsAVailable(int postId) async {
    try {
      await Supabase.instance.client
          .from('charity_posts')
          .update({'status': 'Available'}).eq('id', postId);

      await _fetchCharityPosts();
    } catch (e) {
      print('Error marking post as Available: $e');
    }
  }

  Future<void> _toggleAvailability(int postId, String newStatus) async {
    try {
      await Supabase.instance.client
          .from('charity_posts')
          .update({'status': newStatus}).eq('id', postId);

      await _fetchCharityPosts();
    } catch (e) {
      print('Error updating post status: $e');
    }
  }

  Future<void> _toggleArchive(int postId, String action) async {
    try {
      final newStatus = (action == 'archive') ? 'Archived' : 'Available';
      await Supabase.instance.client
          .from('charity_posts')
          .update({'is_archived': newStatus}).eq('id', postId);

      await _fetchCharityPosts();
    } catch (e) {
      print('Error updating post status: $e');
    }
  }

  Future<void> _archivePost(int postId) async {
    try {
      await Supabase.instance.client
          .from('charity_posts')
          .update({'status': 'Archived'}).eq('id', postId);

      await _fetchCharityPosts();
    } catch (e) {
      print('Error archiving post: $e');
    }
  }

  Widget _buildCharityCard(
    BuildContext context, {
    required int postId,
    required String title,
    required String content,
    required String? imageUrl,
    required String status,
    required int userId,
    required int likesCount,
    required int qnaCount,
    required bool isLiked,
    required String postAuthorName,
  }) {
    Color statusColor;
    if (status == 'Available') {
      statusColor = Colors.green;
    } else if (status == 'Unavailable') {
      statusColor = Colors.red;
    } else if (status == 'Archived') {
      statusColor = Colors.grey;
    } else {
      statusColor = Colors.black;
    }

    return Card(
      elevation: 4.0,
      color: const Color(0xFFF6F2FF),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20.0,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF000000),
                    ),
                  ),
                  const SizedBox(height: 4.0),
                    Text(
                      'By $postAuthorName', // Add author name
                      style: const TextStyle(
                        fontSize: 12.0,
                        color: Color(0xFFA91B60),
                      ),
                    ),
                    ],
                  ),
                
                  

                ),
                if (userId == widget.userID)
                  PopupMenuButton<String>(
                    
                      onSelected: (String result) {
                      if (result == 'toggle_availability') {
                        _showConfirmationDialog(
                          status == 'Available' ? 'mark as unavailable' : 'mark as available',
                          postId
                        );
                      } else if (result == 'toggle_archive') {
                        _showConfirmationDialog(
                          status == 'Archived' ? 'unarchive' : 'archive',
                          postId
                        );
                      }
                    },
                    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(
                        value: 'toggle_availability',
                        child: Text(status == 'Available' ? 'Mark as Unavailable' : 'Mark as Available'),
                      ),
                    ],
                      ),
              ],
            ), // end row
             Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  // GestureDetector(
                  //   onTap: () {
                  //     _toggleLike(postId, likesCount, isLiked);
                  //   },
                  //   child: Row(
                  //     children: [
                  //       Icon(
                  //         isLiked ? Icons.thumb_up : Icons.thumb_up_alt_outlined,
                  //         color: const Color(0xFFA91B60),
                  //       ),
                  //       const SizedBox(width: 4.0),
                  //       Text(
                  //         likesCount.toString(),
                  //         style: const TextStyle(color: Color(0xFFA91B60)),
                  //       ),
                  //     ],
                  //   ),
                  // ),
                ]
             ),
            const SizedBox(height: 8.0),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Text(
                status,
                style: const TextStyle(
                  fontSize: 12.0,
                  fontStyle: FontStyle.italic,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 8.0),
            Text(
              content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14.0,
                color: Color.fromARGB(255, 66, 66, 66),
              ),
            ),
            if (imageUrl != null && imageUrl.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Image.network(
                  imageUrl,
                  height: 250,
                  width: 300,
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(height: 8.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () {
                    _toggleLike(postId, likesCount, isLiked);
                  },
                  child: Row(
                    children: [
                      Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        color: const Color(0xFFA91B60),
                      ),
                      const SizedBox(width: 4.0),
                       if (likesCount > 0)
                      Text(
                        likesCount.toString(),
                        style: const TextStyle(color: Color(0xFFA91B60)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16.0),
                Row(
                  children: [
                    const Icon(Icons.question_answer_outlined, color: Color(0xFFA91B60)),
                    const SizedBox(width: 4.0),

                     if (qnaCount > 0)
                    Text(
                      qnaCount.toString(),
                      style: const TextStyle(color: Color(0xFFA91B60)),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
