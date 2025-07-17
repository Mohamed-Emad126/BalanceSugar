import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../services/footcare_service.dart';
import '../Meals/MainMeal.dart';
import '../Measurements/glucose_input_page.dart';
import '../Welcom/newhome.dart';
import '../Medications/Firstmed.dart';
import '../chat/chatbot0.dart';
import 'dart:math' as math;
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/api_config.dart';
import '../services/auth_service.dart';
import 'analysis_page.dart';
import 'foot_history_page.dart';
import 'region_history_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'region_input_page.dart';
import '../common/bottom_nav.dart';

// Add a global key for navigation to always show FootHistoryPage after analysis
final GlobalKey<NavigatorState> footNavKey = GlobalKey<NavigatorState>();

class UploadPhotoPage extends StatefulWidget {
  final String? regionName;
  const UploadPhotoPage({Key? key, this.regionName}) : super(key: key);

  @override
  _UploadPhotoPageState createState() => _UploadPhotoPageState();
}

class _UploadPhotoPageState extends State<UploadPhotoPage>
    with SingleTickerProviderStateMixin {
  File? _image;
  final ImagePicker _picker = ImagePicker();
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isLoading = false;
  String? _errorMessage;
  int selectedIndex = 3; // Foot page index
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  Future<bool> hasAnyFootRegion() async {
    try {
      final headers = await AuthService.getHeaders();
      final url = Uri.parse(ApiConfig.latestByRegion);
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.isNotEmpty;
      }
    } catch (_) {}
    return false;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1200,
        maxHeight: 1200,
      );

      if (pickedFile != null) {
        final File imageFile = File(pickedFile.path);

        // Validate image size
        final int fileSize = await imageFile.length();
        if (fileSize > 10 * 1024 * 1024) {
          // 10MB limit
          setState(() {
            _errorMessage =
                'Image size too large. Please choose a smaller image.';
            _isLoading = false;
          });
          return;
        }

        setState(() {
          _image = imageFile;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'No image selected';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error picking image: $e';
      });
      _showErrorDialog('Error picking image', e.toString());
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Success'),
        content: const Text('Image analysis completed successfully!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showWarningDialog(VoidCallback onContinue) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: const Color(0xFFF6F8FC),
        elevation: 12,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.camera_alt_rounded,
                  size: 48, color: Color(0xFF034985)),
              const SizedBox(height: 18),
              Text(
                'Take a clear photo of your foot',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF034985),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Make sure your foot is well-lit and clearly visible in the photo.',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    onContinue();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF034985),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showImagePreview(File image) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) =>
            RegionInputPage(image: image, regionName: widget.regionName),
      ),
    );
  }

  void _onUploadPhoto() {
    _showWarningDialog(() async {
      final XFile? pickedFile = await _picker.pickImage(
          source: ImageSource.gallery, imageQuality: 85);
      if (pickedFile != null) {
        final file = File(pickedFile.path);
        setState(() => _selectedImage = file);
        _showImagePreview(file);
      }
    });
  }

  void _onTakePhoto() {
    _showWarningDialog(() async {
      final XFile? pickedFile =
          await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
      if (pickedFile != null) {
        final file = File(pickedFile.path);
        setState(() => _selectedImage = file);
        _showImagePreview(file);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final darkBlue = const Color(0xFF034985);
    return BottomNavScaffold(
      currentIndex: 3,
      backgroundColor: const Color(0xFFE6EEF5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF034985)),
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const DashboardPage()),
              (route) => false,
            );
          },
        ),
        title: const Text(
          'Foot Ulcer',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 60),
              // Camera icon with two concentric circles
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        color: darkBlue.withOpacity(0.18),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Container(
                      width: 120,
                      height: 120,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const Icon(Icons.camera_alt,
                        size: 54, color: Colors.black87),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // How it works box
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 22, horizontal: 18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12.withOpacity(0.08),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'How it works !',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF034985),
                          fontSize: 17,
                        ),
                      ),
                      SizedBox(height: 14),
                      _NumberedStep(
                          number: 1,
                          text: 'Uploads or takes a photo of their foot.'),
                      _NumberedStep(number: 2, text: 'Clicks "Analyze Photo."'),
                      _NumberedStep(number: 3, text: 'App analysis image.'),
                      _NumberedStep(
                          number: 4, text: 'Results are shown on a new page.'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _onUploadPhoto,
                        icon: const Icon(Icons.upload, color: Colors.white),
                        label: const Text('Upload photo',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: darkBlue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _onTakePhoto,
                        icon: const Icon(Icons.camera_alt_outlined,
                            color: Colors.white),
                        label: const Text('Take photo',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: darkBlue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _NumberedStep extends StatelessWidget {
  final int number;
  final String text;
  const _NumberedStep({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: const Color(0xFF034985).withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$number',
                style: const TextStyle(
                  color: Color(0xFF034985),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF222B45),
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
