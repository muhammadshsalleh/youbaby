import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:youbaby/commentcommunity_page.dart';
import 'package:youbaby/home_page.dart';
import 'package:youbaby/momlibrary_page.dart';
import 'package:youbaby/shopPage.dart';
import 'package:youbaby/profile_page.dart';
import 'package:youbaby/settings_page.dart';
import 'package:youbaby/text_limit.dart';
import 'package:youbaby/community_addpost.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:path/path.dart' as path;

//constructor
class CommunityPage extends StatefulWidget {
  final int userID;

  const CommunityPage({super.key, required this.userID});

  @override
  _CommunityPageState createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  int _selectedIndex = 2;
  List<Map<String, dynamic>> _communityPosts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCommunityPosts();
  }

  Future<void> _fetchCommunityPosts() async {
    final response = await Supabase.instance.client
        .from('community_posts')
        .select(
            'id, title, content, image_url, likes_count, comments_count, users(parentName)')
        .order('created_at', ascending: false);

    final likesResponse = await Supabase.instance.client
        .from('post_like')
        .select('post_id')
        .eq('user_id', widget.userID);

    final likedPosts = (likesResponse as List<dynamic>)
        .map((like) => like['post_id'] as int)
        .toList();

    setState(() {
      _communityPosts = (response as List<dynamic>)
          .map((post) {
            final postData = post as Map<String, dynamic>;
            return {
              'id': postData['id'],
              'title': postData['title'],
              'content': postData['content'],
              'image_url': postData['image_url'], //added image
              'likes_count': postData['likes_count'],
              'comments_count': postData['comments_count'],
              'author': postData['users'] != null
                  ? postData['users']['parentName']
                  : 'Unknown',
              'isLiked':
                  likedPosts.contains(postData['id']), // Check if post is liked
            };
          })
          .where(
              (post) => post['title'].isNotEmpty || post['content'].isNotEmpty)
          .toList();
      _isLoading = false;
    });
  }

  Future<void> _toggleLike(
      int postId, int currentLikesCount, bool isLiked) async {
    try {
      final newLikesCount =
          isLiked ? currentLikesCount - 1 : currentLikesCount + 1;

      // Update the likes_count in the post
      await Supabase.instance.client
          .from('community_posts')
          .update({'likes_count': newLikesCount}).eq('id', postId);

      if (isLiked) {
        // Remove the like from the post_likes table
        await Supabase.instance.client
            .from('post_like')
            .delete()
            .eq('post_id', postId)
            .eq('user_id', widget.userID);
      } else {
        // Add the like to the post_likes table
        await Supabase.instance.client.from('post_like').insert(
            {'post_id': postId, 'user_id': widget.userID, 'liked': true});
      }

      // Update the local state
      setState(() {
        final postIndex =
            _communityPosts.indexWhere((post) => post['id'] == postId);
        if (postIndex != -1) {
          _communityPosts[postIndex]['likes_count'] = newLikesCount;
          _communityPosts[postIndex]['isLiked'] = !isLiked;
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating like status: $e')),
      );
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      int _selectedIndex = 2;
      switch (index) {
        case 0:
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => ProfilePage(userID: widget.userID!)),
          );
          break;
        case 1:
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => MomLibraryPage(userID: widget.userID!)),
          );
          break;
        case 2:
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) => HomePage(userID: widget.userID!)),
          );
          break;
        case 3:
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => CommunityPage(userID: widget.userID!)),
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
          'Community',
          style: TextStyle(
            color: Color(0xFFF6F2FF),
            fontSize: 24.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFFA91B60),
      ),
      backgroundColor: const Color(0xFFffffff),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: _communityPosts.length,
              itemBuilder: (context, index) {
                final post = _communityPosts[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CommentsPage(
                          //if post to communitypage, add here

                          postId: post['id'],
                          userId: widget.userID,
                          postTitle: post['title'],
                          postContent: post['content'],
                          postImage: post['image_url'],
                          postAuthor: post['author'] //error here when click post w image
                        ),
                      ),
                    );
                  },
                  child: _buildCommunityCard(
                    context,
                    title: post['title'],
                    content: post['content'],
                    imageUrl: post['image_url'],
                    likesCount: post['likes_count'],
                    commentsCount: post['comments_count'],
                    author: post['author'],
                    postId: post['id'], // Pass the post ID to the card
                    isLiked: post['isLiked'], // Pass the liked status
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CommunityAddPostPage(userID: widget.userID),
            ),
          );
          _fetchCommunityPosts();

          if (result == true) {
            _fetchCommunityPosts();
          }
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
        currentIndex: 3, // This is the Community page
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

  Widget _buildCommunityCard(
    BuildContext context, {
    required String title,
    required String content,
    required String? imageUrl,
    required int likesCount,
    required int commentsCount,
    required String author,
    required int postId, // Accept the post ID as a parameter
    required bool isLiked, // Accept the liked status as a parameter
  }) {
    return Card(
      elevation: 4.0,
      color: const Color(0xFFF6F2FF),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title.isNotEmpty)
              Text(
                title,
                // overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 20.0,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF000000),
                ),
              ),
            const SizedBox(height: 8.0),
            Text(
              'Posted by: $author',
              style: const TextStyle(
                fontSize: 12.0,
                fontWeight: FontWeight.w500,
                color: Color(0xFFA91B60),
              ),
            ),
            const SizedBox(height: 4.0),
            Text(
              content,
              // limitText(content),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16.0,
                color: Color.fromARGB(255, 66, 66, 66),
              ),
            ),
            const SizedBox(height: 4.0),

            if (imageUrl != null && imageUrl.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: Image.network(
                    imageUrl,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Text('Failed to load image'),
                      );
                    },
                  ),
                ),
              ),

            if (title.isNotEmpty) const SizedBox(height: 16.0),
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
                        isLiked
                            ? Icons.thumb_up
                            : Icons
                                .thumb_up_alt_outlined, // Change icon based on state
                        color: isLiked
                            ? const Color(0xFFA91B60)
                            : const Color(
                                0xFFA91B60), // Change color based on state
                      ),
                      const SizedBox(width: 4.0),
                      Text(
                        likesCount.toString(),
                        style: const TextStyle(color: Color(0xFFA91B60)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16.0),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CommentsPage(
                          postId: postId, // Pass the correct post ID here
                          userId: widget.userID, // Pass the correct userId
                          postTitle: title,
                          postContent: content,
                          postImage: imageUrl,
                          postAuthor: author,
                        ),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      const Icon(Icons.comment, color: Color(0xFFA91B60)),
                      const SizedBox(width: 4.0),
                      Text(
                        commentsCount.toString(),
                        style: const TextStyle(color: Color(0xFFA91B60)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
