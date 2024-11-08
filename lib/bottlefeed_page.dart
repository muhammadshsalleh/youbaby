import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:youbaby/feedingHistoryPage.dart';

class BottleFeedingTimerService extends ChangeNotifier {
  int elapsedSeconds = 0;
  bool isActive = false;
  DateTime? startTime;
  Timer? _timer;
  DateTime? _lastUpdateTime;

  BottleFeedingTimerService() {
    _loadTimerState();
    _startBackgroundTimer();
  }

  void _loadTimerState() async {
    final prefs = await SharedPreferences.getInstance();
    elapsedSeconds = prefs.getInt('bottleFeedingElapsedSeconds') ?? 0;
    isActive = prefs.getBool('bottleFeedingIsActive') ?? false;
    String? lastUpdateTimeString =
        prefs.getString('bottleFeedingLastUpdateTime');
    if (lastUpdateTimeString != null) {
      _lastUpdateTime = DateTime.parse(lastUpdateTimeString);
      _updateElapsedTime();
    }
    notifyListeners();
  }

  void _updateElapsedTime() {
    if (_lastUpdateTime != null) {
      int secondsSinceLastUpdate =
          DateTime.now().difference(_lastUpdateTime!).inSeconds;
      if (isActive) elapsedSeconds += secondsSinceLastUpdate;
    }
    _lastUpdateTime = DateTime.now();
  }

