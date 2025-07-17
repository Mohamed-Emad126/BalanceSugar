import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_config.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../common/bottom_nav.dart';
import '../Welcom/newhome.dart';

class UserData {
  final String firstName;
  final String lastName;
  final String email;
  final String gender;
  final String age;
  final String diabetesType;
  final String therapy;
  final String weight;
  final String height;

  UserData({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.gender,
    required this.age,
    required this.diabetesType,
    required this.therapy,
    required this.weight,
    required this.height,
  });
}

class ProfilePage extends StatefulWidget {
  final UserData user;
  const ProfilePage({Key? key, required this.user}) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final Color darkBlue = const Color(0xFF034985);
  bool isEditing = false;
  bool isLoading = false;
  String? _profileImagePath;
  File? _imageFile; // To hold the picked image file

  // Controllers for text fields
  late TextEditingController firstNameController;
  late TextEditingController lastNameController;
  late TextEditingController emailController;
  late TextEditingController ageController;
  late TextEditingController weightController;
  late TextEditingController heightController;

  String? selectedGender;
  String? selectedDiabetesType;
  String? selectedTherapy;

  // Use ProfileService methods for dropdown options
  List<String> get genderOptions => ProfileService.getGenderOptions();
  List<String> get diabetesTypeOptions =>
      ProfileService.getDiabetesTypeOptions();
  List<String> get therapyOptions => ProfileService.getTherapyOptions();

  @override
  void initState() {
    super.initState();
    _loadProfileData();
    // Initialize controllers
    firstNameController = TextEditingController(text: widget.user.firstName);
    lastNameController = TextEditingController(text: widget.user.lastName);
    emailController = TextEditingController(text: widget.user.email);
    ageController = TextEditingController(text: widget.user.age);
    weightController = TextEditingController(text: widget.user.weight);
    heightController = TextEditingController(text: widget.user.height);

    // Initialize dropdown values with validation
    selectedGender = genderOptions.contains(widget.user.gender)
        ? widget.user.gender
        : genderOptions.first;
    selectedDiabetesType =
        diabetesTypeOptions.contains(widget.user.diabetesType)
            ? widget.user.diabetesType
            : diabetesTypeOptions.first;
    selectedTherapy = therapyOptions.contains(widget.user.therapy)
        ? widget.user.therapy
        : therapyOptions.first;
  }

  @override
  void dispose() {
    // Dispose controllers
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    ageController.dispose();
    weightController.dispose();
    heightController.dispose();
    super.dispose();
  }

  Future<void> updateProfile() async {
    setState(() => isLoading = true);

    try {
      // Use ProfileService to update profile
      final updatedProfile = await ProfileService.updateProfileFields(
        gender: selectedGender,
        diabetesType: selectedDiabetesType,
        therapy: selectedTherapy,
        age: int.tryParse(ageController.text),
        weight: double.tryParse(weightController.text),
        height: double.tryParse(heightController.text),
      );

      if (updatedProfile != null) {
        // Update local storage for all fields, even those not sent to the API
        final prefs = await SharedPreferences.getInstance();
        await Future.wait([
          // These are updated locally but not sent to the API
          prefs.setString('first_name', firstNameController.text),
          prefs.setString('last_name', lastNameController.text),
          prefs.setString('email', emailController.text),

          // These are updated locally and were sent to the API
          prefs.setString('gender', selectedGender ?? ''),
          prefs.setString('age', ageController.text),
          prefs.setString('diabetes_type', selectedDiabetesType ?? ''),
          prefs.setString('therapy', selectedTherapy ?? ''),
          prefs.setString('weight', weightController.text),
          prefs.setString('height', heightController.text),
        ]);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
        setState(() => isEditing = false);
      } else {
        throw Exception('Failed to update profile');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating profile: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Widget _buildProfileImage() {
    return GestureDetector(
      onTap: isEditing ? () => _showImagePicker(context) : null,
      child: CircleAvatar(
        radius: 60,
        backgroundColor: Colors.grey[300],
        child: Stack(
          alignment: Alignment.center,
          children: [
            ClipOval(
              child: SizedBox(
                width: 120,
                height: 120,
                child: _imageFile != null
                    ? Image.file(
                        _imageFile!,
                        fit: BoxFit.cover,
                      )
                    : (_profileImagePath != null &&
                            _profileImagePath!.isNotEmpty
                        ? Image.network(
                            // Ensure the URL is HTTPS
                            _profileImagePath!
                                .replaceFirst('http://', 'https://'),
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(
                                  child: CircularProgressIndicator());
                            },
                            errorBuilder: (context, error, stackTrace) {
                              // This will show the person icon if the network image fails
                              return Icon(Icons.person,
                                  size: 60, color: darkBlue);
                            },
                          )
                        // This shows the person icon if there's no image path initially
                        : Icon(Icons.person, size: 60, color: darkBlue)),
              ),
            ),
            if (isEditing)
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.camera_alt,
                    color: Colors.white70, size: 40),
              ),
          ],
        ),
      ),
    );
  }

