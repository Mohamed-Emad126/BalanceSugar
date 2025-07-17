import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'glucose_measurement.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import '../services/timezone_service.dart';

class GlucoseChart extends StatefulWidget {
  final List<GlucoseMeasurement> measurements;
  final String title;
  final VoidCallback? onViewAllPressed;
  final double height;

  const GlucoseChart({
    Key? key,
    required this.measurements,
    required this.title,
    this.onViewAllPressed,
    this.height = 200,
  }) : super(key: key);

  @override
  State<GlucoseChart> createState() => _GlucoseChartState();
}

class _GlucoseChartState extends State<GlucoseChart> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final measurements = widget.measurements;
    final title = widget.title;
    final onViewAllPressed = widget.onViewAllPressed;
    final height = widget.height;
    if (measurements.isEmpty) {
      return const NoMeasurementsAvailableCard();
    }

    final spots = measurements.asMap().entries.map((entry) {
      return FlSpot(
        entry.key.toDouble(),
        entry.value.bloodGlucose,
      );
    }).toList();

    // Show all points, but scrollable, with 16 visible at a time
    final int visibleCount = 16;
    final int totalCount = measurements.length;
    // No extra space for forecast
    final double extraRightSpace = 0.0;
    final double chartWidth =
        max(400, (min(totalCount, visibleCount)) * 50 + extraRightSpace);

    final allYValues = [
      ...measurements.map((m) => m.bloodGlucose.round()),
      // No predictedSpot
    ];
    final highestYValue = allYValues.isNotEmpty ? allYValues.reduce(max) : 100;
    final yBuffer = 20;
    final scaleInterval = 50;
    final scaleValues = <int>[];
    for (int i = 0; i <= highestYValue + yBuffer; i += scaleInterval) {
      scaleValues.add(i);
    }

    // Calculate fixed Y axis scale
    final int yMax = ((highestYValue + yBuffer) / 50).ceil() * 50;
    final List<int> yAxisLabels =
        List.generate((yMax ~/ 50) + 1, (i) => i * 50);
    final double chartHeight = max(height, yMax.toDouble() + 40);

    // Main line: only real measurements
    final realSpots = spots;
    // No predicted line
    final predictedLine = null;

    return Card(
      color: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (onViewAllPressed != null)
                  TextButton(
                    onPressed: onViewAllPressed,
                    child: const Text('View All'),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: chartHeight,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Y axis labels
                      Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(
                          yAxisLabels.length,
                          (i) => SizedBox(
                            height:
                                (chartHeight - 40) / (yAxisLabels.length - 1),
                            child:
                                (yAxisLabels[yAxisLabels.length - 1 - i] % 50 ==
                                        0)
                                    ? Text(
                                        '${yAxisLabels[yAxisLabels.length - 1 - i]}',
                                        style: const TextStyle(fontSize: 10),
                                      )
                                    : const SizedBox.shrink(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Chart
                      Padding(
                        padding: const EdgeInsets.only(
                            left: 10.5,
                            right: 60.0,
                            top:
                                80.0), // increased top and left padding for tooltip visibility
                        child: SizedBox(
                          width: chartWidth,
                          height: chartHeight - 40,
                          child: LineChart(
                            LineChartData(
                              minY: 0,
                              maxY: yMax.toDouble(),
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                horizontalInterval: 50,
                                getDrawingHorizontalLine: (value) {
                                  if (value % 50 == 0) {
                                    return FlLine(
                                      color: Colors.grey.withOpacity(0.2),
                                      strokeWidth: 1,
                                    );
                                  }
                                  return FlLine(
                                    color: Colors.transparent,
                                    strokeWidth: 0,
                                  );
                                },
                              ),
                              titlesData: FlTitlesData(
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, meta) {
                                      final idx = value.toInt();
                                      // Show only first, last, and every 3rd label
                                      if (idx >= 0 &&
                                          idx < measurements.length &&
                                          value == idx.toDouble()) {
                                        if (idx == 0 ||
                                            idx == measurements.length - 1 ||
                                            idx % 3 == 0) {
                                          return Padding(
                                            padding: const EdgeInsets.all(4.0),
                                            child: FutureBuilder<String>(
                                              future: TimezoneService
                                                  .formatInUserTimezone(
                                                measurements[idx]
                                                    .createdAt
                                                    .toIso8601String(),
                                                pattern: 'h:mm a',
                                              ),
                                              builder: (context, snapshot) {
                                                if (snapshot.connectionState ==
                                                    ConnectionState.waiting) {
                                                  return const SizedBox(
                                                      width: 24, height: 10);
                                                }
                                                return Text(
                                                  snapshot.data ?? '--',
                                                  style: const TextStyle(
                                                      fontSize: 10,
                                                      color: Colors.black87),
                                                );
                                              },
                                            ),
                                          );
                                        } else {
                                          return const SizedBox.shrink();
                                        }
                                      }
                                      return const SizedBox.shrink();
                                    },
                                  ),
                                ),
                                rightTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: false)),
                                topTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: false)),
                              ),
                              borderData: FlBorderData(
                                show: true,
                                border: Border(
                                  bottom: BorderSide(
                                      color: Colors.grey.withOpacity(0.2)),
                                  left: BorderSide(color: Colors.transparent),
                                ),
                              ),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: realSpots,
                                  isCurved: true,
                                  color: const Color(0xFF034985),
                                  barWidth: 3,
                                  dotData: FlDotData(
                                    show: true,
                                    getDotPainter:
                                        (spot, percent, barData, index) {
                                      return FlDotCirclePainter(
                                        radius: 4,
                                        color: measurements[index]
                                            .getSeverityColor(),
                                        strokeWidth: 2,
                                        strokeColor: Colors.white,
                                      );
                                    },
                                  ),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    color: const Color(0xFF034985)
                                        .withOpacity(0.1),
                                  ),
                                ),
                              ],
                              lineTouchData: LineTouchData(
                                touchTooltipData: LineTouchTooltipData(
                                  tooltipRoundedRadius: 12,
                                  tooltipBorder:
                                      const BorderSide(color: Colors.grey),
                                  tooltipPadding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 8),
                                  tooltipMargin: 8,
                                  getTooltipItems:
                                      (List<LineBarSpot> touchedBarSpots) {
                                    return touchedBarSpots.map((barSpot) {
                                      // Real measurement
                                      if (barSpot.barIndex == 0 &&
                                          barSpot.x.toInt() <
                                              measurements.length) {
                                        final measurement =
                                            measurements[barSpot.x.toInt()];
                                        return LineTooltipItem(
                                          '${measurement.bloodGlucose.round()} mg/dL\n'
                                          '${DateFormat('h:mm a').format(measurement.createdAt.toLocal())}\n'
                                          '${DateFormat('dd/MM/yyyy').format(measurement.createdAt.toLocal())}',
                                          const TextStyle(
                                              color: Colors.black,
                                              fontSize: 13),
                                        );
                                      }
                                      return null;
                                    }).toList();
                                  },
                                ),
                              ),
                              clipData: FlClipData.none(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeGlucoseChart extends StatefulWidget {
  final List<GlucoseMeasurement> measurements;
  final String title;
  final VoidCallback? onViewAllPressed;
  final double height;

  const HomeGlucoseChart({
    Key? key,
    required this.measurements,
    required this.title,
    this.onViewAllPressed,
    this.height = 200,
  }) : super(key: key);

  @override
  State<HomeGlucoseChart> createState() => _HomeGlucoseChartState();
}

class _HomeGlucoseChartState extends State<HomeGlucoseChart> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _getTodaySubtitle() {
    final now = DateTime.now();
    final formatted = 'Today, ' + DateFormat('EEE d MMM yyyy').format(now);
    return formatted;
  }

  @override
  Widget build(BuildContext context) {
    final measurements = widget.measurements;
    final title = widget.title;
    final onViewAllPressed = widget.onViewAllPressed;
    final height = widget.height;
    if (measurements.isEmpty) {
      return const NoMeasurementsAvailableCard();
    }

    final spots = measurements.asMap().entries.map((entry) {
      return FlSpot(
        entry.key.toDouble(),
        entry.value.bloodGlucose,
      );
    }).toList();

    // Add forecast spot if available
    FlSpot? predictedSpot;
    bool hasForecast = false;
    if (measurements.isNotEmpty) {
      final last = measurements.last;
      if (last.predictedGlucose != null && last.predictedGlucose! > 0) {
        predictedSpot = FlSpot(
          spots.length.toDouble(),
          last.predictedGlucose!,
        );
        hasForecast = true;
      }
    }

    // Show all points, but scrollable, with 16 visible at a time
    final int visibleCount = 16;
    final int totalCount = measurements.length;
    // Add extra space if forecast is present
    final double extraRightSpace = hasForecast ? 80.0 : 0.0;
    final double minWidth = 350;
    final double maxWidth = 700;
    final double chartWidth = totalCount <= 7
        ? minWidth
        : min(maxWidth, minWidth + (totalCount - 7) * 35 + extraRightSpace);

    final allYValues = [
      ...measurements.map((m) => m.bloodGlucose.round()),
      if (predictedSpot != null) predictedSpot.y.round(),
    ];
    final highestYValue = allYValues.isNotEmpty ? allYValues.reduce(max) : 100;
    final yBuffer = 20;
    final scaleInterval = 50;
    final scaleValues = <int>[];
    for (int i = 0; i <= highestYValue + yBuffer; i += scaleInterval) {
      scaleValues.add(i);
    }

    // Calculate fixed Y axis scale
    final int yMax = ((highestYValue + yBuffer) / 50).ceil() * 50;
    final List<int> yAxisLabels =
        List.generate((yMax ~/ 50) + 1, (i) => i * 50);
    final double chartHeight = max(height, yMax.toDouble() + 40);

    // Main line: only real measurements
    final realSpots = spots;
    // Predicted line: only from last real point to predicted point (if present)
    final predictedLine = (predictedSpot != null && spots.isNotEmpty)
        ? [spots.last, predictedSpot]
        : null;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF3F5F7), // light background
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
        child: Card(
          color: Colors.white,
          elevation: 0.5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Daily Tracking',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _getTodaySubtitle(),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                    if (onViewAllPressed != null)
                      TextButton(
                        onPressed: onViewAllPressed,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.blue[800],
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(50, 30),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          alignment: Alignment.centerRight,
                        ),
                        child: const Text(
                          'View all',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: Color(0xFF1155CC),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: chartHeight,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Y axis labels
                          Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(
                              yAxisLabels.length,
                              (i) => SizedBox(
                                height: (chartHeight - 40) /
                                    (yAxisLabels.length - 1),
                                child:
                                    (yAxisLabels[yAxisLabels.length - 1 - i] %
                                                50 ==
                                            0)
                                        ? Text(
                                            '${yAxisLabels[yAxisLabels.length - 1 - i]}',
                                            style: const TextStyle(fontSize: 9),
                                          )
                                        : const SizedBox.shrink(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Chart
                          Padding(
                            padding: const EdgeInsets.only(
                                left: 10.5, right: 60.0, top: 80.0),
                            child: SizedBox(
                              width: chartWidth,
                              height: chartHeight - 40,
                              child: LineChart(
                                LineChartData(
                                  minY: 0,
                                  maxY: yMax.toDouble(),
                                  gridData: FlGridData(
                                    show: true,
                                    drawVerticalLine: false,
                                    horizontalInterval: 50,
                                    getDrawingHorizontalLine: (value) {
                                      if (value % 50 == 0) {
                                        return FlLine(
                                          color: Colors.grey.withOpacity(0.2),
                                          strokeWidth: 1,
                                        );
                                      }
                                      return FlLine(
                                        color: Colors.transparent,
                                        strokeWidth: 0,
                                      );
                                    },
                                  ),
                                  titlesData: FlTitlesData(
                                    leftTitles: AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        getTitlesWidget: (value, meta) {
                                          final idx = value.toInt();
                                          // Show only first, last, and every 3rd label
                                          if (idx >= 0 &&
                                              idx < measurements.length &&
                                              value == idx.toDouble()) {
                                            if (idx == 0 ||
                                                idx ==
                                                    measurements.length - 1 ||
                                                idx % 3 == 0) {
                                              return Padding(
                                                padding:
                                                    const EdgeInsets.all(4.0),
                                                child: FutureBuilder<String>(
                                                  future: TimezoneService
                                                      .formatInUserTimezone(
                                                    measurements[idx]
                                                        .createdAt
                                                        .toIso8601String(),
                                                    pattern: 'h:mm a',
                                                  ),
                                                  builder: (context, snapshot) {
                                                    if (snapshot
                                                            .connectionState ==
                                                        ConnectionState
                                                            .waiting) {
                                                      return const SizedBox(
                                                          width: 24,
                                                          height: 10);
                                                    }
                                                    return Text(
                                                      snapshot.data ?? '--',
                                                      style: const TextStyle(
                                                          fontSize: 9,
                                                          color:
                                                              Colors.black87),
                                                    );
                                                  },
                                                ),
                                              );
                                            } else {
                                              return const SizedBox.shrink();
                                            }
                                          }
                                          return const SizedBox.shrink();
                                        },
                                      ),
                                    ),
                                    rightTitles: AxisTitles(
                                        sideTitles:
                                            SideTitles(showTitles: false)),
                                    topTitles: AxisTitles(
                                        sideTitles:
                                            SideTitles(showTitles: false)),
                                  ),
                                  borderData: FlBorderData(
                                    show: true,
                                    border: Border(
                                      bottom: BorderSide(
                                          color: Colors.grey.withOpacity(0.2)),
                                      left:
                                          BorderSide(color: Colors.transparent),
                                    ),
                                  ),
                                  lineBarsData: [
                                    LineChartBarData(
                                      spots: realSpots,
                                      isCurved: true,
                                      color: const Color(0xFF034985),
                                      barWidth: 3,
                                      dotData: FlDotData(
                                        show: true,
                                        getDotPainter:
                                            (spot, percent, barData, index) {
                                          return FlDotCirclePainter(
                                            radius: 4,
                                            color: measurements[index]
                                                .getSeverityColor(),
                                            strokeWidth: 2,
                                            strokeColor: Colors.white,
                                          );
                                        },
                                      ),
                                      belowBarData: BarAreaData(
                                        show: true,
                                        color: const Color(0xFF034985)
                                            .withOpacity(0.1),
                                      ),
                                    ),
                                    if (predictedLine != null)
                                      LineChartBarData(
                                        spots: predictedLine,
                                        isCurved: false,
                                        color: Colors.red,
                                        barWidth: 2,
                                        isStrokeCapRound: true,
                                        dashArray: [8, 8],
                                        dotData: FlDotData(
                                          show: true,
                                          getDotPainter:
                                              (spot, percent, barData, index) {
                                            // Only show dot for the predicted point
                                            if (index == 1) {
                                              return FlDotCirclePainter(
                                                radius: 5,
                                                color: Colors.red,
                                                strokeWidth: 2,
                                                strokeColor: Colors.white,
                                              );
                                            }
                                            return FlDotCirclePainter(
                                              radius: 0,
                                              color: Colors.transparent,
                                              strokeWidth: 0,
                                              strokeColor: Colors.transparent,
                                            );
                                          },
                                        ),
                                        belowBarData: BarAreaData(show: false),
                                      ),
                                  ],
                                  lineTouchData: LineTouchData(
                                    touchTooltipData: LineTouchTooltipData(
                                      tooltipRoundedRadius: 12,
                                      tooltipBorder:
                                          const BorderSide(color: Colors.grey),
                                      tooltipPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 8),
                                      tooltipMargin: 8,
                                      getTooltipItems:
                                          (List<LineBarSpot> touchedBarSpots) {
                                        return touchedBarSpots.map((barSpot) {
                                          // Real measurement
                                          if (barSpot.barIndex == 0 &&
                                              barSpot.x.toInt() <
                                                  measurements.length) {
                                            final measurement =
                                                measurements[barSpot.x.toInt()];
                                            return LineTooltipItem(
                                              '${measurement.bloodGlucose.round()} mg/dL\n'
                                              '${DateFormat('h:mm a').format(measurement.createdAt.toLocal())}\n'
                                              '${DateFormat('dd/MM/yyyy').format(measurement.createdAt.toLocal())}',
                                              const TextStyle(
                                                  color: Colors.black,
                                                  fontSize: 13),
                                            );
                                          }
                                          return null;
                                        }).toList();
                                      },
                                    ),
                                  ),
                                  clipData: FlClipData.none(),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class NoMeasurementsAvailableCard extends StatelessWidget {
  const NoMeasurementsAvailableCard({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        margin: const EdgeInsets.only(top: 8, bottom: 8),
        decoration: BoxDecoration(
          color: Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Color(0xFFE0E0E0), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline, color: Color(0xFF757575), size: 20),
            const SizedBox(width: 8),
            Text(
              "No measurements available",
              style: TextStyle(
                color: Color(0xFF424242),
                fontWeight: FontWeight.w500,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