  void _saveTimerState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('bottleFeedingElapsedSeconds', elapsedSeconds);
    await prefs.setBool('bottleFeedingIsActive', isActive);
    await prefs.setString(
        'bottleFeedingLastUpdateTime', DateTime.now().toIso8601String());
  }

  void _startBackgroundTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (isActive) elapsedSeconds++;
      _saveTimerState();
      notifyListeners();
    });
  }

  void toggleTimer() {
    if (!isActive) {
      startTime = DateTime.now();
    }
    isActive = !isActive;
    _saveTimerState();
    notifyListeners();
  }

  void resetTimer() {
    elapsedSeconds = 0;
    isActive = false;
    startTime = null;
    _saveTimerState();
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class BottleFeedingPage extends StatelessWidget {
  final int userId;

  const BottleFeedingPage({Key? key, required this.userId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => BottleFeedingTimerService(),
      child: _BottleFeedingPageContent(userId: userId),
    );
  }
}

class _BottleFeedingPageContent extends StatefulWidget {
  final int userId;

  const _BottleFeedingPageContent({Key? key, required this.userId})
      : super(key: key);

  @override
  _BottleFeedingPageContentState createState() =>
      _BottleFeedingPageContentState();
}

class _BottleFeedingPageContentState extends State<_BottleFeedingPageContent> {
  bool isTimerMode = true;
  bool isML = true;
  double amount = 0;
  String milkType = 'Formula';
  DateTime? manualStartTime;
  DateTime? manualEndTime;

  late TextEditingController amountController;
  late TextEditingController durationController;

  @override
  void initState() {
    super.initState();
    amountController = TextEditingController(text: '0');
    durationController = TextEditingController(text: '00:00');
  }

  @override
  void dispose() {
    amountController.dispose();
    durationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timerService = Provider.of<BottleFeedingTimerService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bottle Feeding Tracker'),
        backgroundColor: Colors.blue[100],
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => FeedingHistoryPage(userId: widget.userId)),
            ),
          ),
        ],
      ),
      body: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue[50]!, Colors.green[50]!],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                const SizedBox(height: 20),
                _buildModeToggle(),
                const SizedBox(height: 20),
                if (isTimerMode) _buildTimerDisplay(context, timerService),
                if (!isTimerMode) _buildManualTimeInput(),
                const SizedBox(height: 20),
                _buildUnitToggle(),
                const SizedBox(height: 20),
                _buildAmountInput(),
                const SizedBox(height: 20),
                _buildMilkTypeSelector(),
                const SizedBox(height: 40),
                if (isTimerMode) ...[
                  _buildActionButton(
                    context,
                    timerService.isActive ? 'Stop Feeding' : 'Start Feeding',
                    timerService.isActive ? Icons.stop : Icons.play_arrow,
                    Colors.blue[300]!,
                    () => timerService.toggleTimer(),
                  ),
                  const SizedBox(height: 20),
                ],
                _buildActionButton(
                  context,
                  'Save Session',
                  Icons.save,
                  Colors.green[300]!,
                  () => _saveBottleFeedingSession(context, timerService),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Mode: ', style: TextStyle(fontSize: 16)),
        ToggleButtons(
          children: const [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('Timer', style: TextStyle(fontSize: 16)),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('Manual', style: TextStyle(fontSize: 16)),
            ),
          ],
          isSelected: [isTimerMode, !isTimerMode],
          onPressed: (int index) {
            setState(() {
              isTimerMode = index == 0;
            });
          },
          borderRadius: BorderRadius.circular(30),
          selectedColor: Colors.white,
          fillColor: Colors.blue[300],
          borderColor: Colors.blue[300],
          selectedBorderColor: Colors.blue[300],
        ),
      ],
    );
  }

  Widget _buildManualTimeInput() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Feeding Duration',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: durationController,
              keyboardType: TextInputType.datetime,
              decoration: InputDecoration(
                hintText: 'MM:SS',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (value) {
                // You might want to add validation here
              },
              style: const TextStyle(fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimerDisplay(
      BuildContext context, BottleFeedingTimerService timerService) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          const BoxShadow(
              color: Colors.black12, blurRadius: 5, offset: Offset(0, 3))
        ],
      ),
      child: Column(
        children: [
          Text('Feeding Time', style: Theme.of(context).textTheme.titleLarge),
          Text(_formatTime(timerService.elapsedSeconds),
              style: Theme.of(context).textTheme.headlineMedium),
        ],
      ),
    );
  }

  Widget _buildUnitToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Unit: ', style: TextStyle(fontSize: 16)),
        ToggleButtons(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('ml', style: TextStyle(fontSize: 16)),
            ),
            const Padding(
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
          fillColor: Colors.blue[300],
          borderColor: Colors.blue[300],
          selectedBorderColor: Colors.blue[300],
        ),
      ],
    );
  }

  void _convertUnits() {
    if (isML) {
      amount *= 29.5735;
    } else {
      amount /= 29.5735;
    }
    amountController.text = amount.toStringAsFixed(1);
  }

  Widget _buildAmountInput() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Amount',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                suffixText: isML ? 'ml' : 'oz',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (value) {
                double? newValue = double.tryParse(value);
                if (newValue != null) {
                  setState(() => amount = newValue);
                }
              },
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 16),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: Colors.blue[300],
                inactiveTrackColor: Colors.blue[100],
                trackShape: const RoundedRectSliderTrackShape(),
                thumbColor: Colors.blue[500],
                overlayColor: Colors.blue.withAlpha(32),
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 12.0),
                overlayShape:
                    const RoundSliderOverlayShape(overlayRadius: 20.0),
              ),
              child: Slider(
                value: amount,
                min: 0,
                max: isML ? 300 : 300 / 29.5735,
                divisions: isML ? 300 : 100,
                label: amount.round().toString(),
                onChanged: (value) {
                  setState(() => amount = value);
                  amountController.text = value.toStringAsFixed(1);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMilkTypeSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Milk Type',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            DropdownButton<String>(
              value: milkType,
              isExpanded: true,
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() => milkType = newValue);
                }
              },
              items: <String>['Formula', 'Breast Milk', 'Cow\'s Milk']
                  .map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, String label, IconData icon,
      Color color, VoidCallback onPressed) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
      onPressed: onPressed,
    );
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _saveBottleFeedingSession(BuildContext context, BottleFeedingTimerService timerService) async {
    final supabase = Supabase.instance.client;
    DateTime now = DateTime.now();

    int duration;
    DateTime startTime;
    DateTime endTime;

    if (isTimerMode) {
      duration = timerService.elapsedSeconds;
      endTime = now;
      startTime = timerService.startTime ?? now.subtract(Duration(seconds: duration));
    } else {
      // Parse the manual duration input
      List<String> parts = durationController.text.split(':');
      duration = int.parse(parts[0]) * 60 + int.parse(parts[1]);
      endTime = now;
      startTime = now.subtract(Duration(seconds: duration));
    }

    try {
      await supabase.from('feedingTracker').insert({
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'duration': duration,
        'userID': widget.userId,
        'breastSide': 'N/A', // Not applicable for bottle feeding
        'feedingType': 'Bottle',
        'totalTime': duration,
        'quantity': amount,
        'unit': isML ? 'ml' : 'oz',
        'notes': 'Milk Type: $milkType',
        'milkType': milkType,
      });

      if (isTimerMode) {
        timerService.resetTimer();
      } else {
        setState(() {
          durationController.text = '00:00';
          amountController.text = '0';
          amount = 0;
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bottle feeding session saved successfully')),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving bottle feeding session: $error')),
      );
    }
  }
}
