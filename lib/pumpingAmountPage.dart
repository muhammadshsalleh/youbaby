import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class AmountInputPage extends StatefulWidget {
  final int leftDuration;
  final int rightDuration;
  final int userId;
  final DateTime startTime;

  const AmountInputPage({
    Key? key,
    required this.leftDuration,
    required this.rightDuration,
    required this.userId,
    required this.startTime,
  }) : super(key: key);

  @override
  _AmountInputPageState createState() => _AmountInputPageState();
}

class _AmountInputPageState extends State<AmountInputPage> {
  double leftAmount = 0;
  double rightAmount = 0;
  bool isML = true;

  final double minAmount = 15; // 0.5 oz
  final double avgAmount = 90; // 3 oz
  final double maxAmount = 300; // 10 oz

  late TextEditingController leftController;
  late TextEditingController rightController;

  @override
  void initState() {
    super.initState();
    leftController = TextEditingController(text: '0');
    rightController = TextEditingController(text: '0');
  }

  @override
  void dispose() {
    leftController.dispose();
    rightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enter Milk Amount'),
        backgroundColor: Colors.pink[100],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.pink[50]!, Colors.blue[50]!],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSessionDetails(),
                SizedBox(height: 20),
                _buildUnitToggle(),
                SizedBox(height: 20),
                if (widget.leftDuration > 0)
                  _buildAmountInput('Left', leftAmount, leftController, (value) {
                    setState(() => leftAmount = value);
                  }),
                if (widget.leftDuration > 0) SizedBox(height: 20),
                if (widget.rightDuration > 0)
                  _buildAmountInput('Right', rightAmount, rightController, (value) {
                    setState(() => rightAmount = value);
                  }),
                if (widget.rightDuration > 0) SizedBox(height: 20),
                _buildTotalAmount(),
                SizedBox(height: 40),
                ElevatedButton(
                  child: Text('Save Session'),
                  onPressed: _savePumpingSession,
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.green[300],
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSessionDetails() {
    String formattedDate =
        DateFormat('MMM d, yyyy - h:mm a').format(widget.startTime);
    String duration =
        _formatDuration(widget.leftDuration + widget.rightDuration);
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Session Date: $formattedDate',
                style: TextStyle(fontSize: 16)),
            SizedBox(height: 8),
            Text('Total Duration: $duration', style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int totalSeconds) {
    int hours = totalSeconds ~/ 3600;
    int minutes = (totalSeconds % 3600) ~/ 60;
    int seconds = totalSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildUnitToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Unit: ', style: TextStyle(fontSize: 16)),
        ToggleButtons(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('ml', style: TextStyle(fontSize: 16)),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('oz', style: TextStyle(fontSize: 16)),
            ),
          ],
          isSelected: [isML, !isML],
          onPressed: (int index) {
            setState(() {
              isML = index == 0;
              _convertUnits();
            });
          },
          borderRadius: BorderRadius.circular(30),
          selectedColor: Colors.white,
          fillColor: Colors.pink[300],
          borderColor: Colors.pink[300],
          selectedBorderColor: Colors.pink[300],
        ),
      ],
    );
  }

  void _convertUnits() {
    if (isML) {
      leftAmount *= 29.5735;
      rightAmount *= 29.5735;
    } else {
      leftAmount /= 29.5735;
      rightAmount /= 29.5735;
    }
    leftController.text = leftAmount.toStringAsFixed(1);
    rightController.text = rightAmount.toStringAsFixed(1);
  }

  Widget _buildAmountInput(String side, double amount,
      TextEditingController controller, void Function(double) onChanged) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('$side Breast',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    keyboardType:
                        TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,1}')),
                    ],
                    decoration: InputDecoration(
                      suffixText: isML ? 'ml' : 'oz',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: (value) {
                      double? newValue = double.tryParse(value);
                      if (newValue != null) {
                        onChanged(newValue);
                      }
                    },
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: Colors.pink[300],
                inactiveTrackColor: Colors.pink[100],
                trackShape: RoundedRectSliderTrackShape(),
                thumbColor: Colors.pink[500],
                overlayColor: Colors.pink.withAlpha(32),
                thumbShape: RoundSliderThumbShape(enabledThumbRadius: 12.0),
                overlayShape: RoundSliderOverlayShape(overlayRadius: 20.0),
              ),
              child: Slider(
                value: amount,
                min: 0,
                max: isML ? maxAmount : maxAmount / 29.5735,
                divisions: isML ? 300 : 100,
                label: amount.round().toString(),
                onChanged: (value) {
                  onChanged(value);
                  controller.text = value.toStringAsFixed(1);
                },
              ),
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildAmountLabel('Min', minAmount),
                _buildAmountLabel('Avg', avgAmount),
                _buildAmountLabel('Max', maxAmount),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountLabel(String label, double amount) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 12)),
        Text(
          '${isML ? amount.toStringAsFixed(0) : (amount / 29.5735).toStringAsFixed(1)}',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        Text(isML ? 'ml' : 'oz', style: TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildSliderOverlay() {
    return IgnorePointer(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(width: 2, height: 20, color: Colors.blue),
          Container(width: 2, height: 20, color: Colors.green),
          Container(width: 2, height: 20, color: Colors.red),
        ],
      ),
    );
  }

  Widget _buildTotalAmount() {
    double totalAmount = leftAmount + rightAmount;
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Total Amount',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text(
              '${totalAmount.toStringAsFixed(1)} ${isML ? 'ml' : 'oz'}',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.green),
            ),
          ],
        ),
      ),
    );
  }

  void _savePumpingSession() async {
    final supabase = Supabase.instance.client;
    DateTime now = DateTime.now();

    Future<void> saveBreastSession(
        String side, int duration, double amount) async {
      await supabase.from('feedingTracker').insert({
        'startTime':
            now.subtract(Duration(seconds: duration)).toIso8601String(),
        'endTime': now.toIso8601String(),
        'duration': duration,
        'userID': widget.userId,
        'breastSide': side,
        'feedingType': 'Pumping',
        'totalTime': duration,
        'quantity': amount,
        'unit': isML ? 'ml' : 'oz',
        'notes': '',
      });
    }

    try {
      if (widget.leftDuration > 0) {
        await saveBreastSession('Left', widget.leftDuration, leftAmount);
      }

      if (widget.rightDuration > 0) {
        await saveBreastSession('Right', widget.rightDuration, rightAmount);
      }

      Navigator.pop(context, true); // Return true to indicate success
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving pumping session: $error')),
      );
    }
  }
}