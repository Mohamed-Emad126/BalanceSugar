import 'package:flutter/material.dart';
import '../Profile/Drawer.dart';
import '../chat/chatbot0.dart';
import '../services/glucose_service.dart';
import '../Measurements/glucose_measurement.dart';
import '../Measurements/glucose_history_page.dart';
import '../Measurements/glucose_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Profile/profile.dart';
import 'dart:io';
import '../services/diet_service.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:pedometer/pedometer.dart';
import '../services/medication_service.dart';
import '../services/profile_service.dart';
import '../common/bottom_nav.dart';

final Color lightBlue = const Color(0xFF76CED9);
final Color darkBlue = const Color(0xFF034985);
final Color fabBlue = const Color(0xFF0F76CE);
final Color primaryBlue = const Color(0xFF0F76CE);
final Color yellowAccent = const Color(0xFFFDD00E);
final Color tealAccent = const Color(0xFF13BEB4);
final Color redAccent = const Color(0xFFF6574D);

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with WidgetsBindingObserver {
  int selectedIndex = 0;
  final GlucoseService _glucoseService = GlucoseService();
  final DietService _dietService = DietService();
  List<GlucoseMeasurement> _measurements = [];
  bool _isLoading = true;
  String? _profileImagePath;
  String _username = 'User';
  // For new charts
  int _steps = 0;
  double _distance = 0.0;
  int _stepCalories = 0;
  int _caloriesEaten = 0;
  int _calorieGoal = 0;
  int _caloriesAvailable = 0;
  int _protein = 0, _proteinGoal = 90, _proteinRemaining = 0;
  int _fats = 0, _fatsGoal = 70, _fatsRemaining = 0;
  int _carbs = 0, _carbsGoal = 110, _carbsRemaining = 0;

  // Pedometer specific state variables
  late Stream<StepCount> _stepCountStreamNew;
  late Stream<PedestrianStatus> _pedestrianStatusStreamNew;
  int _pedometerSteps = 0; // Raw steps from pedometer
  DateTime _lastStepRecordDate = DateTime.now().subtract(
      Duration(days: 1)); // Initialize to yesterday to trigger first save

  List<UpcomingMedication> _upcomingMedications = [];
  bool _isMedicationLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadMeasurements();
    _loadUserProfile();
    _loadStepAndCalorieData();
    _initPedometerForHome();
    _loadUpcomingMedications();
  }

  @override
  void dispose() {
    // Cancel any active streams
    _stepCountStreamNew.drain();
    _pedestrianStatusStreamNew.drain();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadUserProfile();
    }
  }

  Future<void> _loadMeasurements() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final measurements = await _glucoseService.getLast16Measurements();
      if (mounted) {
        setState(() {
          _measurements = measurements;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading measurements: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading measurements: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadUserProfile() async {
    // 1. Load from cache for a responsive UI
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedImage = prefs.getString('profile_image');
      if (mounted) {
        setState(() {
          String firstName = prefs.getString('first_name') ?? "";
          String lastName = prefs.getString('last_name') ?? "";
          _username =
              firstName.isNotEmpty ? "$firstName $lastName".trim() : 'User';
          _profileImagePath = cachedImage;
          print("✅ Home: Loaded image from cache: $_profileImagePath");
        });
      }
    } catch (e) {
      print("🚨 Home: Error loading from cache: $e");
    }

    // 2. Fetch latest data from server
    try {
      final profile = await ProfileService.getProfile();
      // 3. ONLY update cache if server provides a valid URL
      if (profile?.imageUrl != null && profile!.imageUrl!.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        print("✅ Home: Fetched image from server: ${profile.imageUrl}");
        await prefs.setString('profile_image', profile.imageUrl!);
        if (mounted && _profileImagePath != profile.imageUrl) {
          setState(() {
            _profileImagePath = profile.imageUrl;
          });
        }
      } else {
        print(
            "🚨 Home: Server returned null/empty image URL. Using cached version.");
      }
    } catch (e) {
      print("🚨 Home: Error fetching profile: $e");
    }
  }

  void _initPedometerForHome() async {
    try {
      _pedestrianStatusStreamNew = Pedometer.pedestrianStatusStream;
      _stepCountStreamNew = Pedometer.stepCountStream;

      _stepCountStreamNew.listen(
        (StepCount event) {
          // Using a temporary variable for raw pedometer steps
          int currentPedometerReading = event.steps;
          print('Pedometer event in newhome: $currentPedometerReading steps');

          // Check if it's a new day compared to when steps were last successfully recorded
          DateTime today = DateTime.now();
          if (_lastStepRecordDate.day != today.day || _pedometerSteps == 0) {
            print(
                'New day detected in pedometer stream or first initialization');
            // Update _pedometerSteps with the current reading before saving
            _pedometerSteps = currentPedometerReading;
            _savePedometerStepsToBackend(_pedometerSteps);
          } else {
            // For existing day, calculate the difference and save
            int stepsToSave = currentPedometerReading;
            print(
                'Existing day in pedometer stream. Current reading: $stepsToSave');
            _savePedometerStepsToBackend(stepsToSave);
          }
        },
        onError: (error) {
          print('Error in newhome step count stream: $error');
        },
        cancelOnError: false,
      );

      _pedestrianStatusStreamNew.listen(
        (PedestrianStatus event) {
          print('Pedestrian status in newhome: ${event.status}');
        },
        onError: (error) {
          print('Error in newhome pedestrian status stream: $error');
        },
        cancelOnError: false,
      );
    } catch (e) {
      print('Error initializing pedometer in newhome: $e');
    }
  }

  Future<void> _savePedometerStepsToBackend(int stepsToSave) async {
    if (stepsToSave <= 0 && _steps > 0) {
      print(
          'Skipping recording of $stepsToSave steps as it might be a reset or initial 0.');
      return;
    }

    try {
      final Map<String, dynamic> serverResponse =
          await _dietService.recordCumulativeSteps(stepsToSave);
      print('Server response: $serverResponse');

      // Extract step history from the response
      final stepHistory =
          serverResponse['step_history'] as Map<String, dynamic>;
      final bool isNewDay = serverResponse['is_new_day'] ?? false;
      final int baselineForToday =
          (serverResponse['baseline_for_today'] ?? 0).toInt();
      final int dailyStepsCalculated =
          (serverResponse['daily_steps_calculated'] ?? 0).toInt();

      setState(() {
        if (isNewDay) {
          _pedometerSteps = baselineForToday;
          _steps = dailyStepsCalculated;
          print('New day: baseline=$baselineForToday, daily steps=$_steps');
        } else {
          _steps = dailyStepsCalculated;
        }

        // Get server values or calculate if needed
        _stepCalories =
            double.tryParse(stepHistory['calories_burned']?.toString() ?? '0.0')
                    ?.toInt() ??
                0;
        _distance =
            double.tryParse(stepHistory['distance']?.toString() ?? '0.0') ??
                0.0;

        // Calculate if we have steps but no server values
        if (_steps > 0) {
          if (_stepCalories == 0) {
            _stepCalories = (_steps * 0.04).round();
          }
          if (_distance == 0.0) {
            _distance = _steps * 0.0008;
          }
        }

        // Update last record date
        if (stepHistory['date'] != null) {
          try {
            String dateString = stepHistory['date'].toString();
            _lastStepRecordDate = DateTime.parse(dateString);
          } catch (e) {
            print('Error parsing date: $e');
            _lastStepRecordDate = DateTime.now();
          }
        } else {
          _lastStepRecordDate = DateTime.now();
        }
      });

      print(
          'Updated state: steps=$_steps, calories=$_stepCalories, distance=${_distance.toStringAsFixed(4)}km');
    } catch (e) {
      print('Error saving steps: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save steps: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadStepAndCalorieData() async {
    if (!mounted) return;

    try {
      // Try to load today's steps from the server
      try {
        print('newhome: Loading step data from getStepsToday API');
        final todayStepsData = await _dietService.getStepsToday();
        if (mounted) {
          setState(() {
            _steps = (todayStepsData['steps'] ?? 0).toInt();
            _stepCalories = double.tryParse(
                        todayStepsData['calories_burned']?.toString() ?? '0')
                    ?.toInt() ??
                0;
            _distance = double.tryParse(
                    todayStepsData['distance']?.toString() ?? '0') ??
                0.0;
            // Check if this data is for today
            final String serverDateStr =
                todayStepsData['date']?.toString() ?? '';
            if (serverDateStr.isNotEmpty) {
              try {
                final DateTime serverDate = DateTime.parse(serverDateStr);
                final DateTime now = DateTime.now();
                if (serverDate.year == now.year &&
                    serverDate.month == now.month &&
                    serverDate.day == now.day) {
                  _lastStepRecordDate = serverDate;
                  // Don't update _pedometerSteps here as it should come from cumulative steps
                }
              } catch (e) {
                print('Error parsing date from steps today: $e');
              }
            }
          });
        }
      } catch (e) {
        print('Error loading steps via getStepsToday in newhome: $e');
        // Don't reset the steps here as they might be available from cumulative steps
        if (mounted) {
          setState(() {
            // Only reset if we don't have any steps yet
            if (_steps == 0) {
              _stepCalories = 0;
              _distance = 0.0;
            }
          });
        }
      }

      // Fetch nutrition summary
      final response = await _dietService.getNutritionSummary();
      if (response != null && mounted) {
        setState(() {
          // Calories data
          _caloriesEaten = (response['calories']['consumed'] ?? 0).toInt();
          _calorieGoal = (response['calories']['goal'] ?? 0).toInt();
          _caloriesAvailable = (response['calories']['remaining'] ?? 0).toInt();

          // Protein data
          _protein = (response['protein']['consumed'] ?? 0).toInt();
          _proteinGoal = (response['protein']['goal'] ?? 0).toInt();
          _proteinRemaining = (response['protein']['remaining'] ?? 0).toInt();

          // Fats data
          _fats = (response['fats']['consumed'] ?? 0).toInt();
          _fatsGoal = (response['fats']['goal'] ?? 0).toInt();
          _fatsRemaining = (response['fats']['remaining'] ?? 0).toInt();

          // Carbs data
          _carbs = (response['carbs']['consumed'] ?? 0).toInt();
          _carbsGoal = (response['carbs']['goal'] ?? 0).toInt();
          _carbsRemaining = (response['carbs']['remaining'] ?? 0).toInt();
        });
      }
    } catch (e) {
      print('Error loading data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadUpcomingMedications() async {
    if (!mounted) return;

    setState(() {
      _isMedicationLoading = true;
    });

    try {
      final upcomingMedications =
          await MedicationService.getUpcomingMedications();

      if (mounted) {
        setState(() {
          _upcomingMedications = upcomingMedications;
          _isMedicationLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading upcoming medications: $e');
      if (mounted) {
        setState(() {
          _isMedicationLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading upcoming medications: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Helper method to format medication time in local timezone
  String _formatMedicationTime(String timeForIntake) {
    // Backend already handles timezone conversion and sends pre-formatted times
    // Just return the time as-is since it's already in the correct format
    return timeForIntake;
  }

  Widget _buildGlucoseChart() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_measurements.isEmpty) {
      return const NoMeasurementsAvailableCard();
    }

    return HomeGlucoseChart(
      measurements: _measurements,
      title: 'Glucose Levels',
      onViewAllPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const GlucoseHistoryPage(),
          ),
        ).then((_) => _loadMeasurements());
      },
    );
  }

  Widget _buildWalkingAndCaloriesRow() {
    final double stepPercent =
        (_steps / 10000).clamp(0.0, 1.0); // Assume 10,000 steps as daily goal
    final double calPercent =
        (_caloriesEaten / (_calorieGoal == 0 ? 1 : _calorieGoal))
            .clamp(0.0, 1.0);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Container(
            width: 280,
            margin: const EdgeInsets.only(right: 12),
            child: Card(
              color: const Color(0xFF2196F3),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              elevation: 6,
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.directions_walk,
                            color: Color(0xFF2196F3),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('Daily Walking',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15)),
                            Text('Calories consumption in a day',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 11)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularPercentIndicator(
                          arcType: ArcType.HALF,
                          radius: 60,
                          lineWidth: 12,
                          percent: 1.0,
                          progressColor: Colors.blue.shade200,
                          circularStrokeCap: CircularStrokeCap.round,
                        ),
                        CircularPercentIndicator(
                          arcType: ArcType.HALF,
                          radius: 60,
                          lineWidth: 12,
                          percent: stepPercent,
                          animation: true,
                          circularStrokeCap: CircularStrokeCap.round,
                          backgroundColor: Colors.transparent,
                          progressColor: Colors.white,
                          center: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('$_steps',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 33)),
                              Text('Steps',
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 14)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(
                      color: Colors.white24,
                      thickness: 1,
                      height: 6,
                      indent: 16,
                      endIndent: 16,
                    ),
                    IntrinsicHeight(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Column(
                            children: [
                              const Text('Distance',
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 14)),
                              const SizedBox(height: 4),
                              Text('${_distance.toStringAsFixed(1)} Km',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18)),
                            ],
                          ),
                          const VerticalDivider(
                            color: Colors.white24,
                            thickness: 1,
                            width: 20,
                            indent: 10,
                            endIndent: 10,
                          ),
                          Column(
                            children: [
                              const Text('Calories',
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 14)),
                              const SizedBox(height: 4),
                              Text('$_stepCalories Kcal',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Container(
            height: 280,
            width: 280,
            child: Card(
              color: const Color(0xFFFF9800),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              elevation: 6,
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.local_fire_department,
                            color: Color(0xFFFF9800),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('Daily Calories',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15)),
                            Text('Calories consumption in a day',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 11)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularPercentIndicator(
                          arcType: ArcType.HALF,
                          radius: 60,
                          lineWidth: 12,
                          percent: 1.0,
                          progressColor: Colors.orange.shade200,
                          circularStrokeCap: CircularStrokeCap.round,
                        ),
                        CircularPercentIndicator(
                          arcType: ArcType.HALF,
                          radius: 60,
                          lineWidth: 12,
                          percent: calPercent,
                          animation: true,
                          circularStrokeCap: CircularStrokeCap.round,
                          backgroundColor: Colors.transparent,
                          progressColor: Colors.white,
                          center: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('$_caloriesEaten',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 33)),
                              Text('of $_calorieGoal kcal',
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 14)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(
                      color: Colors.white24,
                      thickness: 1,
                      height: 12,
                      indent: 16,
                      endIndent: 16,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Text('Protein',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 13)),
                              const SizedBox(height: 8),
                              LinearPercentIndicator(
                                width: 70,
                                percent: (_protein /
                                        (_proteinGoal == 0 ? 1 : _proteinGoal))
                                    .clamp(0.0, 1.0),
                                lineHeight: 5.0,
                                backgroundColor: Colors.white30,
                                progressColor: const Color(0xFF81D4FA),
                                barRadius: const Radius.circular(5),
                              ),
                              const SizedBox(height: 8),
                              Text('$_protein/$_proteinGoal g',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 12)),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Text('Fats',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 13)),
                              const SizedBox(height: 8),
                              LinearPercentIndicator(
                                width: 70,
                                percent:
                                    (_fats / (_fatsGoal == 0 ? 1 : _fatsGoal))
                                        .clamp(0.0, 1.0),
                                lineHeight: 5.0,
                                backgroundColor: Colors.white30,
                                progressColor: const Color(0xFF42A5F5),
                                barRadius: const Radius.circular(5),
                              ),
                              const SizedBox(height: 8),
                              Text('$_fats/$_fatsGoal g',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 12)),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Text('Carbs',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 13)),
                              const SizedBox(height: 8),
                              LinearPercentIndicator(
                                width: 70,
                                percent: (_carbs /
                                        (_carbsGoal == 0 ? 1 : _carbsGoal))
                                    .clamp(0.0, 1.0),
                                lineHeight: 5.0,
                                backgroundColor: Colors.white30,
                                progressColor: const Color(0xFFFFEE58),
                                barRadius: const Radius.circular(5),
                              ),
                              const SizedBox(height: 8),
                              Text('$_carbs/$_carbsGoal g',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicationReminders() {
    if (_isMedicationLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_upcomingMedications.isEmpty) {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          margin: const EdgeInsets.only(top: 8, bottom: 8),
          decoration: BoxDecoration(
            color: Color(0xFFF3F4F6), // subtle grey
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Color(0xFFE0E0E0), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.info_outline, color: Color(0xFF757575), size: 20),
              const SizedBox(width: 8),
              Text(
                "No medications scheduled for today",
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _upcomingMedications.map((medication) {
              return _buildMedicationCard(medication);
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildMedicationCard(UpcomingMedication medication) {
    return Container(
      width: 300, // Adjust width as needed
      margin: const EdgeInsets.only(right: 12),
      child: Card(
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          medication.medicationName,
                          style: TextStyle(
                              color: Color(0xFF034985),
                              fontWeight: FontWeight.bold,
                              fontSize: 26),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${medication.dosageQuantityOfUnitsPerTime.toStringAsFixed(0)}mg, ${medication.dosageForm}',
                          style: const TextStyle(
                              color: Color(0xFF034985), fontSize: 14),
                        ),
                        Text(
                          medication.routeOfAdministration,
                          style: const TextStyle(
                              color: Color(0xFF034985), fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 100,
                    height: 100,
                    child:
                        Image.asset('images/reminder.png', fit: BoxFit.contain),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.notifications,
                      size: 18, color: Color(0xFF034985)),
                  const SizedBox(width: 6),
                  const Text('Reminders',
                      style: TextStyle(color: Color(0xFF034985), fontSize: 16)),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _formatMedicationTime(medication.timeForIntake),
                  style: const TextStyle(
                      color: Color(0xFF034985),
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHealthTipsColumn() {
    final tips = [
      {
        'image': 'images/bed.jpg',
        'title': 'Sleep Well!',
        'subtitle':
            'Getting 7-9 hours of good quality sleep each night helps regulate insulin levels, reduce stress.'
      },
      {
        'image': 'images/Person_running.png',
        'title': 'Stay Active!',
        'subtitle':
            'Walking for just 30 minutes a day can help lower your blood sugar levels and improve your mood.'
      },
      {
        'image': 'images/time.png',
        'title': 'Take Meds on Time',
        'subtitle':
            'Consistently taking your medication as prescribed is crucial for managing your diabetes.'
      },
      {
        'image': 'images/blood-sugar-monitor.png',
        'title': 'Monitor Your Glucose',
        'subtitle':
            'Regularly checking your blood sugar helps you understand your body and make informed decisions.'
      },
      {
        'image': 'images/food.png',
        'title': 'Eat a Balanced Diet',
        'subtitle':
            'Focus on a diet rich in fruits, vegetables, lean proteins, and whole grains to maintain stable blood sugar levels.'
      },
      {
        'image': 'images/hydration.png',
        'title': 'Stay Hydrated',
        'subtitle':
            'Drinking plenty of water can help your kidneys flush out excess sugar and prevent dehydration.'
      },
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: darkBlue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.lightbulb_outline,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Daily Tips',
                style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.bold,
                    fontSize: 21.5),
              ),
            ],
          ),
        ),
        ...tips.map((tip) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: Card(
                color: Colors.white, // Changed to white as per image
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                elevation: 2,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment
                        .center, // Aligned to center vertically
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(
                            8.0), // Rounded corners for the image
                        child: Image.asset(
                          tip['image'] as String,
                          width: 55, // Adjusted image size
                          height: 55,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tip['title'] as String,
                              style: const TextStyle(
                                  fontSize: 17,
                                  color: Color(0xFF091F44),
                                  fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              tip['subtitle'] as String,
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF091F44),
                                  fontWeight: FontWeight.normal),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavScaffold(
      currentIndex: selectedIndex,
      backgroundColor: const Color(0xFFE6EEF5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF034985),
        elevation: 0,
        toolbarHeight: 100,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(30),
          ),
        ),
        automaticallyImplyLeading: false,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(30),
            ),
            color: Color(0xFF034985),
          ),
        ),
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0, top: 8.0),
          child: GestureDetector(
            onTap: () async {
              final prefs = await SharedPreferences.getInstance();
              final userData = UserData(
                firstName: prefs.getString('first_name') ?? "",
                lastName: prefs.getString('last_name') ?? "",
                email: prefs.getString('email') ?? "",
                gender: prefs.getString('gender') ?? "",
                age: prefs.getString('age') ?? "",
                diabetesType: prefs.getString('diabetes_type') ?? "",
                therapy: prefs.getString('therapy') ?? "",
                weight: prefs.getString('weight') ?? "",
                height: prefs.getString('height') ?? "",
              );
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfilePage(user: userData),
                ),
              );

              if (result == true) {
                _loadUserProfile();
              }
            },
            child: _buildProfileImage(),
          ),
        ),
        title: _buildAppBarTitle(),
        actions: [
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: IconButton(
              icon: Icon(Icons.person_outline, color: Colors.white),
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                final userData = UserData(
                  firstName: prefs.getString('first_name') ?? "",
                  lastName: prefs.getString('last_name') ?? "",
                  email: prefs.getString('email') ?? "",
                  gender: prefs.getString('gender') ?? "",
                  age: prefs.getString('age') ?? "",
                  diabetesType: prefs.getString('diabetes_type') ?? "",
                  therapy: prefs.getString('therapy') ?? "",
                  weight: prefs.getString('weight') ?? "",
                  height: prefs.getString('height') ?? "",
                );
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfilePage(user: userData),
                  ),
                );

                // Refresh user data if profile was updated
                if (result == true) {
                  _loadUserProfile();
                }
              },
            ),
          ),
          Builder(
            builder: (context) => Padding(
              padding: const EdgeInsets.only(top: 8.0, right: 8.0),
              child: IconButton(
                icon: Icon(Icons.menu, color: Colors.white),
                onPressed: () {
                  Scaffold.of(context).openEndDrawer();
                },
              ),
            ),
          ),
        ],
      ),
      endDrawer: ProfileDrawer(),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              _buildGlucoseChart(),
              const SizedBox(height: 16),
              _buildWalkingAndCaloriesRow(),
              const SizedBox(height: 16),
              // Add section title for today's medications
              Text(
                "Today's Medications",
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 8),
              _buildMedicationReminders(),
              const SizedBox(height: 16),
              _buildHealthTipsColumn(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(),
            ),
          );
        },
        backgroundColor: darkBlue,
        child: const Icon(
          Icons.chat,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildProfileImage() {
    ImageProvider? backgroundImage;
    if (_profileImagePath != null && _profileImagePath!.isNotEmpty) {
      // Ensure the URL is HTTPS
      final secureUrl = _profileImagePath!.replaceFirst('http://', 'https://');
      if (secureUrl.startsWith('https')) {
        backgroundImage = NetworkImage(secureUrl);
      } else {
        backgroundImage = FileImage(File(_profileImagePath!));
      }
    }

    return CircleAvatar(
      backgroundColor: Colors.white24,
      backgroundImage: backgroundImage,
      child: (backgroundImage == null)
          ? const Icon(Icons.person, color: Colors.white)
          : null,
    );
  }

  Widget _buildAppBarTitle() {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hey, $_username!',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Have a healthy life!',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
              fontWeight: FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
