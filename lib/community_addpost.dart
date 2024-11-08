import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;

class CommunityAddPostPage extends StatefulWidget {
  final int userID;

  const CommunityAddPostPage({super.key, required this.userID});

  @override
  _CommunityAddPostPageState createState() => _CommunityAddPostPageState();
}

class _CommunityAddPostPageState extends State<CommunityAddPostPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;
  File? _imageFile;
  String? _imageUrl;

  bool _isUploading = false;

  Future<void> _pickAndUploadImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
        _isUploading = true; // Start uploading
      });

      // Upload the image immediately
      await _uploadAndSaveImage();
    }
  }

  Future<void> _uploadAndSaveImage() async {
    if (_imageFile == null) return;

    try {
      final fileName =
          'community_post_${widget.userID}_${DateTime.now().millisecondsSinceEpoch}${path.extension(_imageFile!.path)}';
      final bytes = await _imageFile!.readAsBytes();

      final response = await Supabase.instance.client.storage
          .from('community')
          .uploadBinary(fileName, bytes);

      print('Image uploaded successfully! Path: $response');

      final imageUrl = Supabase.instance.client.storage
          .from('community')
          .getPublicUrl(fileName);

      setState(() {
        _imageUrl = imageUrl;
        _isUploading = false; // Image upload finished
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image uploaded successfully!')),
      );
    } catch (error) {
      setState(() {
        _isUploading = false; // Reset uploading state on failure
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading image: $error')),
      );
    }
  }

  Future<void> _submitPost() async {
    if (!_formKey.currentState!.validate() || _isUploading) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final response =
          await Supabase.instance.client.from('community_posts').insert({
        'user_Id': widget.userID,
        'title': _titleController.text,
        'content': _contentController.text,
        'created_at': DateTime.now().toIso8601String(),
        'image_url': _imageUrl,
      }) .select()
        .single(); // Fetches the inserted row

     // Check if the response is empty or null
    if (response == null || response.isEmpty) {
      throw Exception('Failed to add post, no data returned.');
    }

    // If the post was successfully added, show a success message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Post added successfully!')),
    );
    Navigator.pop(context); // Navigate back after successful submission
  } catch (error) {
    setState(() {
      _errorMessage = 'Failed to add post: $error';
    });
  } finally {
    setState(() {
      _isSubmitting = false;
    });
  }
}

  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Choose Image Source'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                GestureDetector(
                  child: const Text('Camera'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _pickAndUploadImage(ImageSource.camera);
                  },
                ),
                const Padding(padding: EdgeInsets.all(8.0)),
                GestureDetector(
                  child: const Text('Gallery'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _pickAndUploadImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Community Post'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Post Title'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Title is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _contentController,
                decoration: const InputDecoration(labelText: 'Post Content'),
                maxLines: 5,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Content is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: _imageFile != null
                          ? Stack(
                              alignment: Alignment.center,
                              children: [
                                Image.file(_imageFile!, fit: BoxFit.cover),
                                if (_isUploading)
                                  const Center(
                                    child:
                                        CircularProgressIndicator(), // Loading indicator
                                  ),
                              ],
                            )
                          : const Icon(Icons.image, size: 50),
                    ),
                    if (_isUploading)
                      const Center(
                        child: CircularProgressIndicator(),
                      ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: IconButton(
                        icon: const Icon(Icons.camera_alt),
                        onPressed: _showImageSourceDialog,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16.0),
              if (_errorMessage != null)
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              const SizedBox(height: 16.0),
              ElevatedButton(
                onPressed: (_isSubmitting || _isUploading) ? null : _submitPost,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFA91B60),
                  foregroundColor: Colors.white, 
                ),
                child: _isSubmitting
                    ? const CircularProgressIndicator()
                    : const Text('Submit'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
