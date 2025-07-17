import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../Welcom/newhome.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import '../Profile/profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

class User extends StatefulWidget {
  final VoidCallback
      onContinue; // Callback for when user clicks 'Create account'

  const User({
    super.key,
    required this.onContinue,
  }); // Pass onContinue to the constructor

  @override
  _UserState createState() => _UserState();
}

class _UserState extends State<User> {
  final _formKey = GlobalKey<FormState>(); // Form key for validation
  String? _selectedGender;
  String? _selectedTherapy;
  String? _selectedDiabetesType;
  TextEditingController _weightController = TextEditingController();
  TextEditingController _heightController = TextEditingController();
  TextEditingController _ageController = TextEditingController();
  bool _isLoading = false;

  Future<void> _submitData() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Get user data from SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final firstName = prefs.getString('first_name') ?? '';
        final lastName = prefs.getString('last_name') ?? '';
        final email = prefs.getString('email') ?? '';

        // Use ProfileService to update profile
        final updatedProfile = await ProfileService.updateProfileFields(
          gender: _selectedGender,
          therapy: _selectedTherapy,
          diabetesType: _selectedDiabetesType,
          weight: double.tryParse(_weightController.text),
          height: double.tryParse(_heightController.text),
          age: int.tryParse(_ageController.text),
        );

        if (updatedProfile != null) {
          // Save all user data to SharedPreferences
          await prefs.setString('first_name', firstName);
          await prefs.setString('last_name', lastName);
          await prefs.setString('email', email);
          await prefs.setString('gender', _selectedGender ?? '');
          await prefs.setString('therapy', _selectedTherapy ?? '');
          await prefs.setString('diabetes_type', _selectedDiabetesType ?? '');
          await prefs.setString('weight', _weightController.text);
          await prefs.setString('height', _heightController.text);
          await prefs.setString('age', _ageController.text);

          // Navigate to DashboardPage (homepage)
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => const DashboardPage(),
            ),
            (route) => false,
          );
        } else {
          _showErrorDialog('Failed to update data, please try again.');
        }
      } catch (error) {
        _showErrorDialog('An error occurred during the process.');
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF034985),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(
          "User",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF034985)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(height: 110),
              Container(
                height: 410,
                padding: const EdgeInsets.all(16),
                margin:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 40),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              labelText: 'Gender',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              labelStyle: const TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    const BorderSide(color: Color(0xFF034985)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    const BorderSide(color: Colors.grey),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    const BorderSide(color: Colors.grey),
                              ),
                              prefixIcon: const Icon(Icons.person,
                                  color: Color(0xFF034985), size: 20),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            value: _selectedGender,
                            items: ProfileService.getGenderOptions()
                                .map(
                                  (gender) => DropdownMenuItem(
                                    value: gender,
                                    child: Row(
                                      children: [
                                        Text(
                                          gender,
                                          style: const TextStyle(
                                            color: Color(0xFF034985),
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedGender = value;
                              });
                            },
                            validator: (value) {
                              if (value == null) {
                                return 'Required';
                              }
                              return null;
                            },
                            dropdownColor: Colors.white,
                            icon: const Icon(Icons.arrow_drop_down,
                                color: Color(0xFF034985), size: 20),
                            style: const TextStyle(
                                color: Color(0xFF034985), fontSize: 14),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _weightController,
                            decoration: InputDecoration(
                              labelText: 'Weight',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              labelStyle: const TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    const BorderSide(color: Color(0xFF034985)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    const BorderSide(color: Colors.grey),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    const BorderSide(color: Colors.grey),
                              ),
                              prefixIcon: const Icon(Icons.monitor_weight,
                                  color: Color(0xFF034985), size: 20),
                              suffixText: 'kg',
                              suffixStyle: const TextStyle(
                                color: Color(0xFF034985),
                                fontSize: 12,
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            style: const TextStyle(fontSize: 14),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Required';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              labelText: 'Therapy',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              labelStyle: const TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    const BorderSide(color: Color(0xFF034985)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    const BorderSide(color: Colors.grey),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    const BorderSide(color: Colors.grey),
                              ),
                              prefixIcon: const Icon(Icons.local_hospital,
                                  color: Color(0xFF034985), size: 20),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            value: _selectedTherapy,
                            items: ProfileService.getTherapyOptions()
                                .map(
                                  (therapy) => DropdownMenuItem(
                                    value: therapy,
                                    child: Row(
                                      children: [
                                        Text(
                                          therapy,
                                          style: const TextStyle(
                                            color: Color(0xFF034985),
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedTherapy = value;
                              });
                            },
                            validator: (value) {
                              if (value == null) {
                                return 'Required';
                              }
                              return null;
                            },
                            dropdownColor: Colors.white,
                            icon: const Icon(Icons.arrow_drop_down,
                                color: Color(0xFF034985), size: 20),
                            style: const TextStyle(
                                color: Color(0xFF034985), fontSize: 14),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _heightController,
                            decoration: InputDecoration(
                              labelText: 'Height',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              labelStyle: const TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    const BorderSide(color: Color(0xFF034985)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    const BorderSide(color: Colors.grey),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    const BorderSide(color: Colors.grey),
                              ),
                              prefixIcon: const Icon(Icons.height,
                                  color: Color(0xFF034985), size: 20),
                              suffixText: 'cm',
                              suffixStyle: const TextStyle(
                                color: Color(0xFF034985),
                                fontSize: 12,
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            style: const TextStyle(fontSize: 14),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Required';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Diabetes Type',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        labelStyle: const TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFF034985)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.grey),
                        ),
                        prefixIcon: const Icon(Icons.bloodtype,
                            color: Color(0xFF034985), size: 20),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      value: _selectedDiabetesType,
                      items: ProfileService.getDiabetesTypeOptions()
                          .map(
                            (type) => DropdownMenuItem(
                              value: type,
                              child: Row(
                                children: [
                                  Text(
                                    type,
                                    style: const TextStyle(
                                      color: Color(0xFF034985),
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedDiabetesType = value;
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Required';
                        }
                        return null;
                      },
                      dropdownColor: Colors.white,
                      icon: const Icon(Icons.arrow_drop_down,
                          color: Color(0xFF034985), size: 20),
                      style: const TextStyle(
                          color: Color(0xFF034985), fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _ageController,
                      decoration: InputDecoration(
                        labelText: 'Age',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        labelStyle: const TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFF034985)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.grey),
                        ),
                        prefixIcon: const Icon(Icons.cake,
                            color: Color(0xFF034985), size: 20),
                        suffixText: 'years',
                        suffixStyle: const TextStyle(
                          color: Color(0xFF034985),
                          fontSize: 12,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      style: const TextStyle(fontSize: 14),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitData,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF034985),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Save',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
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
