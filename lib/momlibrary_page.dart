import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'read_page.dart'; // Import the ReadPage

class MomLibraryPage extends StatefulWidget {
  final int userID;
  // final String title;
  // final String author;
  // final DateTime publishDate;

  const MomLibraryPage({super.key, required this.userID});

  @override
  _MomLibraryPageState createState() => _MomLibraryPageState();
}

class _MomLibraryPageState extends State<MomLibraryPage> {
  final _searchController = TextEditingController();
  String _selectedCategory = 'All';
  List<Map<String, dynamic>> _articles = [];
  Timer? _debounce;
  bool _isLoading = true; // Track loading state

  @override
  void initState() {
    super.initState();
    _fetchArticles(); 
  }

 Future<void> _fetchArticles({String? searchTerm}) async {
  setState(() {
    _isLoading = true;
  });

  try {
    List<dynamic> response = [];
    
    if (searchTerm != null && searchTerm.isNotEmpty) {
      var searchTermLower = searchTerm.toLowerCase();
      
      // Fetch articles that match by title
      var titleMatches = await Supabase.instance.client
          .from('article2')
          .select('*, userAdmin(name)')
          .ilike('title', '%$searchTermLower%');

      // Fetch all articles that have tags (using is not null instead of neq)
      var tagMatches = await Supabase.instance.client
          .from('article2')
          .select('*, userAdmin(name)')
          .not('tags', 'is', null);  // Changed from neq to not is null

      // Combine results and filter on client side
      Set<String> seenIds = {};
      response = [...titleMatches, ...tagMatches].where((item) {
        final id = item['id'].toString();
        if (seenIds.contains(id)) {
          return false;
        }
        
        // Check title match
        bool titleMatch = item['title'].toString().toLowerCase().contains(searchTermLower);
        
        // Check tags match
        bool tagMatch = false;
        if (item['tags'] != null && item['tags'] is List) {
          List<String> tags = List<String>.from(item['tags']);
          tagMatch = tags.any((tag) => 
            tag.toLowerCase().contains(searchTermLower)
          );
        }

        if (titleMatch || tagMatch) {
          seenIds.add(id);
          return true;
        }
        return false;
      }).toList();

      // Apply category filter if needed
      if (_selectedCategory != 'All') {
        response = response.where((item) => 
          item['category'] == _selectedCategory
        ).toList();
      }
      
    } else {
      // If no search term, just get all articles or filter by category
      var query = Supabase.instance.client
          .from('article2')
          .select('*, userAdmin(name)');

      if (_selectedCategory != 'All') {
        query = query.eq('category', _selectedCategory);
      }

      response = await query;
    }

    setState(() {
      _articles = List<Map<String, dynamic>>.from(response.map((item) {
        final Map<String, dynamic> article = Map<String, dynamic>.from(item);
        if (article['created_at'] != null) {
          try {
            article['created_at'] = DateTime.parse(article['created_at']);
          } catch (e) {
            print('Error parsing date: $e');
            article['created_at'] = DateTime.now();
          }
        }
        return article;
      }));

      _articles.sort((a, b) {
        final DateTime? dateA = a['created_at'];
        final DateTime? dateB = b['created_at'];
        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;
        return dateB.compareTo(dateA);
      });
    });
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error fetching articles: $e')),
    );
    print('Error: $e');
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mom’s Library',
          style: TextStyle(
            color: Color(0xFFEBE0D0),
            fontSize: 20.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFFA91B60),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFF0F4F8), // Light pastel blue
              Color(0xFFECEFF1), // Very light grayish blue
              Color(0xFFDDE7EB), // Soft light gray with a hint of blue
              Color(0xFFE8EBEE), // Another light gray tone
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Search Bar
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: 'Search...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(30.0)),
                  ),
                ),
                onChanged: (value) {
                  if (_debounce?.isActive ?? false) _debounce!.cancel();
                  _debounce = Timer(const Duration(milliseconds: 500), () {
                    _fetchArticles(searchTerm: value);
                  });
                },
              ),
              const SizedBox(height: 16.0),

              // Category Buttons
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _categoryButton('All'),
                    const SizedBox(width: 10),
                    _categoryButton('Nutrition & Feeding'),
                    const SizedBox(width: 10),
                    _categoryButton('Baby Development'),
                    const SizedBox(width: 10),
                    _categoryButton('Mother’s Activities'),
                    const SizedBox(width: 10),
                    _categoryButton('Baby Health & Care'),
                    const SizedBox(width: 10),
                    _categoryButton('Baby Gear'),
                  ],
                ),
              ),
              const SizedBox(height: 16.0),

              // List of Articles or Loading/No Results Message
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _articles.isEmpty
                        ? const Center(
                            child: Text(
                              'No Results',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey,
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _articles.length,
                            itemBuilder: (context, index) {
                              final article = _articles[index];
                              return _buildArticleContainer(article);
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _categoryButton(String category) {
    final isSelected = _selectedCategory == category;
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? const Color(0xFFA91B60) : Colors.white,
        foregroundColor: isSelected ? Colors.white : Colors.black,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      onPressed: () {
        setState(() {
          _selectedCategory = category;
          _fetchArticles(searchTerm: _searchController.text);
        });
      },
      child: Text(category),
    );
  }

  Widget _buildArticleContainer(Map<String, dynamic> article) {
  String formattedDate = 'Date not available';
  if (article['created_at'] != null) {
    try {
      final date = article['created_at'] is DateTime
          ? article['created_at']
          : DateTime.parse(article['created_at'].toString());
      formattedDate = DateFormat('dd MMMM yyyy').format(date);
    } catch (e) {
      print('Error formatting date: $e');
    }
  }

  String authorName = 'Unknown';
  if (article['userAdmin'] != null && article['userAdmin']['name'] != null) {
    authorName = article['userAdmin']['name'];
  }

  // Convert tags from dynamic to List<String>
  List<String> tags = [];
  if (article['tags'] != null) {
    tags = List<String>.from(article['tags']);
  }

  return Card(
    elevation: 1,
    margin: const EdgeInsets.only(bottom: 16.0),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    child: InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReadPage(
              articleId: article['id'],  
              userId: widget.userID,
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            article['images'] != null && article['images'].isNotEmpty
              ? Image.network(
                article['images'],
                width: 50,
                height: 50,
                fit: BoxFit.cover,
              )
              : const Icon(Icons.article),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article['title'] ?? 'No Title',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Author: $authorName',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Published: $formattedDate',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: tags.map((tag) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFA91B60).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '#$tag',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFA91B60),
                          ),
                        ),
                      )).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
  }
}
