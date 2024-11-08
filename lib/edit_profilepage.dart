import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import 'dart:convert';

class EditProfilePage extends StatefulWidget {
  final int userID; // User ID passed to the EditProfilePage

  const EditProfilePage({super.key, required this.userID});

  @override
  _EditProfilePageState createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();

  String? parentName;
  String? email;
  String? babyName;
  String? babyGender;
  DateTime? babyBirthday;
  String? phoneNumber;
  String? role;
  String? imageUrl;
  File? _imageFile;
  String? _imageUrl;
  String? selectedState;
  String? selectedDistrict;
  List<String> states = [];
  List<String> districts = [];

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  // Future<List<String>> fetchStates() async {
  //   final response = await http.get(Uri.parse(
  //       'http://api.geonames.org/countrySubdivisionJSON?lat=4.2105&lng=101.9758&username=YOUR_USERNAME'));
  // }

  Future<void> _fetchUserProfile() async {
    try {
      final response = await Supabase.instance.client
          .from('users')
          .select(
              'parentName, email, babyName, babyGender, babyBirthday, phoneNumber, role, image')
          .eq('id', widget.userID)
          .single();

      setState(() {
        parentName = response['parentName'];
        email = response['email'];
        babyName = response['babyName'];
        babyGender = response['babyGender'];
        babyBirthday = response['babyBirthday'] != null
            ? DateTime.parse(response['babyBirthday'])
            : null;
        phoneNumber = response['phoneNumber'];
        role = response['role'];
        //imageUrl = response['image'];
        _imageUrl = response['image'];
        isLoading = false;
      });

      if (_imageUrl != null) {
        _loadImageFromStorage(_imageUrl!);
      }
    } catch (e) {
      print('Error fetching user profile: $e');
    }
  }

