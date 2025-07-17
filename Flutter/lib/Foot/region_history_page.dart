import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/api_config.dart';
import '../services/auth_service.dart';
import '../common/bottom_nav.dart';

class RegionHistoryPage extends StatefulWidget {
  final String regionName;
  const RegionHistoryPage({Key? key, required this.regionName})
      : super(key: key);

  @override
  State<RegionHistoryPage> createState() => _RegionHistoryPageState();
}

class _RegionHistoryPageState extends State<RegionHistoryPage> {
  List<Map<String, dynamic>> measurements = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _fetchMeasurements();
  }

  Future<void> _fetchMeasurements() async {
    setState(() {
      isLoading = true;
      error = null;
    });
    try {
      final headers = await AuthService.getHeaders();
      final url = Uri.parse(ApiConfig.ulcersByRegion +
          '?region=${Uri.encodeComponent(widget.regionName)}');
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          measurements = List<Map<String, dynamic>>.from(data);
          isLoading = false;
        });
      } else {
        setState(() {
          error = 'Failed to load measurements: \\${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Error: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _deleteMeasurement(int ulcerId) async {
    try {
      final headers = await AuthService.getHeaders();
      final url = Uri.parse(ApiConfig.deleteUlcer + '$ulcerId/delete/');
      final response = await http.delete(url, headers: headers);
      if (response.statusCode == 204 || response.statusCode == 200) {
        _fetchMeasurements();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete measurement')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavScaffold(
      currentIndex: 3,
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF034985)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.regionName,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 24,
          ),
        ),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF034985)),
              ),
            )
          : error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          size: 48, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      Text(
                        error!,
                        style: TextStyle(color: Colors.red[700], fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: measurements.length,
                  itemBuilder: (context, index) {
                    final m = measurements[index];
                    String formattedDate =
                        m['uploaded_at'] ?? m['date'] ?? m['created_at'] ?? '-';
                    try {
                      final dateString =
                          m['uploaded_at'] ?? m['date'] ?? m['created_at'];
                      if (dateString != null) {
                        final date = DateTime.parse(dateString);
                        final weekdays = [
                          'Monday',
                          'Tuesday',
                          'Wednesday',
                          'Thursday',
                          'Friday',
                          'Saturday',
                          'Sunday'
                        ];
                        final weekday = weekdays[date.weekday - 1];
                        formattedDate =
                            '$weekday, ${date.day}/${date.month}/${date.year}';
                      }
                    } catch (_) {}

                    Color? differenceColor;
                    if (m['area_difference'] != null) {
                      final diff =
                          double.tryParse(m['area_difference'].toString());
                      if (diff != null) {
                        if (diff < 0) {
                          differenceColor = Colors.green;
                        } else if (diff > 0) {
                          differenceColor = Colors.red;
                        }
                      }
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 20),
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
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(
                              color: Color(0xFF034985),
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(16),
                                topRight: Radius.circular(16),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Ulcer Analysis',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 18,
                                  ),
                                ),
                                Text(
                                  (formattedDate == '-' ||
                                          formattedDate.isEmpty)
                                      ? 'No Date'
                                      : formattedDate,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildInfoRow('Previous Area',
                                          '${m['last_area'] ?? '-'} mm²'),
                                      const SizedBox(height: 12),
                                      _buildInfoRow(
                                        'Current Area',
                                        '${m['ulcer_area'] ?? '-'} mm²',
                                      ),
                                      const SizedBox(height: 12),
                                      _buildInfoRow(
                                        'Difference',
                                        '${m['area_difference'] ?? '-'} mm²',
                                        color: differenceColor,
                                      ),
                                      const SizedBox(height: 12),
                                      _buildInfoRow(
                                        'Condition',
                                        '${m['classification_result'] ?? '-'}',
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Column(
                                  children: [
                                    if (m['original_image'] != null &&
                                        (m['original_image'] as String)
                                            .isNotEmpty)
                                      _buildImageContainer(
                                          m['original_image'], 'Original'),
                                    if (m['segmented_image'] != null &&
                                        (m['segmented_image'] as String)
                                            .isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      _buildImageContainer(
                                          m['segmented_image'], 'Segmented'),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Center(
                            child: SizedBox(
                              width: 100,
                              child: ElevatedButton.icon(
                                onPressed: () => _deleteMeasurement(m['id']),
                                label: const Text('Delete'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFF034985),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color ?? const Color(0xFF1F2937),
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildImageContainer(String imageUrl, String label) {
    return Column(
      children: [
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Color(0xFF034985)),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
