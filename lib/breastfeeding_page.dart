import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youbaby/feedingHistoryPage.dart';
import 'package:provider/provider.dart';

class TimerService extends ChangeNotifier {
  int leftElapsedSeconds = 0;
  int rightElapsedSeconds = 0;
  bool isLeftActive = false;
  bool isRightActive = false;
  Timer? _timer;
  DateTime? _lastUpdateTime;

  TimerService() {
    _loadTimerState();
    _startBackgroundTimer();
  }

  void _loadTimerState() async {
    final prefs = await SharedPreferences.getInstance();
    leftElapsedSeconds = prefs.getInt('leftElapsedSeconds') ?? 0;
    rightElapsedSeconds = prefs.getInt('rightElapsedSeconds') ?? 0;
    isLeftActive = prefs.getBool('isLeftActive') ?? false;
    isRightActive = prefs.getBool('isRightActive') ?? false;
    String? lastUpdateTimeString = prefs.getString('lastUpdateTime');
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
    await prefs.setInt('leftElapsedSeconds', leftElapsedSeconds);
    await prefs.setInt('rightElapsedSeconds', rightElapsedSeconds);
    await prefs.setBool('isLeftActive', isLeftActive);
    await prefs.setBool('isRightActive', isRightActive);
    await prefs.setString('lastUpdateTime', DateTime.now().toIso8601String());
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
    if (side == 'Left') {
      isLeftActive = !isLeftActive;
    } else {
      isRightActive = !isRightActive;
    }
    _saveTimerState();
    notifyListeners();
  }

  void resetTimer(String side) {
    if (side == 'Left') {
      leftElapsedSeconds = 0;
      isLeftActive = false;
    } else {
      rightElapsedSeconds = 0;
      isRightActive = false;
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

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class BreastfeedingPage extends StatelessWidget {
  final int userId;

  const BreastfeedingPage({Key? key, required this.userId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => TimerService(),
      child: _BreastfeedingPageContent(userId: userId),
    );
  }
}

class _BreastfeedingPageContent extends StatelessWidget {
  final int userId;

  const _BreastfeedingPageContent({Key? key, required this.userId})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final timerService = Provider.of<TimerService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Breastfeeding Tracker'),
        backgroundColor: Colors.pink[100],
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => FeedingHistoryPage(userId: userId)),
            ),
          ),
        ],
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Text(
                'Tap the Left or Right side to start the timer',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: Colors.grey[800]),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildBreastButton(context, 'Left', timerService.isLeftActive,
                      timerService.leftElapsedSeconds, Colors.pink[200]!),
                  _buildBreastButton(
                      context,
                      'Right',
                      timerService.isRightActive,
                      timerService.rightElapsedSeconds,
                      Colors.blue[200]!),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildResetButton(context, 'Left', Colors.black),
                  _buildResetButton(context, 'Right', Colors.black),
                ],
              ),
              _buildTotalTimeDisplay(context, timerService),
              _buildActionButton(
                  context,
                  'Save Session',
                  Icons.save,
                  Colors.green[300]!,
                  () => _saveFeedingSession(context, timerService)),
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
        width: 150,
        height: 150,
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
                size: 40, color: Colors.white),
            Text(side,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(color: Colors.white)),
            Text(_formatTime(elapsedSeconds),
                style: TextStyle(fontSize: 18, color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _buildResetButton(BuildContext context, String side, Color color) {
    return IconButton(
      icon: Icon(Icons.refresh, color: color),
      onPressed: () => _showResetConfirmation(context, side),
      tooltip: 'Reset $side',
    );
  }

  Widget _buildTotalTimeDisplay(
      BuildContext context, TimerService timerService) {
    int totalSeconds =
        timerService.leftElapsedSeconds + timerService.rightElapsedSeconds;
    return Container(
      padding: EdgeInsets.all(20),
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
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: color,
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
          content:
              Text('Are you sure you want to reset the $side breast timer?'),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Reset'),
              onPressed: () {
                // Use parentContext instead of context
                Provider.of<TimerService>(parentContext, listen: false)
                    .resetTimer(side);
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

  void _saveFeedingSession(
      BuildContext context, TimerService timerService) async {
    final supabase = Supabase.instance.client;
    DateTime now = DateTime.now();

    // Function to save individual breast feeding session
    Future<void> saveBreastSession(String side, int duration) async {
      await supabase.from('feedingTracker').insert({
        'startTime':
            now.subtract(Duration(seconds: duration)).toIso8601String(),
        'endTime': now.toIso8601String(),
        'duration': duration,
        'userID': userId,
        'breastSide': side,
        'feedingType': 'Breast',
        'totalTime': duration,
        'quantity': null,
        'notes': '',
      });
    }

    try {
      // Save left breast session if duration > 0
      if (timerService.leftElapsedSeconds > 0) {
        await saveBreastSession('Left', timerService.leftElapsedSeconds);
      }

      // Save right breast session if duration > 0
      if (timerService.rightElapsedSeconds > 0) {
        await saveBreastSession('Right', timerService.rightElapsedSeconds);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Feeding session(s) saved successfully')),
      );

      // Reset both timers after saving
      timerService.resetTimer('Left');
      timerService.resetTimer('Right');
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving feeding session: $error')),
      );
    }
  }
}
