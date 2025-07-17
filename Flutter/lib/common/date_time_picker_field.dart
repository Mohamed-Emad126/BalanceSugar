import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:flutter_date_pickers/flutter_date_pickers.dart' as dp;

enum DateTimePickerType { date, time, dateTime }

class DateTimePickerField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final void Function(String)? onChanged;
  final DateTime? minDate;
  final DateTime? maxDate;
  final DateTimePickerType pickerType;
  final String? displayFormat;
  final IconData? icon;
  final bool centerDisplay;

  const DateTimePickerField({
    Key? key,
    required this.label,
    required this.controller,
    this.onChanged,
    this.minDate,
    this.maxDate,
    this.pickerType = DateTimePickerType.dateTime,
    this.displayFormat,
    this.icon,
    this.centerDisplay = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget displayTimeWidget = const Text('');
    if (controller.text.isNotEmpty) {
      displayTimeWidget = _buildDisplayWidget(controller.text);
    } else {
      displayTimeWidget = Text(
        _getDefaultHint(),
        style: TextStyle(color: Colors.grey, fontSize: 13),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty)
          Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
        if (label.isNotEmpty) SizedBox(height: 5),
        SizedBox(
          height: 50,
          child: TextButton(
            onPressed: () => _pick(context, controller),
            style: TextButton.styleFrom(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: EdgeInsets.symmetric(horizontal: 10),
            ),
            child: Align(
              alignment:
                  centerDisplay ? Alignment.center : Alignment.centerLeft,
              child: displayTimeWidget,
            ),
          ),
        ),
      ],
    );
  }

  String _getDefaultHint() {
    switch (pickerType) {
      case DateTimePickerType.date:
        return 'Select date';
      case DateTimePickerType.time:
        return 'Select time';
      case DateTimePickerType.dateTime:
      default:
        return 'Select date & time';
    }
  }

  IconData _getDefaultIcon() {
    switch (pickerType) {
      case DateTimePickerType.date:
        return Icons.calendar_today;
      case DateTimePickerType.time:
        return Icons.access_time;
      case DateTimePickerType.dateTime:
      default:
        return Icons.event;
    }
  }

  String _formatDisplay(String isoString) {
    if (displayFormat != null && displayFormat!.isNotEmpty) {
      final dt = DateTime.tryParse(isoString);
      if (dt != null) {
        return DateFormat(displayFormat!).format(dt);
      }
    }
    // Fallbacks based on pickerType
    final dt = DateTime.tryParse(isoString);
    if (dt == null) return isoString;
    switch (pickerType) {
      case DateTimePickerType.date:
        return DateFormat('yMMMd').format(dt);
      case DateTimePickerType.time:
        return DateFormat('h:mm a').format(dt);
      case DateTimePickerType.dateTime:
      default:
        return DateFormat('yMMMd h:mm a').format(dt);
    }
  }

  Widget _buildDisplayWidget(String isoString) {
    TextAlign align = centerDisplay ? TextAlign.center : TextAlign.left;
    CrossAxisAlignment colAlign =
        centerDisplay ? CrossAxisAlignment.center : CrossAxisAlignment.start;
    if (displayFormat != null && displayFormat!.isNotEmpty) {
      final dt = DateTime.tryParse(isoString);
      if (dt != null) {
        return Text(
          DateFormat(displayFormat!).format(dt),
          style: TextStyle(color: Colors.black87),
          textAlign: align,
        );
      }
    }
    final dt = DateTime.tryParse(isoString);
    if (dt == null)
      return Text(isoString,
          style: TextStyle(color: Colors.black87), textAlign: align);
    if (pickerType == DateTimePickerType.dateTime) {
      return Column(
        crossAxisAlignment: colAlign,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            DateFormat('h:mm a').format(dt),
            style: TextStyle(color: Colors.black87),
            textAlign: align,
          ),
          Text(
            DateFormat('EEE, MMM d, yyyy').format(dt),
            style: TextStyle(color: Colors.black87),
            textAlign: align,
          ),
        ],
      );
    } else if (pickerType == DateTimePickerType.date) {
      return Text(
        DateFormat('yMMMd').format(dt),
        style: TextStyle(color: Colors.black87),
        textAlign: align,
      );
    } else if (pickerType == DateTimePickerType.time) {
      return Text(
        DateFormat('h:mm a').format(dt),
        style: TextStyle(color: Colors.black87),
        textAlign: align,
      );
    }
    return Text(isoString,
        style: TextStyle(color: Colors.black87), textAlign: align);
  }

  Future<void> _pick(
      BuildContext context, TextEditingController controller) async {
    DateTime now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final min = minDate ?? today;
    DateTime initial = controller.text.isNotEmpty
        ? DateTime.tryParse(controller.text) ?? min
        : min;
    if (initial.isBefore(min)) initial = min;

    if (pickerType == DateTimePickerType.date) {
      DateTime? pickedDate = await _showCustomDatePicker(
        context,
        initial,
        min,
        maxDate ?? DateTime(now.year + 5),
      );
      if (pickedDate != null) {
        controller.text = pickedDate.toIso8601String();
        if (onChanged != null) onChanged!(controller.text);
      }
    } else if (pickerType == DateTimePickerType.time) {
      TimeOfDay initialTime = controller.text.isNotEmpty
          ? TimeOfDay.fromDateTime(DateTime.parse(controller.text))
          : TimeOfDay.fromDateTime(DateTime.now());
      TimeOfDay? pickedTime =
          await _showCustomTimePicker(context, initialTime: initialTime);
      if (pickedTime != null) {
        final dt = DateTime(
            now.year, now.month, now.day, pickedTime.hour, pickedTime.minute);
        controller.text = dt.toIso8601String();
        if (onChanged != null) onChanged!(controller.text);
      }
    } else {
      // dateTime
      DateTime? pickedDate = await _showCustomDatePicker(
        context,
        initial,
        min,
        maxDate ?? DateTime(now.year + 5),
      );
      if (pickedDate != null) {
        TimeOfDay initialTime = controller.text.isNotEmpty
            ? TimeOfDay.fromDateTime(DateTime.parse(controller.text))
            : TimeOfDay.fromDateTime(DateTime.now());
        TimeOfDay? pickedTime =
            await _showCustomTimePicker(context, initialTime: initialTime);
        if (pickedTime != null) {
          DateTime localDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
          String isoString = localDateTime.toIso8601String();
          controller.text = isoString;
          if (onChanged != null) onChanged!(isoString);
        }
      }
    }
  }

  Future<DateTime?> _showCustomDatePicker(BuildContext context,
      DateTime initialDate, DateTime firstDate, DateTime lastDate) async {
    DateTime selectedDate = initialDate;
    DateTime displayedMonth = DateTime(initialDate.year, initialDate.month);
    const blue = Color(0xFF004A99);
    const monthNames = [
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
    return await showDialog<DateTime>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: StatefulBuilder(
              builder: (context, setState) {
                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          DropdownButton<int>(
                            value: displayedMonth.month,
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                                fontSize: 18),
                            underline: SizedBox(),
                            items: List.generate(
                                12,
                                (i) => DropdownMenuItem(
                                      value: i + 1,
                                      child: Text(monthNames[i],
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black,
                                              fontSize: 18)),
                                    )),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  displayedMonth =
                                      DateTime(displayedMonth.year, val);
                                });
                              }
                            },
                          ),
                          SizedBox(width: 12),
                          DropdownButton<int>(
                            value: displayedMonth.year,
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: blue,
                                fontSize: 18),
                            underline: SizedBox(),
                            items: List.generate(
                              lastDate.year - firstDate.year + 1,
                              (i) => DropdownMenuItem(
                                value: firstDate.year + i,
                                child: Text((firstDate.year + i).toString(),
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: blue,
                                        fontSize: 18)),
                              ),
                            ),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  displayedMonth =
                                      DateTime(val, displayedMonth.month);
                                });
                              }
                            },
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      dp.DayPicker.single(
                        selectedDate: selectedDate,
                        onChanged: (date) =>
                            setState(() => selectedDate = date),
                        firstDate: firstDate,
                        lastDate: lastDate,
                        datePickerStyles: dp.DatePickerRangeStyles(
                          selectedSingleDateDecoration: BoxDecoration(
                              color: blue, shape: BoxShape.circle),
                          selectedDateStyle: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                          dayHeaderStyleBuilder: (day) => dp.DayHeaderStyle(
                            textStyle: TextStyle(
                                color: Colors.blueGrey,
                                fontWeight: FontWeight.bold),
                          ),
                          currentDateStyle: TextStyle(
                              color: blue, fontWeight: FontWeight.bold),
                          defaultDateTextStyle: TextStyle(color: Colors.black),
                          disabledDateStyle: TextStyle(color: Colors.grey),
                        ),
                        datePickerLayoutSettings: dp.DatePickerLayoutSettings(
                          showPrevMonthEnd: true,
                          showNextMonthStart: true,
                          maxDayPickerRowCount: 6,
                          dayPickerRowHeight: 38,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: Color(0xFFF5F5F5),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.10),
                                    blurRadius: 8,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: TextButton(
                                onPressed: () => Navigator.pop(context),
                                style: TextButton.styleFrom(
                                  foregroundColor: Color(0xFF004A99),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  backgroundColor: Color(0xFFF5F5F5),
                                  textStyle: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18),
                                ),
                                child: Text('Cancel',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: Color(0xFF004A99))),
                              ),
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: blue,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: blue.withOpacity(0.10),
                                    blurRadius: 6,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: TextButton(
                                onPressed: () =>
                                    Navigator.pop(context, selectedDate),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  backgroundColor: blue,
                                ),
                                child: Text('Save',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.white)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<TimeOfDay?> _showCustomTimePicker(BuildContext context,
      {TimeOfDay? initialTime}) async {
    int hour = initialTime?.hourOfPeriod ?? TimeOfDay.now().hourOfPeriod;
    int minute = initialTime?.minute ?? TimeOfDay.now().minute;
    int second = 0;
    bool isPm = (initialTime?.period ?? TimeOfDay.now().period) == DayPeriod.pm;
    const blue = Color(0xFF004A99);
    return await showDialog<TimeOfDay>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.15),
      builder: (context) {
        int tempHour = hour;
        int tempMinute = minute;
        int tempSecond = second;
        bool tempIsPm = isPm;
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              elevation: 8,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Set time',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: blue,
                                fontSize: 18)),
                      ),
                      SizedBox(height: 10),
                      SizedBox(
                        height: 140,
                        child: Stack(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _numberPicker(
                                  value: tempHour == 0 ? 12 : tempHour,
                                  minValue: 1,
                                  maxValue: 12,
                                  onChanged: (val) => setState(
                                      () => tempHour = val == 12 ? 0 : val),
                                ),
                                Text(" : ",
                                    style: TextStyle(
                                        fontSize: 22,
                                        color: blue,
                                        fontWeight: FontWeight.bold)),
                                _numberPicker(
                                  value: tempMinute,
                                  minValue: 0,
                                  maxValue: 59,
                                  onChanged: (val) =>
                                      setState(() => tempMinute = val),
                                ),
                                Text(" : ",
                                    style: TextStyle(
                                        fontSize: 22,
                                        color: blue,
                                        fontWeight: FontWeight.bold)),
                                _numberPicker(
                                  value: tempSecond,
                                  minValue: 0,
                                  maxValue: 59,
                                  onChanged: (val) =>
                                      setState(() => tempSecond = val),
                                ),
                                SizedBox(width: 10),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    GestureDetector(
                                      onTap: () =>
                                          setState(() => tempIsPm = false),
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: !tempIsPm
                                              ? blue
                                              : Colors.transparent,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text('AM',
                                            style: TextStyle(
                                                color: !tempIsPm
                                                    ? Colors.white
                                                    : blue,
                                                fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                    SizedBox(height: 10),
                                    GestureDetector(
                                      onTap: () =>
                                          setState(() => tempIsPm = true),
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: tempIsPm
                                              ? blue
                                              : Colors.transparent,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text('PM',
                                            style: TextStyle(
                                                color: tempIsPm
                                                    ? Colors.white
                                                    : blue,
                                                fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: Color(0xFFF5F5F5),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.10),
                                    blurRadius: 8,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: TextButton(
                                onPressed: () => Navigator.pop(context),
                                style: TextButton.styleFrom(
                                  foregroundColor: Color(0xFF004A99),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  backgroundColor: Color(0xFFF5F5F5),
                                  textStyle: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18),
                                ),
                                child: Text('Cancel',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: Color(0xFF004A99))),
                              ),
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: blue,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: blue.withOpacity(0.10),
                                    blurRadius: 6,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: TextButton(
                                onPressed: () {
                                  int finalHour = tempHour == 12 ? 0 : tempHour;
                                  if (tempIsPm) finalHour += 12;
                                  Navigator.pop(
                                      context,
                                      TimeOfDay(
                                          hour: finalHour, minute: tempMinute));
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  backgroundColor: blue,
                                ),
                                child: Text('Save',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.white)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _numberPicker(
      {required int value,
      required int minValue,
      required int maxValue,
      required ValueChanged<int> onChanged}) {
    return SizedBox(
      width: 40,
      height: 120,
      child: CupertinoPicker(
        scrollController:
            FixedExtentScrollController(initialItem: value - minValue),
        itemExtent: 32,
        onSelectedItemChanged: (index) => onChanged(index + minValue),
        children: List.generate(
            maxValue - minValue + 1,
            (index) => Center(
                child:
                    Text('${(index + minValue).toString().padLeft(2, '0')}'))),
      ),
    );
  }

  String _formatBackendTimePretty(String isoString) {
    final dt = DateTime.parse(isoString);
    final time = DateFormat('h:mm a').format(dt);
    final offsetMatch = RegExp(r'([+-]\d{2}:\d{2})$').firstMatch(isoString);
    final offset = offsetMatch != null ? offsetMatch.group(1) : '';
    return offset != null && offset.isNotEmpty ? '$time $offset' : time;
  }
}
