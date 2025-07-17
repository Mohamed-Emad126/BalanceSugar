import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/medication_service.dart';
import '../services/timezone_service.dart';
import '../common/bottom_nav.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_date_pickers/flutter_date_pickers.dart' as dp;
import '../common/date_time_picker_field.dart';

class AddPillPage extends StatefulWidget {
  final Map<String, dynamic>? medication;

  const AddPillPage({Key? key, this.medication}) : super(key: key);

  @override
  _AddPillPageState createState() => _AddPillPageState();
}

class _AddPillPageState extends State<AddPillPage> {
  final TextEditingController _pillNameController = TextEditingController();
  final TextEditingController _pillAmountController = TextEditingController();
  final TextEditingController _dosageController = TextEditingController();
  final TextEditingController _stoppedPillController = TextEditingController();
  final TextEditingController _firstIntakeController = TextEditingController();
  bool _isSubmitting = false;

  String? _selectedForm;
  String? _selectedUnit;
  String? _selectedInterval;
  String? _selectedRoute;

  final List<String> _forms = ["Tablet", "Capsule", "Syrup", "Injectable"];

  final List<String> _units = [
    "Tablet",
    "Capsule",
    "Milligram (mg)",
    "Milliliter (ml)",
  ];

  final List<String> _intervals = ["Daily", "Weekly", "Monthly"];

  final List<String> _routes = [
    "Oral",
    "Intra-muscular",
    "Intravenous",
    "Subcutaneous",
  ];

  bool _isChronicOrAcute = false;
  bool _equallyDistributedRegimen = false;

  @override
  void initState() {
    super.initState();
    if (widget.medication != null) {
      _pillNameController.text = widget.medication!['medication_name'];
      _pillAmountController.text =
          widget.medication!['dosage_quantity_of_units_per_time'].toString();
      _dosageController.text =
          widget.medication!['dosage_frequency'].toString();
      _selectedForm = widget.medication!['dosage_form'];
      _selectedUnit = widget.medication!['dosage_unit_of_measure'];
      _selectedInterval = widget.medication!['periodic_interval'];
      _selectedRoute = widget.medication!['route_of_administration'];
      _firstIntakeController.text =
          widget.medication!['first_time_of_intake'] ?? '';
      _stoppedPillController.text =
          widget.medication!['stopped_by_datetime'] ?? '';
      _isChronicOrAcute = widget.medication!['is_chronic_or_acute'] ?? false;
      _equallyDistributedRegimen =
          widget.medication!['equally_distributed_regimen'] ?? false;
    } else {
      _selectedInterval = null;
      _selectedRoute = null;
    }
  }

