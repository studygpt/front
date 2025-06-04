import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({Key? key}) : super(key: key);

  @override
  _UserProfilePageState createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  Map<String, dynamic> user = {
    'id': 0,
    'email': '',
    'first_name': '',
    'last_name': '',
    'is_active': false,
    'role': '',
    'grade': 0,
    'profile_picture': 'assets/default_profile.png',
  };

  bool isEditing = false;
  bool isLoading = true;
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _emailController;
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _gradeController;
  String? token;
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadUserData();
  }

  void _initializeControllers() {
    _emailController = TextEditingController();
    _firstNameController = TextEditingController();
    _lastNameController = TextEditingController();
    _gradeController = TextEditingController();
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      token = prefs.getString('accessToken');

      if (token == null) {
        throw Exception('No authentication token found');
      }

      final response = await http.post(
        Uri.parse('http://56.228.80.139/api/account/profile/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Profile response: $data'); // Debug log
        setState(() {
          user = {
            'id': data['id'] ?? 0,
            'email': data['email'] ?? '',
            'first_name': data['first_name'] ?? '',
            'last_name': data['last_name'] ?? '',
            'is_active': data['is_active'] ?? false,
            'role': data['role'] ?? '',
            'grade': data['grade'] ?? 0,
            'profile_picture': data['profile_picture'] ?? 'assets/default_profile.png',
          };

          _emailController.text = user['email'];
          _firstNameController.text = user['first_name'];
          _lastNameController.text = user['last_name'];
          _gradeController.text = user['grade'].toString();

          isLoading = false;
        });
      } else {
        throw Exception('Failed to load profile: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading profile: ${e.toString()}')),
      );
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      isLoading = true;
    });

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://56.228.80.139/api/account/change-profile/'),
      );

      request.headers.addAll({
        'Authorization': 'Bearer $token',
      });

      request.fields['email'] = _emailController.text;
      request.fields['first_name'] = _firstNameController.text;
      request.fields['last_name'] = _lastNameController.text;
      request.fields['grade'] = _gradeController.text;

      if (_selectedImage != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'profile_picture',
          _selectedImage!.path,
        ));
      }

      final response = await request.send();
      final responseData = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = jsonDecode(responseData);
        print('Update profile response: $data'); // Debug log
        // Instead of updating user map directly, reload full profile data
        await _loadUserData();
        setState(() {
          isEditing = false;
          _selectedImage = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
      } else {
        final errorData = jsonDecode(responseData);
        String errorMessage = 'Failed to update profile: ${response.statusCode}';
        if (errorData.containsKey('detail')) {
          errorMessage = errorData['detail'];
        } else if (errorData.containsKey('email')) {
          errorMessage = 'Email error: ${errorData['email'][0]}';
        } else if (errorData.containsKey('profile_picture')) {
          errorMessage = 'Image error: ${errorData['profile_picture'][0]}';
        }
        throw Exception(errorMessage);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating profile: ${e.toString()}')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _gradeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Profile'),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() {
                isEditing = false;
                _selectedImage = null;
                _emailController.text = user['email'];
                _firstNameController.text = user['last_name'];
                _lastNameController.text = user['last_name'];
                _gradeController.text = user['grade'].toString();
              }),
            ),
          IconButton(
            icon: Icon(isEditing ? Icons.save : Icons.edit),
            onPressed: isEditing ? _updateProfile : () => setState(() => isEditing = true),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundImage: _selectedImage != null
                        ? FileImage(_selectedImage!)
                        : user['profile_picture'].startsWith('/media')
                        ? NetworkImage('http://56.228.80.139${user['profile_picture']}')
                        : AssetImage(user['profile_picture']) as ImageProvider,
                  ),
                  if (isEditing)
                    FloatingActionButton.small(
                      onPressed: _uploadProfilePicture,
                      child: const Icon(Icons.camera_alt),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              _buildInfoTile('User ID', user['id'].toString()),
              _buildInfoTile('Account Status', user['is_active'] ? 'Active' : 'Inactive'),
              _buildInfoTile('Role', user['role'].toString().toUpperCase()),
              _buildEditableField(
                label: 'Email',
                controller: _emailController,
                icon: Icons.email,
                isEditing: isEditing,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              _buildEditableField(
                label: 'First Name',
                controller: _firstNameController,
                icon: Icons.person,
                isEditing: isEditing,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your first name';
                  }
                  return null;
                },
              ),
              _buildEditableField(
                label: 'Last Name',
                controller: _lastNameController,
                icon: Icons.person,
                isEditing: isEditing,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your last name';
                  }
                  return null;
                },
              ),
              _buildEditableField(
                label: 'Grade',
                controller: _gradeController,
                icon: Icons.school,
                isEditing: isEditing,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your grade';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              if (isEditing && _selectedImage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Text(
                    'New profile picture selected',
                    style: TextStyle(color: Theme.of(context).primaryColor),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile(String title, String value) {
    return ListTile(
      title: Text(title),
      subtitle: Text(value.isNotEmpty ? value : 'N/A'),
    );
  }

  Widget _buildEditableField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required bool isEditing,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: isEditing
          ? TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
        ),
        keyboardType: keyboardType,
        validator: validator,
      )
          : ListTile(
        leading: Icon(icon),
        title: Text(label),
        subtitle: Text(controller.text.isNotEmpty ? controller.text : 'N/A'),
      ),
    );
  }

  Future<void> _uploadProfilePicture() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }
}