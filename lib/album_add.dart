import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:supabase_flutter/supabase_flutter.dart';

class AlbumAddPage extends StatefulWidget {
  final int userID;

  const AlbumAddPage({Key? key, required this.userID}) : super(key: key);

  @override
  _AlbumAddPageState createState() => _AlbumAddPageState();
}

class _AlbumAddPageState extends State<AlbumAddPage> {
  final _captionController = TextEditingController();
  final _tagController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _albumNameController = TextEditingController();

  File? _imageFile;
  String? _imageUrl;
  String? _milestone;
  bool _isUploading = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  List<String> _selectedTags = [];
  bool _hasExistingAlbum = false;

  // Predefined milestones
  final List<String> _milestones = [
    'First Smile',
    'First Laugh',
    'First Steps',
    'First Words',
    'First Tooth',
    'First Birthday',
    'First Haircut',
    'First Food'
  ];

  @override
  void initState() {
    super.initState();
    _checkExistingAlbum();
  }

  Future<void> _checkExistingAlbum() async {
    try {
      final albumResponse = await Supabase.instance.client
          .from('albums')
          .select()
          .eq('baby_id', widget.userID);

      setState(() {
        _hasExistingAlbum = albumResponse.isNotEmpty;
        if (_hasExistingAlbum) {
          _albumNameController.text = albumResponse[0]['name'] ?? '';
        }
      });
    } catch (error) {
      print('Error checking existing album: $error');
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    _tagController.dispose();
    _albumNameController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
        _isUploading = true;
      });

      await _uploadImage();
    }
  }

  Future<void> _uploadImage() async {
    if (_imageFile == null) return;

    try {
      final fileName =
          'album_${widget.userID}_${DateTime.now().millisecondsSinceEpoch}${path.extension(_imageFile!.path)}';
      final bytes = await _imageFile!.readAsBytes();

      final response = await Supabase.instance.client.storage
          .from('babyAlbum')
          .uploadBinary(fileName, bytes);

      print('Image uploaded successfully! Path: $response');

      final imageUrl = Supabase.instance.client.storage
          .from('babyAlbum')
          .getPublicUrl(fileName);

      setState(() {
        _imageUrl = imageUrl;
        _isUploading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image uploaded successfully!')),
      );
    } catch (error) {
      setState(() {
        _isUploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading image: $error')),
      );
    }
  }

  void _addTag(String tag) {
    if (tag.isNotEmpty && !_selectedTags.contains(tag)) {
      setState(() {
        _selectedTags.add(tag);
        _tagController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _selectedTags.remove(tag);
    });
  }

  Future<void> _submitPhoto() async {
    if (_imageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select and upload an image first')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      String albumId;

      // Create or get album
      if (!_hasExistingAlbum) {
        final albumData = {
          'baby_id': widget.userID,
          'name': _albumNameController.text.trim(),
          'cover_photo_url': _imageUrl, // Set first photo as cover
        };

        final newAlbumResponse = await Supabase.instance.client
            .from('albums')
            .insert(albumData)
            .select()
            .single();

        albumId = newAlbumResponse['id'];
      } else {
        final albumResponse = await Supabase.instance.client
            .from('albums')
            .select()
            .eq('baby_id', widget.userID)
            .single();
        albumId = albumResponse['id'];
      }

      // Insert photo
      final photoResponse = await Supabase.instance.client
          .from('albums_photos')
          .insert({
            'album_id': albumId,
            'photo_url': _imageUrl,
            'caption': _captionController.text.isEmpty
                ? null
                : _captionController.text,
            'milestone': _milestone,
          })
          .select()
          .single();

      // Handle tags
      for (String tag in _selectedTags) {
        // Insert or get tag
        final tagResponse = await Supabase.instance.client
            .from('albums_tags')
            .upsert({'name': tag}, onConflict: 'name')
            .select()
            .single();

        // Create photo-tag relationship
        await Supabase.instance.client.from('albums_photo_tags').insert({
          'photo_id': photoResponse['id'],
          'tag_id': tagResponse['id'],
        });
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (error) {
      print('Error submitting photo: $error');
      setState(() {
        _errorMessage = 'Failed to add photo: $error';
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
        title: const Text('Add New Photo'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GestureDetector(
                onTap: _showImageSourceDialog,
                child: Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _imageFile != null
                      ? Stack(
                          alignment: Alignment.center,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                _imageFile!,
                                fit: BoxFit.cover,
                                height: 200,
                                width: double.infinity,
                              ),
                            ),
                            if (_isUploading)
                              Container(
                                color: Colors.black26,
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                          ],
                        )
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate,
                                  size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text('Select a photo',
                                  style: TextStyle(color: Colors.grey[600])),
                            ],
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),

              //album name
              if (!_hasExistingAlbum) ...[
                TextFormField(
                  controller: _albumNameController,
                  decoration: const InputDecoration(
                    labelText: 'Album Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter an album name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],

              TextFormField(
                controller: _captionController,
                decoration: const InputDecoration(
                  labelText: 'Caption (Optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _milestone,
                decoration: const InputDecoration(
                  labelText: 'Milestone (Optional)',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('No Milestone'),
                  ),
                  ..._milestones.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                ],
                onChanged: (String? value) {
                  setState(() => _milestone = value);
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _tagController,
                      decoration: const InputDecoration(
                        labelText: 'Add Tags (Optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => _addTag(_tagController.text.trim()),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _selectedTags.map((tag) {
                  return Chip(
                    label: Text(tag),
                    onDeleted: () => _removeTag(tag),
                  );
                }).toList(),
              ),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed:
                    (_isSubmitting || _isUploading) ? null : _submitPhoto,
                child: _isSubmitting
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(width: 16),
                          Text('Saving...'),
                        ],
                      )
                    : const Text('Upload Photo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