  Future<void> _submitMedication() async {
    if (_pillNameController.text.isEmpty ||
        _pillAmountController.text.isEmpty ||
        _dosageController.text.isEmpty ||
        _selectedForm == null ||
        _selectedUnit == null ||
        _selectedInterval == null ||
        _selectedRoute == null ||
        _firstIntakeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_pillNameController.text.length > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Medication name must not exceed 100 characters'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final medicationData = {
        'medication_name': _pillNameController.text,
        'dosage_form': _selectedForm,
        'dosage_unit_of_measure': _selectedUnit,
        'dosage_quantity_of_units_per_time': double.parse(
          _pillAmountController.text,
        ),
        'periodic_interval': _selectedInterval,
        'dosage_frequency': int.parse(_dosageController.text),
        'route_of_administration': _selectedRoute,
        'first_time_of_intake': _firstIntakeController.text,
        'stopped_by_datetime': _stoppedPillController.text.isNotEmpty
            ? _stoppedPillController.text
            : null,
        'is_chronic_or_acute': _isChronicOrAcute,
        'equally_distributed_regimen': _equallyDistributedRegimen,
      };

      Map<String, dynamic> response;
      if (widget.medication != null) {
        response = await MedicationService.updateMedication(
          widget.medication!['id'],
          medicationData,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Medication updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        response = await MedicationService.createMedication(medicationData);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Medication added successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Show interaction warning dialog if present
      if (response['interaction_warning'] != null &&
          response['interaction_warning'].toString().trim().isNotEmpty &&
          response['interaction_warning'].toString().trim() != '{}') {
        final warningRaw = response['interaction_warning'];
        String newMedName = _pillNameController.text.trim();
        String med1 = '', med2 = '', message = '';
        if (warningRaw is Map && warningRaw.isNotEmpty) {
          final entry = warningRaw.entries.first;
          final meds =
              entry.key.toString().split('&').map((s) => s.trim()).toList();
          if (meds.length >= 2) {
            med1 = meds[0];
            med2 = meds[1];
          } else if (meds.length == 1) {
            med1 = meds[0];
            if (newMedName.isNotEmpty && newMedName != med1) {
              med2 = newMedName;
            }
          }
          message = entry.value.toString();
        } else if (warningRaw is String &&
            warningRaw.contains("{") &&
            warningRaw.contains(":")) {
          final regExp = RegExp(r"'([^']+)': '([^']+)'", multiLine: true);
          final match = regExp.firstMatch(warningRaw);
          if (match != null) {
            med1 = match.group(1) ?? '';
            message = match.group(2) ?? '';
            if (newMedName.isNotEmpty && newMedName != med1) {
              med2 = newMedName;
            }
          } else {
            med1 = newMedName;
            message = warningRaw;
          }
        } else if (warningRaw is String) {
          med1 = newMedName;
          message = warningRaw;
        }
        // Skip dialog if only one med and it's the same as the new med
        if (med1.isNotEmpty &&
            (med2.isEmpty || med1 == med2) &&
            med1 == newMedName) {
          Navigator.pop(context, true);
          return;
        }
        await showDialog(
          context: context,
          barrierDismissible: false, // User must acknowledge the warning
          builder: (context) {
            const blue = Color(0xFF004A99);
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: Row(
                children: [
                  Icon(Icons.medical_services_rounded,
                      color: Colors.red, size: 22),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Potential Drug Interaction Detected',
                      style: TextStyle(
                        color: blue,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (med1.isNotEmpty && med2.isNotEmpty && med1 != med2) ...[
                    Text(
                      '$med1 and $med2',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: blue,
                          fontSize: 15),
                    ),
                    SizedBox(height: 8),
                  ] else if (med1.isNotEmpty) ...[
                    Text(
                      med1,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: blue,
                          fontSize: 15),
                    ),
                    SizedBox(height: 8),
                  ],
                  Text(
                    message,
                    style: TextStyle(color: Colors.black87, fontSize: 14),
                  ),
                  SizedBox(height: 18),
                  Text(
                    'Please consult with your healthcare provider before proceeding.',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey[700],
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              actions: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text('OK',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            );
          },
        );
        Navigator.pop(context, true);
        return;
      }

      Navigator.pop(context, true);
    } catch (e) {
      if (e is DrugInteractionException) {
        // Show interaction warning dialog
        String newMedName = _pillNameController.text.trim();
        String med1 = '', med2 = '', message = '';
        if (e.interactions.isNotEmpty) {
          final interaction = e.interactions.first;
          final regExp = RegExp(r"([A-Za-z0-9\- ]+) and ([A-Za-z0-9\- ]+)",
              caseSensitive: false);
          final match = regExp.firstMatch(interaction);
          if (match != null) {
            med1 = match.group(1) ?? '';
            med2 = match.group(2) ?? '';
            message = interaction;
          } else {
            med1 = interaction;
            if (newMedName.isNotEmpty && newMedName != med1) {
              med2 = newMedName;
            }
            message = interaction;
          }
        }
        // Skip dialog if only one med and it's the same as the new med
        if (med1.isNotEmpty &&
            (med2.isEmpty || med1 == med2) &&
            med1 == newMedName) {
          Navigator.pop(context, true);
          return;
        }
        await showDialog(
          context: context,
          barrierDismissible: false, // User must make a choice
          builder: (BuildContext context) {
            const blue = Color(0xFF004A99);
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: Row(
                children: [
                  Icon(Icons.medical_services_rounded,
                      color: Colors.red, size: 22),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Potential Drug Interaction Detected',
                      style: TextStyle(
                        color: blue,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (med1.isNotEmpty && med2.isNotEmpty && med1 != med2) ...[
                    Text(
                      '$med1 and $med2',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: blue,
                          fontSize: 15),
                    ),
                    SizedBox(height: 8),
                  ] else if (med1.isNotEmpty) ...[
                    Text(
                      med1,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: blue,
                          fontSize: 15),
                    ),
                    SizedBox(height: 8),
                  ],
                  Text(
                    message,
                    style: TextStyle(color: Colors.black87, fontSize: 14),
                  ),
                  SizedBox(height: 18),
                  Text(
                    'Please consult with your healthcare provider before proceeding.',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey[700],
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              actions: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text('OK',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            );
          },
        );
        Navigator.pop(context, true);
        return;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFE6EEF5),
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.blue[900]),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.medication != null ? "Edit Medication" : "Add Medication",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 10),
              _buildTextField(
                "Medication Name*",
                "Generic Name of The Medication",
                _pillNameController,
                Icons.medication,
                maxLength: 100,
              ),
              SizedBox(height: 15),
              _buildDropdownRow(
                "Pill Form*",
                _forms,
                _selectedForm,
                Icons.category,
                "Dose Unit*",
                _units,
                _selectedUnit,
                Icons.format_list_numbered,
              ),
              SizedBox(height: 15),
              _buildDropdownRow(
                "Pill Interval*",
                _intervals,
                _selectedInterval,
                Icons.calendar_today,
                "Pill Route*",
                _routes,
                _selectedRoute,
                Icons.route,
              ),
              SizedBox(height: 15),
              _buildAmountAndDosage(),
              SizedBox(height: 15),
              _buildTimePickers(),
              SizedBox(height: 15),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitMedication,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade900,
                  minimumSize: Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isSubmitting
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        widget.medication != null
                            ? "Update Medication"
                            : "Add Medication",
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const CommonBottomNavBar(currentIndex: 2),
    );
  }

  Widget _buildTextField(
    String label,
    String hint,
    TextEditingController controller,
    IconData icon, {
    bool isNumber = false,
    int? maxLength,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 5),
        TextFormField(
          controller: controller,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          maxLength: maxLength,
          style: TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
            filled: true,
            fillColor: Colors.white,
            contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            prefixIcon: Icon(icon, color: Colors.blue[900], size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownRow(
    String label1,
    List<String> items1,
    String? selectedValue1,
    IconData icon1,
    String label2,
    List<String> items2,
    String? selectedValue2,
    IconData icon2,
  ) {
    return Row(
      children: [
        Expanded(
          child: _buildDropdown(label1, items1, selectedValue1, (val) {
            if (label1 == "Pill Form*") {
              setState(() => _selectedForm = val);
            } else if (label1 == "Pill Interval*") {
              setState(() => _selectedInterval = val);
            }
          }, icon1),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _buildDropdown(label2, items2, selectedValue2, (val) {
            if (label2 == "Dose Unit*") {
              setState(() => _selectedUnit = val);
            } else if (label2 == "Pill Route*") {
              setState(() => _selectedRoute = val);
            }
          }, icon2),
        ),
      ],
    );
  }

  Widget _buildDropdown(
    String label,
    List<String> items,
    String? selectedValue,
    ValueChanged<String?> onChanged,
    IconData icon,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 5),
        SizedBox(
          height: 50,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: items.contains(selectedValue) ? selectedValue : null,
                isExpanded: true,
                dropdownColor: Colors.white,
                hint: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: Colors.blue[900], size: 20),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        label == "Pill Interval*"
                            ? "Select Pill\nInterval"
                            : label == "Pill Route*"
                                ? "Select Pill\nRoute"
                                : label == "Pill Form*"
                                    ? "Select Pill\nForm"
                                    : label == "Dose Unit*"
                                        ? "Select Dose\nUnit"
                                        : "Select $label",
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ),
                  ],
                ),
                onChanged: onChanged,
                items: items
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(value),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAmountAndDosage() {
    return Row(
      children: [
        Expanded(
          child: _buildTextField(
            "Pill Amount",
            "Enter amount",
            _pillAmountController,
            Icons.calculate,
            isNumber: true,
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _buildTextField(
            "Dosage",
            "Enter Dosage",
            _dosageController,
            Icons.science,
            isNumber: true,
          ),
        ),
      ],
    );
  }

  Widget _buildTimePickers() {
    return Row(
      children: [
        Expanded(
          child: DateTimePickerField(
            label: "First In-take Time",
            controller: _firstIntakeController,
            onChanged: (_) => setState(() {}),
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: DateTimePickerField(
            label: "Stopped Pill Time",
            controller: _stoppedPillController,
            onChanged: (_) => setState(() {}),
          ),
        ),
      ],
    );
  }
}
