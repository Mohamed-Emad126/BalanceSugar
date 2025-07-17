import 'glucose_measurement.dart';
import 'package:flutter/material.dart';
import '../services/glucose_service.dart';
import 'package:intl/intl.dart';
import 'glucose_chart.dart';
import '../services/timezone_service.dart';
import '../common/bottom_nav.dart';

class GlucoseHistoryPage extends StatefulWidget {
  const GlucoseHistoryPage({Key? key}) : super(key: key);

  @override
  State<GlucoseHistoryPage> createState() => _GlucoseHistoryPageState();
}

class _GlucoseHistoryPageState extends State<GlucoseHistoryPage> {
  final GlucoseService _glucoseService = GlucoseService();
  List<GlucoseMeasurement> _measurements = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';

  // Statistics for the filtered period
  double _averageGlucose = 0;
  double _highestGlucose = 0;
  double _lowestGlucose = 0;
  int _totalReadings = 0;
  Map<GlucoseSeverity, int> _severityDistribution = {};

  @override
  void initState() {
    super.initState();
    _loadAllMeasurements();
  }

  Future<void> _loadAllMeasurements() async {
    try {
      setState(() {
        _isLoading = true;
      });
      final measurements = await _glucoseService.getGlucoseHistory();
      setState(() {
        _measurements = measurements;
        _isLoading = false;
        _updateStatistics(_getFilteredMeasurements());
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading measurements: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getFilterTitle() {
    switch (_selectedFilter) {
      case 'Today':
        return 'Today\'s Readings';
      case 'Week':
        return 'Last 7 Days';
      case 'Month':
        return 'Last 30 Days';
      default:
        return 'All Readings';
    }
  }

  List<GlucoseMeasurement> _getFilteredMeasurements() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    List<GlucoseMeasurement> filtered;

    switch (_selectedFilter) {
      case 'Today':
        filtered = _measurements.where((m) {
          final measurementDate = m.createdAt;
          return measurementDate.isAfter(startOfDay);
        }).toList();
        break;

      case 'Week':
        final weekAgo = now.subtract(const Duration(days: 7));
        filtered = _measurements
            .where((m) =>
                m.createdAt.isAfter(weekAgo) &&
                m.createdAt.isBefore(now.add(const Duration(days: 1))))
            .toList();
        break;

      case 'Month':
        final monthAgo = now.subtract(const Duration(days: 30));
        filtered = _measurements
            .where((m) =>
                m.createdAt.isAfter(monthAgo) &&
                m.createdAt.isBefore(now.add(const Duration(days: 1))))
            .toList();
        break;

      default:
        filtered = List.from(_measurements);
    }

    // Sort measurements by date, most recent first
    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return filtered;
  }

  void _updateStatistics(List<GlucoseMeasurement> measurements) {
    if (measurements.isEmpty) {
      _averageGlucose = 0;
      _highestGlucose = 0;
      _lowestGlucose = 0;
      _totalReadings = 0;
      _severityDistribution = {};
      return;
    }

    double sum = 0;
    _highestGlucose = measurements.first.bloodGlucose;
    _lowestGlucose = measurements.first.bloodGlucose;
    _severityDistribution = {};

    for (var measurement in measurements) {
      sum += measurement.bloodGlucose;

      if (measurement.bloodGlucose > _highestGlucose) {
        _highestGlucose = measurement.bloodGlucose;
      }
      if (measurement.bloodGlucose < _lowestGlucose) {
        _lowestGlucose = measurement.bloodGlucose;
      }

      _severityDistribution[measurement.severity] =
          (_severityDistribution[measurement.severity] ?? 0) + 1;
    }

    _totalReadings = measurements.length;
    _averageGlucose = sum / _totalReadings;
  }

  Widget _buildStatisticsCard() {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _getFilterTitle(),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                    'Average', '${_averageGlucose.toStringAsFixed(1)} mg/dL'),
                _buildStatItem(
                    'Highest', '${_highestGlucose.toStringAsFixed(1)} mg/dL'),
                _buildStatItem(
                    'Lowest', '${_lowestGlucose.toStringAsFixed(1)} mg/dL'),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Readings Distribution',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSeverityStatItem(
                    'Normal',
                    _severityDistribution[GlucoseSeverity.normal] ?? 0,
                    Colors.green),
                _buildSeverityStatItem(
                    'High',
                    (_severityDistribution[GlucoseSeverity.high] ?? 0) +
                        (_severityDistribution[GlucoseSeverity.dangerous] ?? 0),
                    Colors.red),
                _buildSeverityStatItem(
                    'Low',
                    (_severityDistribution[GlucoseSeverity.low] ?? 0) +
                        (_severityDistribution[GlucoseSeverity.veryLow] ?? 0),
                    Colors.orange),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildSeverityStatItem(String label, int count, Color color) {
    final percentage = _totalReadings > 0
        ? (count / _totalReadings * 100).toStringAsFixed(1)
        : '0';

    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          '$label\n($percentage%)',
          style: TextStyle(
            color: color,
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredMeasurements = _getFilteredMeasurements();

    return Scaffold(
      backgroundColor: const Color(0xFFE6EEF5),
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Glucose History', style: TextStyle(fontWeight: FontWeight.bold),),
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF034985)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAllMeasurements,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildFilterChip('All'),
                              _buildFilterChip('Today'),
                              _buildFilterChip('Week'),
                              _buildFilterChip('Month'),
                            ],
                          ),
                        ),
                        if (filteredMeasurements.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: GlucoseChart(
                              measurements: filteredMeasurements,
                              title: 'Trend Overview',
                              height: 300,
                            ),
                          )
                        else
                          const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Card(
                              color: Colors.white,
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text(
                                  'No measurements available for the selected period',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                        _buildStatisticsCard(),
                      ],
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final measurement = filteredMeasurements[index];
                          return Card(
                            color: Colors.white,
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 2,
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: const BoxDecoration(
                                    color:
                                        Color(0xFF034985), // Dark blue header
                                    borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(10)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Blood Glucose',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(
                                              0.2), // Slightly transparent white background
                                          borderRadius:
                                              BorderRadius.circular(5),
                                        ),
                                        child: Text(
                                          '${measurement.bloodGlucose.toStringAsFixed(0)} mg/dl',
                                          style: TextStyle(
                                            color:
                                                measurement.getSeverityColor(),
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildDetailRow(
                                          'Date',
                                          DateFormat('EEEE, d/M/yyyy')
                                              .format(measurement.createdAt)),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Time',
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                          FutureBuilder<String>(
                                            future: TimezoneService
                                                .formatInUserTimezone(
                                              measurement.createdAt
                                                  .toIso8601String(),
                                              pattern: 'h:mm a',
                                            ),
                                            builder: (context, snapshot) {
                                              if (snapshot.connectionState ==
                                                  ConnectionState.waiting) {
                                                return const SizedBox(
                                                  width: 40,
                                                  height: 16,
                                                  child: Center(
                                                      child:
                                                          CircularProgressIndicator(
                                                              strokeWidth: 2)),
                                                );
                                              }
                                              final timeString =
                                                  snapshot.data ?? '--';
                                              return Row(
                                                children: [
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    timeString,
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      color: Colors.black,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Severity',
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                          Text(
                                            measurement.getSeverityText(),
                                            style: TextStyle(
                                              fontSize: 16,
                                              color: measurement
                                                  .getSeverityColor(),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        childCount: filteredMeasurements.length,
                      ),
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: CommonBottomNavBar(currentIndex: 4),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[700],
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.black,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label) {
    return FilterChip(
      label: Text(label),
      selected: _selectedFilter == label,
      onSelected: (bool selected) {
        setState(() {
          _selectedFilter = label;
          _updateStatistics(_getFilteredMeasurements());
        });
      },
      backgroundColor: Colors.white,
      selectedColor: const Color(0xFF034985),
      labelStyle: TextStyle(
        color: _selectedFilter == label ? Colors.white : Colors.black,
      ),
    );
  }
}
