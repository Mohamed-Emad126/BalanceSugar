import 'package:flutter/material.dart';
import '../services/glucose_service.dart';
import 'package:intl/intl.dart';
import '../Welcom/newhome.dart';
import '../common/bottom_nav.dart';
import '../common/date_time_picker_field.dart';

class GlucoseInputPage extends StatefulWidget {
  const GlucoseInputPage({Key? key}) : super(key: key);

  @override
  State<GlucoseInputPage> createState() => _GlucoseInputPageState();
}

class _GlucoseInputPageState extends State<GlucoseInputPage> {
  final GlucoseService _glucoseService = GlucoseService();
  final TextEditingController _glucoseController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  String? _selectedMeal;
  int selectedIndex = 4; // Tracking page index

  final List<String> _meals = [
    'Pre Breakfast',
    'Post Breackfast',
    'Pre Lunch',
    'Post Lunch',
    'Pre Diner',
    'Post Diner',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = now;
    _dateController.text = now.toIso8601String();
    final nowTime = TimeOfDay.fromDateTime(now);
    _selectedTime = nowTime;
    final dt =
        DateTime(now.year, now.month, now.day, nowTime.hour, nowTime.minute);
    _timeController.text = dt.toIso8601String();
  }

  Future<void> _submitMeasurement() async {
    if (_glucoseController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid glucose value')),
      );
      return;
    }

    final double bloodGlucose = double.parse(_glucoseController.text);
    final DateTime measurementTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    try {
      await _glucoseService.addGlucoseMeasurement(
        bloodGlucose: bloodGlucose,
        timeOfMeasurement: DateFormat('HH:mm').format(measurementTime),
        timestamp: measurementTime,
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DashboardPage()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding measurement: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavScaffold(
      currentIndex: 4,
      backgroundColor: const Color(0xFFE6EEF5),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_ios, color: Colors.blue[900]),
                onPressed: () => Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const DashboardPage()),
                  (route) => false,
                ),
              ),
            ],
          ),
          leadingWidth: 90,
          title: const Text(
            'Add Glucose',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
          centerTitle: true,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(15.0),
        child: Center(
          child: Container(
            width: 500, // Responsive max width for large screens
            height: 580,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 20),

                // Value Section
                Row(
                  children: [
                    Icon(Icons.bloodtype, color: Color(0xFF0F76CE)),
                    SizedBox(width: 8),
                    Text('Value',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _glucoseController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Enter glucose value',
                        ),
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F76CE),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'mg/dL',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Meal Section
                Row(
                  children: [
                    Icon(Icons.restaurant_menu, color: Color(0xFF0F76CE)),
                    SizedBox(width: 8),
                    Text('Meal',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    dropdownColor: Colors.white,
                    value: _selectedMeal,
                    hint: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('Select'),
                    ),
                    items: _meals.map((meal) {
                      return DropdownMenuItem<String>(
                        value: meal,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          child:
                              Text(meal, style: const TextStyle(fontSize: 16)),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedMeal = value;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 14),
                // Time Section
                Row(
                  children: [
                    Icon(Icons.access_time, color: Color(0xFF0F76CE)),
                    SizedBox(width: 8),
                    Text('Time',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),
                DateTimePickerField(
                  label: '',
                  controller: _timeController,
                  pickerType: DateTimePickerType.time,
                  displayFormat: 'h:mm a',
                  onChanged: (val) {
                    final dt = DateTime.tryParse(val);
                    if (dt != null) {
                      setState(() {
                        _selectedTime = TimeOfDay.fromDateTime(dt);
                      });
                    }
                  },
                ),
                const SizedBox(height: 18),
                // Date Section
                Row(
                  children: [
                    Icon(Icons.calendar_today, color: Color(0xFF0F76CE)),
                    SizedBox(width: 8),
                    Text('Date',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),
                DateTimePickerField(
                  label: '',
                  controller: _dateController,
                  pickerType: DateTimePickerType.date,
                  displayFormat: 'EEE dd MMM yyyy',
                  minDate: DateTime(2020),
                  maxDate: DateTime.now().add(const Duration(days: 365)),
                  onChanged: (val) {
                    final dt = DateTime.tryParse(val);
                    if (dt != null) {
                      setState(() {
                        _selectedDate = dt;
                      });
                    }
                  },
                ),
                const SizedBox(height: 32),
                // Add Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitMeasurement,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF0F76CE),
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Add',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
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
