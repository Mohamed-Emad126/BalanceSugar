import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../Meals/MainMeal.dart';
import '../Measurements/glucose_input_page.dart';
import '../Welcom/newhome.dart';
import '../services/medication_service.dart';
import 'AddPillPage.dart';
import '../services/api_config.dart';
import '../Foot/foot_history_page.dart';
import '../services/auth_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/timezone_service.dart';
import '../common/bottom_nav.dart';

void main() {
  runApp(PillReminderApp());
}

class PillReminderApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: PillReminderScreen(),
    );
  }
}

class PillReminderScreen extends StatefulWidget {
  @override
  _PillReminderScreenState createState() => _PillReminderScreenState();
}

class Medication {
  final String id;
  final String medicationName;
  final String dosageForm;
  final String dosageUnitOfMeasure;
  final double dosageQuantityOfUnitsPerTime;
  final int dosageFrequency;
  final String periodicInterval;
  final String routeOfAdministration;
  final String firstTimeOfIntake;
  final String? stoppedByDatetime;
  final bool isChronicOrAcute;
  final bool equallyDistributedRegimen;
  final bool isActive;
  final dynamic interactionWarning;

  Medication({
    required this.id,
    required this.medicationName,
    required this.dosageForm,
    required this.dosageUnitOfMeasure,
    required this.dosageQuantityOfUnitsPerTime,
    required this.dosageFrequency,
    required this.periodicInterval,
    required this.routeOfAdministration,
    required this.firstTimeOfIntake,
    this.stoppedByDatetime,
    required this.isChronicOrAcute,
    required this.equallyDistributedRegimen,
    required this.isActive,
    this.interactionWarning,
  });

  factory Medication.fromJson(Map<String, dynamic> json) {
    return Medication(
      id: json['id'].toString(),
      medicationName: json['medication_name'],
      dosageForm: json['dosage_form'],
      dosageUnitOfMeasure: json['dosage_unit_of_measure'],
      dosageQuantityOfUnitsPerTime:
          double.parse(json['dosage_quantity_of_units_per_time'].toString()),
      dosageFrequency: int.parse(json['dosage_frequency'].toString()),
      periodicInterval: json['periodic_interval'],
      routeOfAdministration: json['route_of_administration'],
      firstTimeOfIntake: json['first_time_of_intake'],
      stoppedByDatetime: json['stopped_by_datetime'],
      isChronicOrAcute: json['is_chronic_or_acute'] ?? false,
      equallyDistributedRegimen: json['equally_distributed_regimen'] ?? false,
      isActive: json['is_active'] ?? true,
      interactionWarning: json['interaction_warning'],
    );
  }

  Map<String, dynamic> toJson() {
    String? utcFirstTime = firstTimeOfIntake;
    String? utcStoppedBy = stoppedByDatetime;
    try {
      if (firstTimeOfIntake.isNotEmpty) {
        final dt = DateTime.parse(firstTimeOfIntake);
        utcFirstTime = TimezoneService.convertToUtcIso(dt);
      }
      if (stoppedByDatetime != null && stoppedByDatetime!.isNotEmpty) {
        final dt = DateTime.parse(stoppedByDatetime!);
        utcStoppedBy = TimezoneService.convertToUtcIso(dt);
      }
    } catch (_) {}
    return {
      'id': id,
      'medication_name': medicationName,
      'dosage_form': dosageForm,
      'dosage_unit_of_measure': dosageUnitOfMeasure,
      'dosage_quantity_of_units_per_time': dosageQuantityOfUnitsPerTime,
      'dosage_frequency': dosageFrequency,
      'periodic_interval': periodicInterval,
      'route_of_administration': routeOfAdministration,
      'first_time_of_intake': utcFirstTime,
      'stopped_by_datetime': utcStoppedBy,
      'is_chronic_or_acute': isChronicOrAcute,
      'equally_distributed_regimen': equallyDistributedRegimen,
      'is_active': isActive,
      'interaction_warning': interactionWarning,
    };
  }
}

