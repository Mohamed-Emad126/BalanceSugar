import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/api_config.dart';
import '../services/auth_service.dart';
import 'region_history_page.dart';
import 'Foot.dart' as foot;
import '../Meals/MainMeal.dart';
import '../Measurements/glucose_input_page.dart';
import '../Welcom/newhome.dart';
import '../Medications/Firstmed.dart';
import '../chat/chatbot0.dart';
import '../common/bottom_nav.dart';

class FootHistoryPage extends StatefulWidget {
  const FootHistoryPage({Key? key}) : super(key: key);

  @override
  State<FootHistoryPage> createState() => _FootHistoryPageState();
}

class _FootHistoryPageState extends State<FootHistoryPage> {
  List<Map<String, dynamic>> regions = [];
  bool isLoading = true;
  String? error;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchRegions();
  }

  Future<void> _fetchRegions() async {
    setState(() {
      isLoading = true;
      error = null;
    });
    try {
      final headers = await AuthService.getHeaders();
      final url = Uri.parse(ApiConfig.latestByRegion);
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          regions = List<Map<String, dynamic>>.from(data);
          isLoading = false;
        });
      } else {
        setState(() {
          error = 'Failed to load regions: \\${response.statusCode}';
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

  Future<void> _deleteRegion(String region) async {
    try {
      final headers = await AuthService.getHeaders();
      final url = Uri.parse(
          '${ApiConfig.deleteUlcersByRegion}?region=${Uri.encodeComponent(region)}');
      final response = await http.delete(url, headers: headers);

      if (response.statusCode == 200 || response.statusCode == 204) {
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Failed to delete region: ${response.statusCode} - ${response.body}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _confirmAndDeleteRegion(String region) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        elevation: 8,
        backgroundColor: Colors.white,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title bar with icon
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 18, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.red[700],
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.delete_forever, color: Colors.white, size: 26),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Delete Region',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 19,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
              child: Text(
                'Are you sure you want to delete the region "$region" and all its measurements?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 18, left: 16, right: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey.shade400),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[700],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        'Delete',
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
          ],
        ),
      ),
    );
    if (confirmed == true) {
      setState(() => isLoading = true);
      await _deleteRegion(region);
      await _fetchRegions();
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Region and its measurements deleted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final darkBlue = const Color(0xFF034985);
    final filteredRegions = regions
        .where((region) =>
            region['region']
                ?.toLowerCase()
                .contains(_searchQuery.toLowerCase()) ??
            false)
        .toList();
    return BottomNavScaffold(
      currentIndex: 3,
      backgroundColor: const Color(0xFFE6EEF5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Color(0xFF034985)),
          onPressed: () => Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const DashboardPage()),
            (route) => false,
          ),
        ),
        title: const Text('Foot History',
            style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 24)),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Text(error!))
              : Column(
                  children: [
                    const SizedBox(height: 18),
                    _buildSearchBar(),
                    Expanded(
                      child: filteredRegions.isEmpty
                          ? _buildNoRegionsPlaceholder()
                          : ListView.builder(
                              padding: const EdgeInsets.all(20),
                              itemCount: filteredRegions.length,
                              itemBuilder: (context, index) {
                                final region = filteredRegions[index];
                                return GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => RegionHistoryPage(
                                            regionName: region['region'] ?? ''),
                                      ),
                                    );
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    margin: const EdgeInsets.only(bottom: 24),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      // border: Border.all(
                                      //     color: const Color(0xFF034985)
                                      //         .withOpacity(0.5),
                                      //     width: 2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.06),
                                          blurRadius: 12,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    padding: const EdgeInsets.all(20),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 14,
                                                      vertical: 6),
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                region['region'] ?? '',
                                                style: const TextStyle(
                                                  color: Colors.black,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 18,
                                                ),
                                              ),
                                            ),
                                            const Spacer(),
                                            TextButton(
                                              onPressed: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        RegionHistoryPage(
                                                            regionName: region[
                                                                    'region'] ??
                                                                ''),
                                                  ),
                                                );
                                              },
                                              style: TextButton.styleFrom(
                                                backgroundColor: darkBlue,
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                textStyle: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 16),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 18,
                                                        vertical: 8),
                                              ),
                                              child: const Text('View all'),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  const Row(
                                                    children: [
                                                      Text('Ulcer Analysis',
                                                          style: TextStyle(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color: Colors.red,
                                                              fontSize: 15)),
                                                      SizedBox(width: 4),
                                                      Tooltip(
                                                        message:
                                                            'Shows ulcer area changes for this region.',
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 6),
                                                  _buildAnalysisRow(
                                                      'Previous Area',
                                                      region['last_area']),
                                                  _buildAnalysisRow(
                                                      'Current Area',
                                                      region['ulcer_area']),
                                                  _buildAnalysisRow(
                                                      'Difference',
                                                      region[
                                                          'area_difference']),
                                                  _buildAnalysisRow(
                                                      'Condition',
                                                      region[
                                                          'classification_result']),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 18),
                                            Container(
                                              width: 80,
                                              height: 80,
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(18),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black12
                                                        .withOpacity(0.10),
                                                    blurRadius: 10,
                                                    offset: const Offset(0, 4),
                                                  ),
                                                ],
                                              ),
                                              child: region['image'] != null &&
                                                      region['image']
                                                          .toString()
                                                          .isNotEmpty &&
                                                      region['image']
                                                          .toString()
                                                          .startsWith('http')
                                                  ? ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              18),
                                                      child: Image.network(
                                                        region['image'],
                                                        fit: BoxFit.cover,
                                                        errorBuilder: (context,
                                                            error, stackTrace) {
                                                          return const Icon(
                                                              Icons
                                                                  .broken_image,
                                                              size: 40,
                                                              color: Color(
                                                                  0xFF034985));
                                                        },
                                                      ),
                                                    )
                                                  : const Icon(Icons.image,
                                                      size: 40,
                                                      color: Color(0xFF034985)),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          children: [
                                            ElevatedButton.icon(
                                              onPressed: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        foot.UploadPhotoPage(
                                                      key: UniqueKey(),
                                                      regionName:
                                                          region['region'] ??
                                                              '',
                                                    ),
                                                  ),
                                                );
                                              },
                                              label: Text('Add',
                                                  style: TextStyle(
                                                      color: darkBlue)),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  side: BorderSide(
                                                      color: darkBlue,
                                                      width: 1.5),
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 24,
                                                        vertical: 10),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            ElevatedButton(
                                              onPressed: () =>
                                                  _confirmAndDeleteRegion(
                                                      region['region'] ?? ''),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    const Color(0xFF034985),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 24,
                                                        vertical: 10),
                                              ),
                                              child: const Text('Delete',
                                                  style: TextStyle(
                                                      color: Colors.white)),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'addRegionFAB',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const foot.UploadPhotoPage(),
            ),
          );
        },
        backgroundColor: const Color(0xFF034985),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        decoration: const InputDecoration(
          border: InputBorder.none,
          icon: Icon(Icons.search, color: Color(0xFF034985)),
          hintText: 'Search region...',
        ),
        onChanged: (val) => setState(() => _searchQuery = val),
      ),
    );
  }

  Widget _buildNoRegionsPlaceholder() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 18),
            const Text(
              'No regions found',
              style: TextStyle(
                color: Color(0xFF034985),
                fontWeight: FontWeight.w600,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Start by adding a new region.',
              style: TextStyle(color: Colors.grey, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisRow(String label, dynamic value) {
    final isAreaValue = label.contains('Area') || label == 'Difference';
    final valueStr = value?.toString() ?? '-';
    Color valueColor = const Color(0xFF034985);

    if (label == 'Difference' && value != null) {
      final diff = double.tryParse(value.toString());
      if (diff != null) {
        if (diff < 0) {
          valueColor = Colors.green;
        } else if (diff > 0) {
          valueColor = Colors.red;
        }
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
          ),
          Expanded(
            child: Text(
              isAreaValue ? '$valueStr mm²' : valueStr,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: valueColor,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