  Future<void> _loadImageFromStorage(String imagePath) async {
    try {
      final response = await Supabase.instance.client.storage
          .from('profiles')
          .download(imagePath);

      setState(() {
        _imageFile = File.fromRawPath(response);
      });
    } catch (e) {
      print('Error loading image from storage: $e');
    }
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });

      // Upload the image immediately
      await _uploadAndSaveImage();
    }
  }

  Future<void> _uploadAndSaveImage() async {
    if (_imageFile == null) return;

    try {
      final fileName =
          'profile_${widget.userID}_${DateTime.now().millisecondsSinceEpoch}${path.extension(_imageFile!.path)}';
      final bytes = await _imageFile!.readAsBytes();

      final response = await Supabase.instance.client.storage
          .from('profiles')
          .uploadBinary(fileName, bytes);

      if (response != null) {
        //throw response;
      }

      final imageUrl = Supabase.instance.client.storage
          .from('profiles')
          .getPublicUrl(fileName);

      // Update the user profile with the new image URL
      final updateResponse = await Supabase.instance.client
          .from('users')
          .update({'image': imageUrl}).eq('id', widget.userID);

      if (updateResponse.error != null) {
        throw updateResponse.error!;
      }

      setState(() {
        _imageUrl = imageUrl;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile image updated successfully!')),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating profile image: $error')),
      );
    }
  }

  Future<String?> _uploadImage() async {
    if (_imageFile == null) return null;

    try {
      final fileName =
          'profile_${widget.userID}_${DateTime.now().millisecondsSinceEpoch}${path.extension(_imageFile!.path)}';
      final bytes = await _imageFile!.readAsBytes();

      final response = await Supabase.instance.client.storage
          .from('profiles')
          .uploadBinary(fileName, bytes);

      // if (response != null) {
      //   throw response;
      // }

      final imageUrl = Supabase.instance.client.storage
          .from('profiles')
          .getPublicUrl(fileName);

      return imageUrl;
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading image: $error')),
      );
      return null;
    }
  }

  Future<void> _updateUserProfile() async {
    if (!_formKey.currentState!.validate()) return;

    _formKey.currentState!.save();

    try {
      String? newImageUrl = _imageUrl;

      if (_imageFile != null) {
        newImageUrl = await _uploadImage();
        if (newImageUrl == null) return; // Image upload failed
      }

      final response = await Supabase.instance.client.from('users').update({
        'parentName': parentName,
        'email': email,
        'babyName': babyName,
        'babyGender': babyGender,
        'babyBirthday': babyBirthday?.toIso8601String(),
        'phoneNumber': phoneNumber,
        'role': role,
        'image': newImageUrl,
      }).eq('id', widget.userID);

      if (response.error != null) {
        throw response.error!;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully!')),
      );
      Navigator.pop(context, true);
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile: $error')),
      );
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

  String calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    final difference = now.difference(birthDate);
    final days = difference.inDays;

    if (days < 7) {
      return '$days day${days == 1 ? '' : 's'} old';
    } else if (days < 30) {
      final weeks = (days / 7).floor();
      return '$weeks week${weeks == 1 ? '' : 's'} old';
    } else if (days < 365) {
      final months = (days / 30).floor();
      return '$months month${months == 1 ? '' : 's'} old';
    } else {
      final years = (days / 365).floor();
      return '$years year${years == 1 ? '' : 's'} old';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            color: Color(0xFFEBE0D0),
            fontSize: 24.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFFA91B60),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircleAvatar(
                            radius: 60.0,
                            backgroundColor: const Color(0xFFEBE0D0),
                            backgroundImage: _imageFile != null
                                ? FileImage(_imageFile!)
                                : (_imageUrl != null
                                    ? NetworkImage(_imageUrl!)
                                    : const AssetImage(
                                        'assets/profile.jpg')) as ImageProvider,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: IconButton(
                              icon: const Icon(Icons.camera_alt,
                                  color: Color(0xFFA91B60)),
                              onPressed: _showImageSourceDialog,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildTextField('Parent Name', parentName, (value) {
                      parentName = value;
                    }),
                    _buildDropdownField(
                      label: 'Role',
                      value: role,
                      items: ['Mother', 'Father', 'Guardian'],
                      onChanged: (value) {
                        setState(() {
                          role = value;
                        });
                      },
                      placeholder: 'Select your role',
                    ),
                    _buildTextField('Email', email, (value) {
                      email = value;
                    }, keyboardType: TextInputType.emailAddress),
                    _buildTextField('Baby Name', babyName, (value) {
                      babyName = value;
                    }),
                    _buildDropdownField(
                      label: 'Baby Gender',
                      value: babyGender,
                      items: ['Boy', 'Girl'],
                      onChanged: (value) {
                        setState(() {
                          babyGender = value;
                        });
                      },
                      placeholder: 'Select baby\'s gender',
                    ),
                    _buildDatePicker(context),
                    _buildTextField('Phone Number', phoneNumber, (value) {
                      phoneNumber = value;
                    }, keyboardType: TextInputType.phone),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _updateUserProfile,
                      style: ElevatedButton.styleFrom(
                        foregroundColor: const Color(0xFFEBE0D0),
                        backgroundColor: const Color(0xFFA91B60),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 50, vertical: 15),
                        textStyle: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTextField(
      String label, String? initialValue, Function(String) onSaved,
      {TextInputType keyboardType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        initialValue: initialValue,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        keyboardType: keyboardType,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter $label';
          }
          return null;
        },
        onSaved: (value) => onSaved(value!),
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
    String? placeholder,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: DropdownButtonFormField<String>(
        value: value != null && value.isNotEmpty ? value : null,
        decoration: InputDecoration(
          labelText: label,
          hintText: placeholder,
          border: const OutlineInputBorder(),
        ),
        items: items.map((item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(item),
          );
        }).toList(),
        onChanged: onChanged,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please select $label';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildDatePicker(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: InkWell(
        onTap: () async {
          final DateTime? picked = await showDatePicker(
            context: context,
            initialDate: babyBirthday ?? DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime.now(),
          );
          if (picked != null && picked != babyBirthday) {
            setState(() {
              babyBirthday = picked;
            });
          }
        },
        child: InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Baby\'s Birthday',
            border: OutlineInputBorder(),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                babyBirthday != null
                    ? '${DateFormat('dd/MM/yyyy').format(babyBirthday!)} (${calculateAge(babyBirthday!)})'
                    : 'Select Date',
              ),
              const Icon(Icons.calendar_today),
            ],
          ),
        ),
      ),
    );
  }
}
