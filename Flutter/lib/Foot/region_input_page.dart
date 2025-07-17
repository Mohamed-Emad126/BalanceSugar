import 'package:flutter/material.dart';
import 'dart:io';
import '../services/footcare_service.dart';
import 'analysis_page.dart';

class RegionInputPage extends StatefulWidget {
  final File image;
  final String? regionName;
  const RegionInputPage({Key? key, required this.image, this.regionName})
      : super(key: key);

  @override
  State<RegionInputPage> createState() => _RegionInputPageState();
}

class _RegionInputPageState extends State<RegionInputPage> {
  final TextEditingController _regionController = TextEditingController();
  bool _regionValid = true;
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.regionName?.isNotEmpty ?? false) {
      _regionController.text = widget.regionName!;
    }
  }

  @override
  void dispose() {
    _regionController.dispose();
    super.dispose();
  }

  Future<void> _onContinue() async {
    if (!_validateInput()) return;

    setState(() => _isSubmitting = true);
    try {
      final analysis = await FootcareService.createUlcer(
        widget.image,
        {'region': _regionController.text.trim()},
      );
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (context) => AnalysisPage(analysis: analysis)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(_error ?? 'Unknown error'),
            backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  bool _validateInput() {
    setState(() {
      _regionValid = _regionController.text.trim().isNotEmpty;
      _error = null;
    });
    return _regionValid;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF034985)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Region Details',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter Region Name',
                style: TextStyle(
                  color: Color(0xFF034985),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextField(
                  controller: _regionController,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'e.g. Right foot, Left heel',
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 16),
                    errorText: !_regionValid ? 'Region name is required' : null,
                  ),
                  style:
                      const TextStyle(fontSize: 16, color: Color(0xFF2C3E50)),
                  onChanged: (_) => setState(() => _regionValid = true),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Preview Image',
                style: TextStyle(
                  color: Color(0xFF034985),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 30),
              Center(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(
                      widget.image,
                      fit: BoxFit.cover,
                      width: 250,
                      height: 250,
                    ),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                _buildErrorContainer(),
              ],
              const SizedBox(height: 40),
              Center(
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _onContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF034985),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 2,
                      shadowColor: const Color(0xFF034985).withOpacity(0.3),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 3),
                          )
                        : const Text(
                            'Analyze Image',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorContainer() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _error!,
              style: TextStyle(color: Colors.red.shade700, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
