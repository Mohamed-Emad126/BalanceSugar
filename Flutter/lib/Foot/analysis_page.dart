import 'package:flutter/material.dart';
import 'dart:io';
import 'foot_history_page.dart';

class AnalysisPage extends StatelessWidget {
  final Map<String, dynamic> analysis;
  const AnalysisPage({Key? key, required this.analysis}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final region = analysis['region']?.toString() ?? 'Unknown';
    final originalImage =
        analysis['image']?.toString() ?? analysis['image_url']?.toString();
    final segmentedImage = analysis['segmented_image']?.toString() ??
        analysis['segmented_image_url']?.toString();
    final ulcerArea = analysis['ulcer_area']?.toString() ?? '-';
    final lastArea = analysis['last_area']?.toString() ?? '-';
    final areaDiff = analysis['area_difference']?.toString() ?? '-';
    final classification =
        analysis['classification_result']?.toString() ?? 'Unknown';
    final confidence = analysis['confidence']?.toString() ?? '-';
    final improvement = analysis['improvement_message']?.toString();
    final date = analysis['date'] != null
        ? DateTime.tryParse(analysis['date'].toString()) ?? DateTime.now()
        : DateTime.now();

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF034985)),
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const FootHistoryPage()),
              (route) => false,
            );
          },
        ),
        title: const Text(
          "Analysis Results",
          style: TextStyle(
            color: Color(0xFF034985),
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
              _buildRegionHeader(region),
              _buildImageComparison(originalImage, segmentedImage),
              const SizedBox(height: 8),
              _buildDateSection(date),
              const SizedBox(height: 8),
              _buildAnalysisResults(
                  ulcerArea, lastArea, areaDiff, improvement, classification),
              const SizedBox(height: 8),
              _buildContinueButton(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRegionHeader(String region) {
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF034985).withOpacity(0.1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Center(
        child: Text(
          region,
          style: const TextStyle(
            color: Color(0xFF034985),
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: 1.1,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildImageComparison(String? originalImage, String? segmentedImage) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(child: _buildImageContainer('Original', originalImage)),
          const SizedBox(width: 12),
          Expanded(child: _buildImageContainer('Processed', segmentedImage)),
        ],
      ),
    );
  }

  Widget _buildImageContainer(String title, String? imageUrl) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: Color(0xFF034985),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: (imageUrl != null && imageUrl.isNotEmpty)
                ? (imageUrl.startsWith('http')
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.broken_image,
                                size: 48, color: Color(0xFF034985)),
                      )
                    : Image.file(
                        File(imageUrl),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.broken_image,
                                size: 48, color: Color(0xFF034985)),
                      ))
                : const Icon(Icons.image, size: 48, color: Color(0xFF034985)),
          ),
        ),
      ],
    );
  }

  Widget _buildDateSection(DateTime date) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF034985).withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.calendar_today, color: Color(0xFF034985)),
          const SizedBox(width: 12),
          Text(
            'Tuesday, ${date.day}/${date.month}/${date.year}',
            style: const TextStyle(
              color: Color(0xFF034985),
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisResults(String ulcerArea, String lastArea,
      String areaDiff, String? improvement, String classification) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ulcer Analysis',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF034985),
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 16),
          _buildResultRow('Previous Area', '$lastArea mm²'),
          const SizedBox(height: 12),
          _buildResultRow('Current Area', '$ulcerArea mm²'),
          const SizedBox(height: 12),
          _buildResultRow('Difference', '$areaDiff mm²'),
          const SizedBox(height: 12),
          _buildResultRow('Condition', classification),
          if (improvement != null && improvement.isNotEmpty) ...[
            const SizedBox(height: 16),
            Builder(builder: (context) {
              final message = improvement.toLowerCase();
              IconData statusIcon;
              Color statusColor;
              Color bgColor;

              if (message.contains('not improved')) {
                statusIcon = Icons.trending_flat;
                statusColor = Colors.orange.shade800;
                bgColor = Colors.orange.shade50;
              } else if (message.contains('worse') ||
                  message.contains('decline')) {
                statusIcon = Icons.trending_down;
                statusColor = Colors.red.shade700;
                bgColor = Colors.red.shade50;
              } else if (message.contains('improve')) {
                statusIcon = Icons.trending_up;
                statusColor = Colors.green.shade700;
                bgColor = Colors.green.shade50;
              } else {
                statusIcon = Icons.info_outline;
                statusColor = Colors.grey.shade700;
                bgColor = Colors.grey.shade50;
              }

              final displayText = improvement.replaceAll('Condition', 'Ulcer');

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    Icon(statusIcon, color: statusColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        displayText,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildResultRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 16,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: Color(0xFF034985),
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContinueButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: () {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const FootHistoryPage()),
            (route) => false,
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF034985),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 2,
          shadowColor: const Color(0xFF034985).withOpacity(0.3),
        ),
        child: const Text(
          'Save',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
