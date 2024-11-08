import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:youbaby/sleep_history.dart';
import 'dart:math';

import 'package:youbaby/sleep_insights.dart';

class SleepTrackerPage extends StatefulWidget {
  final int userID;

  const SleepTrackerPage({super.key, required this.userID});

  @override
  State<SleepTrackerPage> createState() => _SleepTrackerPageState();
}

class _SleepTrackerPageState extends State<SleepTrackerPage> {
  late Stopwatch _stopwatch;
  late Timer _timer;
  bool _isRunning = false;
  bool _isPaused = false;
  DateTime? _startTime;
  DateTime? _pauseTime;

  String _currentTime = '00:00:00'; // New variable to store current time
  bool _canSave = false;
  PanelController _panelController = PanelController();
  bool _isPanelOpen = false;
  late Timer _clockTimer;
  late Color _backgroundColor;
  late Color _textColor;
  late Color _accentColor;
  late Color _cardColor;
  late Color _panelColor;
  String _currentFriendlyMessage = '';

  String _sleepQuality = 'Good';
  List<String> _sleepDisruptions = [];

  List<String> _sleepEnvironmentOptions = [
    'Dark', 'Quiet', 'White Noise', 'Cool', 'Warm'
  ];
  String _sleepEnvironment = '';
  List<String> _selectedEnvironment = [];

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch();
    _timer = Timer.periodic(const Duration(milliseconds: 100), _updateTime);
    _loadTimerState();
    _updateColorScheme(); // Initialize color scheme
    _updateFriendlyMessage(); // Initialize the friendly message
    _loadSleepEnvironment();
  }

  Future<void> _loadSleepEnvironment() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _sleepEnvironment = prefs.getString('sleep_environment') ?? '';
      _selectedEnvironment = _sleepEnvironment.split(', ')
          .where((item) => _sleepEnvironmentOptions.contains(item))
          .toList();
    });
  }

  Future<void> _saveSleepEnvironment() async {
    final prefs = await SharedPreferences.getInstance();
    _sleepEnvironment = _selectedEnvironment.join(', ');
    await prefs.setString('sleep_environment', _sleepEnvironment);
  }

  void _updateFriendlyMessage() {
    setState(() {
      if (_isRunning && !_isPaused) {
        _currentFriendlyMessage = _getRandomMessage(_sleepingMessages);
      } else if (_isPaused) {
        _currentFriendlyMessage = _getRandomMessage(_pausedMessages);
      } else {
        _currentFriendlyMessage = _getRandomMessage(_awakeMessages);
      }
    });
  }

  void _updateColorScheme() {
    setState(() {
      if (!_isRunning) {
        // Initial state (pink color scheme)
        _backgroundColor = const Color(0xFFf5e5ed);
        _textColor = const Color(0xFFA91B60);
        _accentColor = const Color(0xFFA91B60);
        _cardColor = Colors.white;
        _panelColor = Colors.white;
      } else if (_isRunning && !_isPaused) {
        // Running state (blue color scheme)
        _backgroundColor = const Color(0xFF1A237E); // Deep blue
        _textColor = Colors.white70;
        _accentColor = const Color(0xFF4FC3F7); // Light blue
        _cardColor = const Color(0xFF303F9F); // Slightly lighter blue
        _panelColor = const Color(0xFF0D47A1); // Dark blue for panel
      } else if (_isPaused) {
        // Paused state (indigo color scheme)
        _backgroundColor = const Color(0xFF3949AB); // Indigo
        _textColor = Colors.white;
        _accentColor = const Color(0xFFFFD54F); // Amber
        _cardColor = const Color(0xFF5C6BC0); // Lighter indigo
        _panelColor = const Color(0xFF3F51B5); // Indigo for panel
      }
    });
  }

   Widget _buildSleepEnvironmentButton() {
    return ElevatedButton.icon(
      onPressed: _showSleepEnvironmentDialog,
      icon: Icon(Icons.bed),
      label: Text('Sleep Environment'),
      style: ElevatedButton.styleFrom(
        backgroundColor: _accentColor,
        foregroundColor: _backgroundColor,
      ),
    );
  }

  void _showSleepEnvironmentDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Sleep Environment',
                  style: TextStyle(color: _accentColor, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Select all that apply:',
                        style: TextStyle(fontWeight: FontWeight.w500)),
                    SizedBox(height: 10),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: _sleepEnvironmentOptions.map((String option) {
                        return FilterChip(
                          label: Text(option),
                          selected: _selectedEnvironment.contains(option),
                          onSelected: (bool selected) {
                            setState(() {
                              if (selected) {
                                _selectedEnvironment.add(option);
                              } else {
                                _selectedEnvironment.remove(option);
                              }
                            });
                          },
                          selectedColor: _accentColor.withOpacity(0.3),
                          checkmarkColor: _accentColor,
                        );
                      }).toList(),
                    ),
                    SizedBox(height: 10),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: _selectedEnvironment
                          .where((item) => !_sleepEnvironmentOptions.contains(item))
                          .map((String item) {
                        return Chip(
                          label: Text(item),
                          onDeleted: () {
                            setState(() {
                              _selectedEnvironment.remove(item);
                            });
                          },
                          deleteIconColor: Colors.red,
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: Text('Cancel'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                ElevatedButton(
                  child: Text('Save'),
                  onPressed: () {
                    _saveSleepEnvironment();
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accentColor,
                  ),
                ),
              ],
            );
          }
        );
      },
    );
  }

  Widget _buildEnhancedTimerView() {
    return SafeArea(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSleepQualityIndicator(),
                _buildSleepEnvironmentButton(),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildFriendlyMessage(),
                  const SizedBox(height: 20),
                  _buildTimerDisplay(),
                  const SizedBox(height: 40),
                  _buildTimerControls(),
                ],
              ),
            ),
          ),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: _buildActionButton(
                  onPressed:
                      (_isRunning || _isPaused) ? _resetTimerCompletely : null,
                  icon: const Icon(Icons.refresh),
                  label: 'Reset',
                  color: Colors.red,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: _buildActionButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            SleepHistoryPage(userID: widget.userID),
                      ),
                    );
                  },
                  icon: const Icon(Icons.history),
                  label: 'View History',
                  color: _accentColor,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: _buildActionButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            SleepInsightsPage(userID: widget.userID),
                      ),
                    );
                  },
                  icon: const Icon(Icons.insights),
                  label: 'Sleep Insights',
                  color: _accentColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSleepQualityIndicator() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Icon(_getQualityIcon(_sleepQuality),
              color: _getQualityColor(_sleepQuality)),
          const SizedBox(width: 5),
          Text(
            '$_sleepQuality Sleep',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _getQualityColor(_sleepQuality),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getQualityIcon(String quality) {
    switch (quality) {
      case 'Excellent':
        return Icons.star;
      case 'Good':
        return Icons.star_half;
      case 'Poor':
        return Icons.star_border;
      default:
        return Icons.help_outline;
    }
  }

  Color _getQualityColor(String quality) {
    switch (quality) {
      case 'Excellent':
        return Colors.green;
      case 'Good':
        return Colors.amber;
      case 'Poor':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getRandomMessage(List<String> messages) {
    final random = Random();
    return messages[random.nextInt(messages.length)];
  }

  final List<String> _sleepingMessages = [
    'Sweet dreams, little one! 💤',
    'Shh... baby is sleeping peacefully 🌙',
    'Rest well, grow well! 🌟',
    'Dreaming of milk and cuddles 🍼',
    'Counting sheep... or maybe teddy bears? 🐑🧸',
  ];

  final List<String> _awakeMessages = [
    'Ready for some Zzz\'s? 🛏️',
    'Time to cuddle your little star to sleep ✨',
    'Lullaby mode: Activated 🎵',
    'Let\'s get cozy and sleepy 🤗',
    'Adventure time is over, now it\'s dream time! 💫',
  ];

  final List<String> _pausedMessages = [
    'Oh no, did someone wake up? 👀',
    'Diaper change break? We\'ll wait! 🧷',
    'Midnight snack time? 🍼',
    'Just a little interruption in dreamland 😴',
    'Paused for some extra cuddles? 🤗',
  ];

  Widget _buildFriendlyMessage() {
    TextStyle messageStyle = TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.bold,
      color: _textColor,
    );

    if (_isPaused) {
      messageStyle = messageStyle.copyWith(color: Colors.orange);
    }

    return Text(
      _currentFriendlyMessage,
      style: messageStyle,
      textAlign: TextAlign.center,
    );
  }

  Widget _buildTimerDisplay() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _accentColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _accentColor.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Text(
        _calculateElapsedTime(),
        style: TextStyle(
          fontSize: 72.0,
          fontWeight: FontWeight.bold,
          color: _textColor,
        ),
      ),
    );
  }

  Widget _buildTimerControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildActionButton(
          onPressed: _toggleTimer,
          icon: Icon(_isRunning
              ? (_isPaused ? Icons.play_arrow : Icons.pause)
              : Icons.play_arrow),
          label: _isRunning ? (_isPaused ? 'Resume' : 'Pause') : 'Start',
        ),
        const SizedBox(width: 20),
        _buildActionButton(
          onPressed: _canSaveTimer() ? _resetTimer : null,
          icon: const Icon(Icons.save),
          label: 'Save',
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required VoidCallback? onPressed,
    required Icon icon,
    required String label,
    Color? color,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: icon,
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color ?? _accentColor,
        foregroundColor: _backgroundColor,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        elevation: 5,
      ),
    );
  }

  Future<void> _loadTimerState() async {
    final prefs = await SharedPreferences.getInstance();
    final startTimeString = prefs.getString('start_time');
    final isPaused = prefs.getBool('is_paused') ?? false;
    final pauseTimeString = prefs.getString('pause_time');

    if (startTimeString != null) {
      setState(() {
        _startTime = DateTime.parse(startTimeString);
        _isRunning = true;
        _isPaused = isPaused;
        if (_isPaused && pauseTimeString != null) {
          _pauseTime = DateTime.parse(pauseTimeString);
        } else if (!_isPaused) {
          _startTimer();
        }
        _canSave = true;
      });
    } else {
      _resetTimerCompletely();
    }
    _updateColorScheme();
    _updateFriendlyMessage();
  }

  Future<void> _saveTimerState() async {
    final prefs = await SharedPreferences.getInstance();
    if (_startTime != null) {
      await prefs.setString('start_time', _startTime!.toIso8601String());
    }
    await prefs.setBool('is_paused', _isPaused);
    if (_isPaused && _pauseTime != null) {
      await prefs.setString('pause_time', _pauseTime!.toIso8601String());
    } else {
      await prefs.remove('pause_time');
    }
  }

  Future<void> _clearTimerState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('start_time');
    await prefs.remove('is_paused');
    await prefs.remove('pause_time');
  }

  String _formatTimeWithSeconds(int milliseconds) {
    final seconds = (milliseconds / 1000).floor();
    final hours = (seconds / 3600).floor();
    final minutes = ((seconds % 3600) / 60).floor();
    final remainingSeconds = seconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  String _calculateElapsedTime() {
    if (_startTime == null) return '00:00:00';

    final now = DateTime.now();
    Duration elapsed;
    if (_isPaused && _pauseTime != null) {
      elapsed = _pauseTime!.difference(_startTime!);
    } else {
      elapsed = now.difference(_startTime!);
    }
    return _formatTimeWithSeconds(elapsed.inMilliseconds);
  }

  void _updateTime(Timer timer) {
    if (_isRunning && !_isPaused && !_isPanelOpen) {
      setState(() {
        _currentTime = _calculateElapsedTime();
        _canSave = _canSaveTimer();
      });
    }
  }

  void _startTimer() {
    _timer?.cancel(); // Cancel any existing timer
    _timer = Timer.periodic(const Duration(milliseconds: 100), _updateTime);
  }

  void _showStyledAlertDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Theme(
          data: Theme.of(context).copyWith(
            dialogTheme: DialogTheme(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              backgroundColor: Colors.white,
              elevation: 5,
            ),
          ),
          child: AlertDialog(
            title: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFA91B60),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Sleep Duration Too Short',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ],
              ),
            ),
            titlePadding: EdgeInsets.zero,
            content: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                message,
                style: const TextStyle(fontSize: 16),
              ),
            ),
            actions: <Widget>[
              TextButton(
                child: const Text(
                  'OK',
                  style: TextStyle(color: Color(0xFFA91B60), fontSize: 16),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _resetTimerCompletely() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _isPaused = false;
      _startTime = null;
      _pauseTime = null;
      _currentTime = '00:00:00';
      _canSave = false;
    });
    _clearTimerState();
    _updateColorScheme();
    _updateFriendlyMessage();
  }

  void _resetTimer() {
  if (_isRunning || _isPaused) {
    final endTime = DateTime.now();
    final duration =
        _startTime != null ? endTime.difference(_startTime!) : Duration.zero;

    if (_startTime != null && duration.inMinutes >= 1) {
      _saveSleepRecord(_startTime!, endTime, duration);
      print("The duration sleep $duration");
      _resetTimerCompletely();
      _updateColorScheme();
      _updateFriendlyMessage();
    } else {
      _showStyledAlertDialog(
          'Sleep duration must be at least 1 minute to save.');
    }
  }
}

  bool _canSaveTimer() {
    if (_startTime == null) return false;
    final now = DateTime.now();
    final duration = now.difference(_startTime!);
    return duration.inMinutes >= 1;
  }

  String _determineSleepQuality(Duration duration) {
  final minutes = duration.inMinutes;
  print("Determining sleep quality for duration: $duration (${duration.inMinutes} minutes)");
  if (minutes >= 60) {
    print("Quality: Excellent");
    return 'Excellent';
  } else if (minutes >= 45 && minutes < 60) {
    print("Quality: Good");
    return 'Good';
  } else {
    print("Quality: Poor");
    return 'Poor';
  }
}

  Future<void> _saveSleepRecord(
    DateTime start, DateTime end, Duration duration) async {
    final supabase = Supabase.instance.client;

    final sleepQuality = _determineSleepQuality(duration);

    try {
      await supabase.from('sleepTracker').insert({
        'userID': widget.userID,
        'sleepStart': start.toIso8601String(),
        'sleepEnd': end.toIso8601String(),
        'duration': duration.inSeconds,
        'status': 'completed',
        'quality': sleepQuality,
        'disruptions': _sleepDisruptions,
        'environment': _sleepEnvironment, // Use the string representation
        'notes': '',
      });

      print('Sleep data saved successfully to Supabase');
      setState(() {
        _sleepQuality = sleepQuality;
      });
      _resetTimerCompletely();
    } catch (error) {
      print('Error inserting sleep data: $error');
    }
  }

  void _toggleTimer() {
  if (!_isRunning) {
    setState(() {
      _startTime = DateTime.now();
      _isRunning = true;
      _isPaused = false;
      _pauseTime = null;
      _startTimer();
    });
  } else if (_isPaused) {
    setState(() {
      if (_pauseTime != null) {
        final pauseDuration = DateTime.now().difference(_pauseTime!);
        _startTime = _startTime?.add(pauseDuration);
      }
      _isPaused = false;
      _pauseTime = null;
      _startTimer();
    });
  } else {
    setState(() {
      _isPaused = true;
      _pauseTime = DateTime.now();
      _timer?.cancel();
    });
  }
  _saveTimerState();
  _updateColorScheme();
  _updateFriendlyMessage();
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Baby Sleep Tracker',
          style: TextStyle(
            color: Color(0xFFEBE0D0),
            fontSize: 24.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: _accentColor,
      ),
      body: AnimatedContainer(
        duration: Duration(milliseconds: 500),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_backgroundColor, _backgroundColor.withOpacity(0.8)],
          ),
        ),
        child: _buildEnhancedTimerView(),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