class _PillReminderScreenState extends State<PillReminderScreen> {
  final Color darkBlue = const Color(0xFF034985);
  int selectedIndex = 2;
  bool isLoading = true;
  List<Medication> medications = [];
  List<Medication> activeMedications = [];
  DateTime selectedDate = DateTime.now();
  ScrollController _scrollController = ScrollController();
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  bool _showMonthYearPicker = false;
  String? error;
  bool _interactionShown = false;
  List<dynamic> selectedDayMedications = [];
  List<GlobalKey> _dayKeys = [];

  // Define pill colors map
  final Map<String, Color> pillColors = {
    'color1': Colors.red,
    'color2': Colors.blue,
    'color3': Colors.teal,
    'color4': Colors.yellow,
  };

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    // Load medications in sequence to ensure proper debugging
    _loadMedicationsSequentially();
  }

  Future<void> _loadMedicationsSequentially() async {
    // First load the full medication list
    await loadMedications();
    // Then load today's medications
    await loadMedicationsForToday();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> loadMedicationsForToday() async {
    setState(() {
      isLoading = true;
      error = null;
      selectedDate = DateTime(
          DateTime.now().year, DateTime.now().month, DateTime.now().day);
    });

    try {
      final meds =
          await MedicationService.getCalendarMedicationsForDay(selectedDate);

      setState(() {
        selectedDayMedications = meds;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load medications: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> loadMedications({bool showInteraction = false}) async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final data = await MedicationService.getMedications();
      final List<Medication> loadedMeds =
          data.map((json) => Medication.fromJson(json)).toList();

      setState(() {
        medications = loadedMeds;
        isLoading = false;
      });

      // 🚨 Show dialog if new interaction found and only if showInteraction is true
      if (showInteraction &&
          !_interactionShown &&
          _checkForNewInteractions(loadedMeds) != null &&
          mounted) {
        final interactionInfo = _checkForNewInteractions(loadedMeds);
        if (interactionInfo != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showInteractionDialog(context, interactionInfo);
          });
          _interactionShown = true;
        }
      }

      // Refresh calendar indicators after loading medications
      setState(() {});
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load medications: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> loadActiveMedications() async {
    setState(() {
      isLoading = true;
      error = null;
    });
    try {
      final data = await MedicationService.getActiveMedications();
      setState(() {
        activeMedications =
            data.map((json) => Medication.fromJson(json)).toList();
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load active medications: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> deleteMedication(String id) async {
    try {
      await MedicationService.deleteMedication(id);

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Medication deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Refresh both full medication list and today's medications after deletion
      await loadMedications();
      await loadMedicationsForToday();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete medication: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<dynamic> getMedicationsForDate(DateTime date) {
    // Treat the input date as local for comparison (backend returns correct offset)
    final targetDate = DateTime(date.year, date.month, date.day);

    return medications.where((medication) {
      try {
        final firstIntake = DateTime.parse(medication.firstTimeOfIntake);
        final firstIntakeDate =
            DateTime(firstIntake.year, firstIntake.month, firstIntake.day);
        final stoppedBy = medication.stoppedByDatetime != null
            ? DateTime.parse(medication.stoppedByDatetime!)
            : null;
        final stoppedByDate = stoppedBy != null
            ? DateTime(stoppedBy.year, stoppedBy.month, stoppedBy.day)
            : null;

        // Check if the medication is active on the selected date
        final isActive = (targetDate.isAtSameMomentAs(firstIntakeDate) ||
                targetDate.isAfter(firstIntakeDate)) &&
            (stoppedByDate == null ||
                targetDate.isBefore(stoppedByDate) ||
                targetDate.isAtSameMomentAs(stoppedByDate));

        // Check if the medication is within the selected duration
        if (isActive) {
          if (medication.periodicInterval == 'Daily') {
            return true;
          } else if (medication.periodicInterval == 'Weekly') {
            final daysSinceStart =
                targetDate.difference(firstIntakeDate).inDays;
            return daysSinceStart % 7 == 0;
          } else if (medication.periodicInterval == 'Monthly') {
            return targetDate.day == firstIntakeDate.day;
          }
        }
        return false;
      } catch (e) {
        return false;
      }
    }).toList();
  }

  void _onDateSelected(DateTime date) async {
    // Ensure we're working with a clean date without timezone issues
    final cleanDate = DateTime(date.year, date.month, date.day);

    setState(() {
      selectedDate = cleanDate;
      isLoading = true;
    });

    try {
      final meds =
          await MedicationService.getCalendarMedicationsForDay(cleanDate);

      setState(() {
        selectedDayMedications = meds;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        selectedDayMedications = [];
        isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load medications for selected date: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _editMedication(Map<String, dynamic> medication) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddPillPage(medication: medication),
      ),
    ).then((result) {
      if (result == true) {
        // Refresh both full medication list and today's medications after editing
        loadMedications();
        loadMedicationsForToday();
      }
    });
  }

  Future<void> _showDeleteConfirmation(String id) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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
                        'Delete Medication',
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
                child: Text(
                  'Are you sure you want to delete this medication?',
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
                        onPressed: () => Navigator.of(context).pop(),
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
                        onPressed: () {
                          Navigator.of(context).pop();
                          deleteMedication(id);
                        },
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
        );
      },
    );
  }

  Future<void> _onItemTapped(int index) async {
    if (index == selectedIndex) return;

    setState(() {
      selectedIndex = index;
    });

    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DashboardPage()),
        );
        break;
      case 1:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => MealTrackerScreen()),
        );
        break;
      case 2:
        // Already on Medicine page
        break;
      case 3:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const FootHistoryPage()),
        );
        break;
      case 4:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const GlucoseInputPage()),
        );
        break;
    }
  }

  void _showMonthYearSelector() {
    setState(() {
      _showMonthYearPicker = true;
    });
  }

  Widget _buildMonthYearPicker() {
    List<int> years = List.generate(10, (index) => DateTime.now().year + index);
    List<String> months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];

    return Container(
      height: 280,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            'Select Month and Year',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: darkBlue,
            ),
          ),
          SizedBox(height: 20),
          Expanded(
            child: Row(
              children: [
                // Months
                Expanded(
                  child: ListView.builder(
                    itemCount: months.length,
                    itemBuilder: (context, index) {
                      bool isSelected = index + 1 == _selectedMonth;
                      return ListTile(
                        title: Text(
                          months[index],
                          style: TextStyle(
                            color: isSelected ? darkBlue : Colors.black87,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        selected: isSelected,
                        onTap: () {
                          setState(() {
                            _selectedMonth = index + 1;
                            selectedDate = DateTime(_selectedYear,
                                _selectedMonth, selectedDate.day);
                          });
                        },
                      );
                    },
                  ),
                ),
                // Years
                Expanded(
                  child: ListView.builder(
                    itemCount: years.length,
                    itemBuilder: (context, index) {
                      bool isSelected = years[index] == _selectedYear;
                      return ListTile(
                        title: Text(
                          years[index].toString(),
                          style: TextStyle(
                            color: isSelected ? darkBlue : Colors.black87,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        selected: isSelected,
                        onTap: () {
                          setState(() {
                            _selectedYear = years[index];
                            selectedDate = DateTime(_selectedYear,
                                _selectedMonth, selectedDate.day);
                          });
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (_scrollController.hasClients) {
                              final double itemWidth = 55.0;
                              final double screenWidth =
                                  MediaQuery.of(context).size.width;
                              final int daysInMonth =
                                  DateTime(_selectedYear, _selectedMonth + 1, 0)
                                      .day;
                              final double totalWidth = daysInMonth * itemWidth;
                              double offset =
                                  (selectedDate.day - 1) * itemWidth -
                                      (screenWidth - itemWidth) / 2;
                              if (offset < 0) offset = 0;
                              if (offset > totalWidth - screenWidth)
                                offset = totalWidth - screenWidth;
                              _scrollController.animateTo(
                                offset,
                                duration: Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _showMonthYearPicker = false;
              });
              _onDateSelected(selectedDate);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: darkBlue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text('Done', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarRow() {
    final List<String> daysOfWeek = [
      'Sun',
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat'
    ];
    final DateTime now = DateTime.now();
    final int daysInMonth = DateTime(_selectedYear, _selectedMonth + 1, 0).day;
    final double itemWidth = 55.0;
    final double screenWidth = MediaQuery.of(context).size.width;
    final double totalWidth = daysInMonth * itemWidth;

    // Always jump to the selected day after every build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        double offset = (selectedDate.day - 1) * itemWidth;
        if (offset < 0) offset = 0;
        if (offset > totalWidth - screenWidth)
          offset = totalWidth - screenWidth;
        _scrollController.jumpTo(offset);
      }
    });

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(top: 50, bottom: 5, left: 20, right: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            spreadRadius: 1,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month and Year header
          GestureDetector(
            onTap: _showMonthYearSelector,
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('MMMM')
                          .format(DateTime(_selectedYear, _selectedMonth, 1)),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      _selectedYear.toString(),
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                Icon(Icons.arrow_drop_down, color: Colors.grey),
              ],
            ),
          ),
          SizedBox(height: 20),
          Container(
            height: 80,
            child: ListView.builder(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              itemCount: daysInMonth,
              itemBuilder: (context, index) {
                final date = DateTime(_selectedYear, _selectedMonth, index + 1);
                final isToday = date.year == now.year &&
                    date.month == now.month &&
                    date.day == now.day;
                final isSelected = date.year == selectedDate.year &&
                    date.month == selectedDate.month &&
                    date.day == selectedDate.day;
                final weekDay = daysOfWeek[date.weekday % 7];

                // Check if this date has medications
                final hasMedications = getMedicationsForDate(date).isNotEmpty;

                Color bgColor = Colors.transparent;
                Color textColor = Colors.black87;
                Color indicatorColor = Colors.transparent;

                if (isSelected) {
                  bgColor = darkBlue; // Selected day
                  textColor = Colors.white;
                  indicatorColor = Colors.white;
                } else if (isToday) {
                  bgColor = Colors.lightBlueAccent
                      .withOpacity(0.3); // Today, if not selected
                  textColor = Colors.blue;
                  indicatorColor =
                      hasMedications ? Colors.blue : Colors.transparent;
                } else if (hasMedications) {
                  indicatorColor = darkBlue; // Medication indicator
                }
                return GestureDetector(
                  onTap: () {
                    _onDateSelected(date);
                  },
                  child: Container(
                    width: 55,
                    margin: EdgeInsets.symmetric(horizontal: 5, vertical: 10),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          weekDay,
                          style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          (index + 1).toString(),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFE6EEF5),
        body: Center(child: CircularProgressIndicator(color: darkBlue)),
      );
    }

    return BottomNavScaffold(
      currentIndex: 2,
      backgroundColor: const Color(0xFFE6EEF5),
      body: Stack(
        children: [
          Column(
            children: [
              Container(
                height: 240,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: _buildCalendarRow(),
              ),
              Expanded(
                child: Column(
                  children: [
                    // Medication list
                    Expanded(
                      child: selectedDayMedications.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.asset("images/pillreminder.png",
                                      height: 160),
                                  const SizedBox(height: 10),
                                  Text(
                                    "No medications scheduled",
                                    style: TextStyle(
                                      fontSize: 20,
                                      color: Colors.black,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    DateFormat('EEE, MMM dd, yyyy')
                                        .format(selectedDate),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: EdgeInsets.only(bottom: 90),
                              itemCount: selectedDayMedications.length,
                              itemBuilder: (context, index) {
                                return _buildMedicationCard(
                                    selectedDayMedications[index]);
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_showMonthYearPicker)
            GestureDetector(
              onTap: () => setState(() => _showMonthYearPicker = false),
              child: Container(
                color: Colors.black54,
                alignment: Alignment.center,
                child: _buildMonthYearPicker(),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddPillPage()),
          ).then((result) {
            if (result == true) {
              loadMedications();
              loadMedicationsForToday();
            }
          });
        },
        backgroundColor: darkBlue,
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // Get color based on medication index
  Color _getPillColor(int index) {
    final colorKeys = pillColors.keys.toList();
    return pillColors[colorKeys[index % colorKeys.length]]!;
  }

  Widget _buildMedicationCard(dynamic medication) {
    // Accepts either Medication or CalendarMedication
    final medicationName = medication.medicationName;
    final dosageQuantity =
        medication.dosageQuantityOfUnitsPerTime.toStringAsFixed(0);
    final dosageMg = medication.dosageQuantityOfUnitsPerTime.toStringAsFixed(0);
    final dosageUnit = medication.dosageUnitOfMeasure;
    final dosageForm = medication.dosageForm;
    final firstIntakeRaw = medication is Medication
        ? medication.firstTimeOfIntake
        : medication.firstTimeOfIntake.toIso8601String();
    // Replace displayTime with a plain widget (no FutureBuilder needed)
    Widget displayTime;
    try {
      final dt = DateTime.parse(firstIntakeRaw);
      final displayTimeStr = DateFormat('h:mm a').format(dt);
      displayTime = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.access_time, size: 10.0, color: Colors.grey[600]),
          SizedBox(width: 2),
          Text(
            displayTimeStr,
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
        ],
      );
    } catch (_) {
      displayTime = Text('Invalid time',
          style: TextStyle(color: Colors.red, fontSize: 11));
    }
    final pillColor = _getPillColor(selectedDayMedications
                .indexWhere((m) => m.medicationName == medicationName) >=
            0
        ? selectedDayMedications
            .indexWhere((m) => m.medicationName == medicationName)
        : 0);
    Map<String, dynamic> interactions = {};
    final interactionWarning = medication.interactionWarning;
    if (interactionWarning != null &&
        interactionWarning is String &&
        interactionWarning.trim() != '{}' &&
        interactionWarning.trim().isNotEmpty) {
      try {
        final jsonString = interactionWarning.replaceAll("'", '"');
        final decoded = json.decode(jsonString);
        if (decoded is Map && decoded.isNotEmpty) {
          interactions = Map<String, dynamic>.from(decoded);
        }
      } catch (e) {
        interactions = {'Unknown': interactionWarning.toString()};
      }
    } else if (interactionWarning is Map && interactionWarning.isNotEmpty) {
      interactions = Map<String, dynamic>.from(interactionWarning);
    }
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 90,
            margin: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: pillColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Image.asset(
                'images/pill.png',
                width: 35,
                height: 35,
              ),
            ),
          ),
          Flexible(
            fit: FlexFit.tight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  medicationName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildDetailItem(
                      icon: Icons.circle,
                      iconSize: 8.0,
                      value: '$dosageQuantity $dosageUnit',
                    ),
                    SizedBox(width: 16),
                    displayTime,
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildDetailItem(
                      icon: Icons.grain,
                      iconSize: 10.0,
                      value: '$dosageMg mg',
                    ),
                    SizedBox(width: 40),
                    _buildDetailItem(
                      icon: Icons.category,
                      iconSize: 10.0,
                      value: dosageForm,
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 34,
                height: 45,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon:
                      Icon(Icons.edit_outlined, color: Colors.black, size: 20),
                  onPressed: () {
                    if (medication is Medication) {
                      _editMedication(medication.toJson());
                    } else if (medication is CalendarMedication) {
                      _editMedication({
                        'id': medication.id.toString(),
                        'medication_name': medication.medicationName,
                        'dosage_form': medication.dosageForm,
                        'dosage_unit_of_measure':
                            medication.dosageUnitOfMeasure,
                        'dosage_quantity_of_units_per_time':
                            medication.dosageQuantityOfUnitsPerTime,
                        'periodic_interval': medication.periodicInterval,
                        'dosage_frequency': medication.dosageFrequency,
                        'route_of_administration':
                            medication.routeOfAdministration,
                        'first_time_of_intake':
                            medication.firstTimeOfIntake.toIso8601String(),
                        'stopped_by_datetime':
                            medication.stoppedByDatetime.toIso8601String(),
                        'is_chronic_or_acute':
                            medication.equallyDistributedRegimen,
                        'equally_distributed_regimen':
                            medication.equallyDistributedRegimen,
                        'is_active': true,
                        'interaction_warning': medication.interactionWarning,
                      });
                    }
                  },
                ),
              ),
              Container(
                width: 34,
                height: 45,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon:
                      Icon(Icons.delete_outline, color: Colors.black, size: 20),
                  onPressed: () {
                    _showDeleteConfirmation(medication.id.toString());
                  },
                ),
              ),
              SizedBox(width: 70),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(
      {required IconData icon, double iconSize = 10.0, required String value}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: iconSize, color: Colors.grey[600]),
        SizedBox(width: 2), // Very small spacing
        Text(
          value,
          style: TextStyle(
            fontSize: 11, // Small font size
            color: Colors.grey[600],
          ),
        ),
      ],
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

  void _showInteractionDialog(BuildContext context, Map<String, String> info) {
    final pill1 = info['pill1'] ?? '';
    final pill2 = info['pill2'] ?? '';
    final message = info['message'] ?? '';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title with new background color
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color: Color(0xFF034985), // Deep blue
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                  ),
                ),
                child: Center(
                  child: Text(
                    "Interaction Warning",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: pill1,
                            style: TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          TextSpan(
                            text: ' + ',
                            style: TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          TextSpan(
                            text: pill2,
                            style: TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          TextSpan(
                            text: ':',
                            style: TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      message,
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      "OK",
                      style: TextStyle(
                        color: Color(0xFF034985), // darkBlue
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Map<String, String>? _checkForNewInteractions(List<Medication> meds) {
    final interactionMap = <String, Map<String, String>>{};

    for (var med in meds) {
      try {
        final warningRaw = (med as dynamic).toJson()['interaction_warning'];
        if (warningRaw != null &&
            warningRaw is String &&
            warningRaw.trim().isNotEmpty &&
            warningRaw != '{}') {
          final warningJson = json.decode(warningRaw.replaceAll("'", '"'));
          final map = Map<String, String>.from(warningJson);
          interactionMap[med.medicationName] = map;
        }
      } catch (e) {
        continue;
      }
    }

    for (var entry in interactionMap.entries) {
      for (var conflict in entry.value.entries) {
        // Only show if the conflict is with a different medication
        if (entry.key != conflict.key &&
            meds.any((m) => m.medicationName == conflict.key)) {
          return {
            'pill1': entry.key,
            'pill2': conflict.key,
            'message': conflict.value,
          };
        }
      }
    }
    return null;
  }
}

String formatIntakeTime(String isoString) {
  final dt = DateTime.parse(isoString); // This will keep +03:00 intact
  return DateFormat.Hm().format(dt); // Shows "07:00" if input is "07:00+03:00"
}

// Add this utility class at the top-level (outside any class)
class TimeFormatter {
  static String formatTime(String isoString) {
    final dt = DateTime.parse(isoString);
    return DateFormat.Hm().format(dt);
  }
}
