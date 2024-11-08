import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:youbaby/feedingHistoryPage.dart';
import 'package:youbaby/pumpingAmountPage.dart';

class TimerService extends ChangeNotifier {
  int leftElapsedSeconds = 0;
  int rightElapsedSeconds = 0;
  bool isLeftActive = false;
  bool isRightActive = false;
  DateTime? startTime;
  Timer? _timer;
  DateTime? _lastUpdateTime;

  TimerService() {
    _loadTimerState();
    _startBackgroundTimer();
  }

  void _loadTimerState() async {
    final prefs = await SharedPreferences.getInstance();
    leftElapsedSeconds = prefs.getInt('pumpingLeftElapsedSeconds') ?? 0;
    rightElapsedSeconds = prefs.getInt('pumpingRightElapsedSeconds') ?? 0;
    isLeftActive = prefs.getBool('pumpingIsLeftActive') ?? false;
    isRightActive = prefs.getBool('pumpingIsRightActive') ?? false;
    String? lastUpdateTimeString = prefs.getString('pumpingLastUpdateTime');
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
      if (isLeftActive) leftElapsedSeconds += secondsSinceLastUpdate;
      if (isRightActive) rightElapsedSeconds += secondsSinceLastUpdate;
    }
    _lastUpdateTime = DateTime.now();
  }

  void _saveTimerState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('pumpingLeftElapsedSeconds', leftElapsedSeconds);
    await prefs.setInt('pumpingRightElapsedSeconds', rightElapsedSeconds);
    await prefs.setBool('pumpingIsLeftActive', isLeftActive);
    await prefs.setBool('pumpingIsRightActive', isRightActive);
    await prefs.setString(
        'pumpingLastUpdateTime', DateTime.now().toIso8601String());
  }

  void _startBackgroundTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (isLeftActive) leftElapsedSeconds++;
      if (isRightActive) rightElapsedSeconds++;
      _saveTimerState();
      notifyListeners();
    });
  }

  void toggleTimer(String side) {
    if (side == 'Left' || side == 'Right') {
      if (!isLeftActive && !isRightActive) {
        // Start the timer, set startTime if both timers are not active
        startTime = DateTime.now();
      }

      if (side == 'Left') {
        isLeftActive = !isLeftActive;
      } else {
        isRightActive = !isRightActive;
      }

      // If both timers are inactive, clear startTime
      if (!isLeftActive && !isRightActive) {
        startTime = null;
      }

      _saveTimerState();
      notifyListeners();
    }
  }

  void resetTimer(String side) {
    if (side == 'Left') {
      leftElapsedSeconds = 0;
      isLeftActive = false;
    } else {
      rightElapsedSeconds = 0;
      isRightActive = false;
    }

    if (!isLeftActive && !isRightActive) {
      startTime = null;
    }

    _saveTimerState();
    notifyListeners();
  }

  void stopAllTimers() {
    isLeftActive = false;
    isRightActive = false;
    _saveTimerState();
    notifyListeners();
  }

  void pauseTimers() {
    // Pause both timers without resetting elapsed times
    isLeftActive = false;
    isRightActive = false;
    _saveTimerState();
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class PumpingPage extends StatelessWidget {
  final int userId;

  const PumpingPage({Key? key, required this.userId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => TimerService(),
      child: _PumpingPageContent(userId: userId),
    );
  }
}

class _PumpingPageContent extends StatefulWidget {
  final int userId;

  const _PumpingPageContent({Key? key, required this.userId}) : super(key: key);

  @override
  _PumpingPageContentState createState() => _PumpingPageContentState();
}

class _PumpingPageContentState extends State<_PumpingPageContent> {
  bool isML = true;
  TextEditingController leftAmountController = TextEditingController();
  TextEditingController rightAmountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // leftAmountController.text = '0';
    // rightAmountController.text = '0';
  }

  @override
  Widget build(BuildContext context) {
    final timerService = Provider.of<TimerService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pumping Tracker'),
        backgroundColor: Colors.pink[100],
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      FeedingHistoryPage(userId: widget.userId)),
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
            colors: [Colors.pink[50]!, Colors.blue[50]!],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10.0),
                child: Text(
                  'Tap the Left or Right side to start the timer',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: Colors.grey[800]),
                  textAlign: TextAlign.center,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildBreastButton(context, 'Left', timerService.isLeftActive,
                      timerService.leftElapsedSeconds, Colors.pink[300]!),
                  _buildBreastButton(
                      context,
                      'Right',
                      timerService.isRightActive,
                      timerService.rightElapsedSeconds,
                      Colors.blue[300]!),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildResetButton(context, 'Left', Colors.pink[300]!),
                  _buildResetButton(context, 'Right', Colors.blue[300]!),
                ],
              ),
              _buildTotalTimeDisplay(context, timerService),
              _buildActionButton(
                  context,
                  'Save Session',
                  Icons.save,
                  Colors.green[300]!,
                  () => _navigateToAmountInput(context, timerService)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBreastButton(BuildContext context, String side, bool isActive,
      int elapsedSeconds, Color color) {
    final timerService = Provider.of<TimerService>(context, listen: false);
    return GestureDetector(
      onTap: () => timerService.toggleTimer(side),
      child: Container(
        width: 130,
        height: 130,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: Colors.black26, blurRadius: 10, offset: Offset(0, 5))
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isActive ? Icons.pause : Icons.play_arrow,
                size: 36, color: Colors.white),
            Text(side,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(color: Colors.white)),
            Text(_formatTime(elapsedSeconds),
                style: const TextStyle(fontSize: 16, color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _buildResetButton(BuildContext context, String side, Color color) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.refresh, size: 18),
      label: Text('Reset $side'),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
      ),
      onPressed: () => _showResetConfirmation(context, side),
    );
  }

  Widget _buildTotalTimeDisplay(
      BuildContext context, TimerService timerService) {
    int totalSeconds =
        timerService.leftElapsedSeconds + timerService.rightElapsedSeconds;
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(vertical: 20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 5, offset: Offset(0, 3))
        ],
      ),
      child: Column(
        children: [
          Text('Total Time', style: Theme.of(context).textTheme.titleLarge),
          Text(_formatTime(totalSeconds),
              style: Theme.of(context).textTheme.headlineMedium),
        ],
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

  void _showResetConfirmation(BuildContext parentContext, String side) {
  showDialog(
    context: parentContext,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Reset $side Timer'),
        content: Text('Are you sure you want to reset the $side breast timer?'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: const Text('Reset'),
            onPressed: () {
              // Use parentContext instead of context
              Provider.of<TimerService>(parentContext, listen: false).resetTimer(side);
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    },
  );
}

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _navigateToAmountInput(
      BuildContext context, TimerService timerService) async {
        
      timerService.pauseTimers();
    // Use the startTime from TimerService if it's available
    DateTime startTime = timerService.startTime ?? DateTime.now();

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AmountInputPage(
          leftDuration: timerService.leftElapsedSeconds,
          rightDuration: timerService.rightElapsedSeconds,
          userId: widget.userId,
          startTime: startTime, // Pass the startTime here
        ),
      ),
    );

    if (result == true) {
      // Session saved successfully
      timerService.resetTimer('Left');
      timerService.resetTimer('Right');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pumping session saved successfully')),
      );
    }
  }

  @override
  void dispose() {
    leftAmountController.dispose();
    rightAmountController.dispose();
    super.dispose();
  }
}