  void _showImagePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (builder) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () {
                  _pickImage(ImageSource.gallery);
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Camera'),
                onTap: () {
                  _pickImage(ImageSource.camera);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 50);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
      _uploadImage(_imageFile!);
    }
  }

  Future<void> _uploadImage(File imageFile) async {
    // No longer setting isLoading here to prevent full-screen loader
    try {
      final token = await AuthService.getAccessToken();
      if (token == null) throw Exception('No authentication token found');

      var request = http.MultipartRequest(
        'PATCH',
        Uri.parse(ApiConfig.updateProfile),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(
        await http.MultipartFile.fromPath('image', imageFile.path),
      );

      var response = await request.send();

      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        final data = jsonDecode(responseBody);
        final newImageUrl = data['image_url'];

        if (newImageUrl != null) {
          print("✅ New image URL from server: $newImageUrl");
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('profile_image', newImageUrl);
          setState(() {
            // By NOT clearing _imageFile, the UI continues to show the local
            // file instantly without a network flicker. The path is updated
            // for the next time the page loads.
            _profileImagePath = newImageUrl;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile image updated!')),
          );
        } else {
          print("🚨 Server response did not contain 'image_url'");
        }
      } else {
        final error = await response.stream.bytesToString();
        throw Exception('Failed to upload image: $error');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading image: $e')),
      );
    }
  }

  Future<void> _loadProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedImage = prefs.getString('profile_image');

    // 1. Load from cache for an instant UI update
    if (mounted) {
      print("✅ ProfilePage: Loaded image from cache: $cachedImage");
      setState(() {
        _profileImagePath = cachedImage;
      });
    }

    // 2. Fetch from the server to get the latest data
    try {
      final profile = await ProfileService.getProfile();
      // 3. ONLY update the cache if the server provides a valid, non-empty URL
      if (profile?.imageUrl != null && profile!.imageUrl!.isNotEmpty) {
        print("✅ ProfilePage: Fetched image from server: ${profile.imageUrl}");
        await prefs.setString('profile_image', profile.imageUrl!);
        if (mounted && _profileImagePath != profile.imageUrl) {
          setState(() {
            _profileImagePath = profile.imageUrl;
          });
        }
      } else {
        print(
            "🚨 ProfilePage: Server returned null/empty image URL. Sticking with cached version.");
      }
    } catch (e) {
      print("🚨 ProfilePage: Error fetching profile: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator(color: darkBlue)),
      );
    }
    return BottomNavScaffold(
      currentIndex: 0,
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: AppBar(
          backgroundColor: const Color(0xFFE6EEF5),
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_ios, color: darkBlue, size: 28),
                onPressed: () => Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const DashboardPage()),
                  (route) => false,
                ),
              ),
              Text(
                'Profile',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: darkBlue,
                ),
              ),
              IconButton(
                icon: Icon(
                  isEditing ? Icons.check : Icons.edit,
                  color: darkBlue,
                  size: 28,
                ),
                onPressed: () {
                  if (isEditing) {
                    updateProfile();
                  } else {
                    setState(() => isEditing = true);
                  }
                },
              ),
            ],
          ),
          toolbarHeight: 70,
        ),
      ),
      body: Stack(
        children: [
          // Curved background with profile picture
          SizedBox(
            height: 240,
            width: double.infinity,
            child: Stack(
              children: [
                ClipPath(
                  clipper: CurvedClipper(),
                  child: Container(
                    height: 140,
                    color: const Color(0xFFE6EEF5),
                  ),
                ),
                Positioned(
                  top: 30,
                  left: MediaQuery.of(context).size.width / 2 - 60,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 4),
                      shape: BoxShape.circle,
                    ),
                    child: _buildProfileImage(),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 160), // Less space after pic
                // Form fields
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Column(
                      children: [
                        _buildTextField(
                          controller: firstNameController,
                          label: 'First Name',
                          readOnly: !isEditing,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: lastNameController,
                          label: 'Last Name',
                          readOnly: !isEditing,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: emailController,
                          label: 'Email',
                          readOnly: !isEditing,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildDropdownField(
                                label: 'Gender',
                                value: selectedGender,
                                options: genderOptions,
                                onChanged: (value) =>
                                    setState(() => selectedGender = value),
                                isEditing: isEditing,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildTextField(
                                controller: ageController,
                                label: 'Age',
                                readOnly: !isEditing,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildDropdownField(
                                label: 'Diabetes Type',
                                value: selectedDiabetesType,
                                options: diabetesTypeOptions,
                                onChanged: (value) => setState(
                                    () => selectedDiabetesType = value),
                                isEditing: isEditing,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildDropdownField(
                                label: 'Therapy',
                                value: selectedTherapy,
                                options: therapyOptions,
                                onChanged: (value) =>
                                    setState(() => selectedTherapy = value),
                                isEditing: isEditing,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: weightController,
                                label: 'Weight (kg)',
                                readOnly: !isEditing,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildTextField(
                                controller: heightController,
                                label: 'Height (cm)',
                                readOnly: !isEditing,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool readOnly = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        filled: true,
        fillColor: const Color(0xFFE6EEF5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      ),
    );
  }

  Widget _buildDropdownField<T>({
    required String label,
    required String? value,
    required List<String> options,
    required Function(String?) onChanged,
    required bool isEditing,
  }) {
    // Ensure the current value is in the options list, otherwise it must be null
    String? currentValue = options.contains(value) ? value : null;

    return IgnorePointer(
      ignoring: !isEditing,
      child: DropdownButtonFormField<String>(
        value: currentValue,
        hint: Text(label, style: TextStyle(color: Colors.grey[600])),
        isExpanded: true,
        onChanged: onChanged,
        style: const TextStyle(color: Colors.black87),
        dropdownColor: Colors.white,
        items: options.map<DropdownMenuItem<String>>((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value),
          );
        }).toList(),
        decoration: InputDecoration(
          labelText: label,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          filled: true,
          fillColor: const Color(0xFFE6EEF5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
        ),
      ),
    );
  }
}

class CurvedClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height - 60);
    path.quadraticBezierTo(
      size.width / 2,
      size.height,
      size.width,
      size.height - 60,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
