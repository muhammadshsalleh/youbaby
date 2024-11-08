import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class SleepHistoryPage extends StatefulWidget {
  final int userID;

  const SleepHistoryPage({Key? key, required this.userID}) : super(key: key);

  @override
  _SleepHistoryPageState createState() => _SleepHistoryPageState();
}

class _SleepHistoryPageState extends State<SleepHistoryPage> {
  String _selectedCategory = 'Today';
  Map<String, List<Map<String, dynamic>>> _categorizedSleepRecords = {
    'Today': [],
    'Yesterday': [],
    'Last 7 Days': [],
    'Last 14 Days': [],
  };

  Map<String, Duration> _cumulativeSleepTime = {
    'Today': Duration.zero,
    'Yesterday': Duration.zero,
    'Last 7 Days': Duration.zero,
    'Last 14 Days': Duration.zero,
  };

  @override
  void initState() {
    super.initState();
    _loadSleepRecords();
  }

  Future<void> _loadSleepRecords() async {
    final supabase = Supabase.instance.client;

    try {
      final response = await supabase
          .from('sleepTracker')
          .select()
          .eq('userID', widget.userID)
          .order('sleepStart', ascending: false)
          .limit(100);

      setState(() {
        _categorizeSleepRecords(response);
        _calculateCumulativeSleepTime();
      });
    } catch (error) {
      print('Error fetching sleep records: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load sleep records')),
      );
    }
  }

  void _categorizeSleepRecords(List<Map<String, dynamic>> records) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final sevenDaysAgo = today.subtract(const Duration(days: 7));
    final fourteenDaysAgo = today.subtract(const Duration(days: 14));

    setState(() {
      _categorizedSleepRecords = {
        'Today': [],
        'Yesterday': [],
        'Last 7 Days': [],
        'Last 14 Days': [],
      };

      for (var record in records) {
        final sleepStart = DateTime.parse(record['sleepStart']);
        if (sleepStart.isAfter(today)) {
          _categorizedSleepRecords['Today']!.add(record);
        } else if (sleepStart.isAfter(yesterday)) {
          _categorizedSleepRecords['Yesterday']!.add(record);
        } else if (sleepStart.isAfter(sevenDaysAgo)) {
          _categorizedSleepRecords['Last 7 Days']!.add(record);
        } else if (sleepStart.isAfter(fourteenDaysAgo)) {
          _categorizedSleepRecords['Last 14 Days']!.add(record);
        }
      }
    });
  }

  void _calculateCumulativeSleepTime() {
    setState(() {
      _cumulativeSleepTime = {
        'Today': Duration.zero,
        'Yesterday': Duration.zero,
        'Last 7 Days': Duration.zero,
        'Last 14 Days': Duration.zero,
      };

      _categorizedSleepRecords.forEach((category, records) {
        for (var record in records) {
          final duration = Duration(seconds: record['duration']);
          _cumulativeSleepTime[category] =
              _cumulativeSleepTime[category]! + duration;
        }
      });
    });
  }

  // Function to delete a sleep record
  Future<void> _deleteSleepRecord(int id) async {
    final supabase = Supabase.instance.client;

    try {
      await supabase.from('sleepTracker').delete().eq('id', id);
      _loadSleepRecords();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sleep record deleted successfully')),
      );
    } catch (error) {
      print('Error deleting sleep record: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete sleep record')),
      );
    }
  }

  // Function to update a sleep record
  Future<void> _updateSleepRecord(
      int id, DateTime startTime, DateTime endTime, String note) async {
    final supabase = Supabase.instance.client;

    try {
      final duration = endTime.difference(startTime).inSeconds;
      await supabase
          .from('sleepTracker')
          .update({
            'sleepStart': startTime.toIso8601String(),
            'sleepEnd': endTime.toIso8601String(),
            'duration': duration,
            'notes': note,
          })
          .eq('id', id);

      _loadSleepRecords();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sleep record updated successfully')),
      );
    } catch (error) {
      print('Error updating sleep record: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update sleep record')),
      );
    }
  }

  // Show a dialog to update sleep record
  void _showUpdateDialog(Map<String, dynamic> record) {
    final TextEditingController noteController =
        TextEditingController(text: record['notes'] ?? '');
    DateTime startTime = DateTime.parse(record['sleepStart']);
    DateTime endTime = DateTime.parse(record['sleepEnd']);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Update Sleep Record'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: noteController,
                      decoration: const InputDecoration(labelText: 'Notes'),
                    ),
                    const SizedBox(height: 20),
                    const Text('Start Time:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(DateFormat('MMM d, h:mm a').format(startTime)),
                    ElevatedButton(
                      onPressed: () async {
                        final pickedDateTime = await showDatePicker(
                          context: context,
                          initialDate: startTime,
                          firstDate: DateTime(2022),
                          lastDate: DateTime.now(),
                        );
                        if (pickedDateTime != null) {
                          final pickedTime = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(startTime),
                          );
                          if (pickedTime != null) {
                            setState(() {
                              startTime = DateTime(
                                pickedDateTime.year,
                                pickedDateTime.month,
                                pickedDateTime.day,
                                pickedTime.hour,
                                pickedTime.minute,
                              );
                            });
                          }
                        }
                      },
                      child: const Text('Change Start Time'),
                    ),
                    const SizedBox(height: 20),
                    const Text('End Time:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(DateFormat('MMM d, h:mm a').format(endTime)),
                    ElevatedButton(
                      onPressed: () async {
                        final pickedDateTime = await showDatePicker(
                          context: context,
                          initialDate: endTime,
                          firstDate: DateTime(2022),
                          lastDate: DateTime.now(),
                        );
                        if (pickedDateTime != null) {
                          final pickedTime = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(endTime),
                          );
                          if (pickedTime != null) {
                            setState(() {
                              endTime = DateTime(
                                pickedDateTime.year,
                                pickedDateTime.month,
                                pickedDateTime.day,
                                pickedTime.hour,
                                pickedTime.minute,
                              );
                            });
                          }
                        }
                      },
                      child: const Text('Change End Time'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _updateSleepRecord(record['id'], startTime, endTime, noteController.text);
                  },
                  child: const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildCategorySelector() {
    final categories = ['Today', 'Yesterday', 'Last 7 Days', 'Last 14 Days'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: categories.map((category) {
          final isSelected = _selectedCategory == category;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  _selectedCategory = category;
                });
              },
              style: ElevatedButton.styleFrom(
                foregroundColor: isSelected ? Colors.white : Colors.black,
                backgroundColor: isSelected ? Colors.blue : Colors.grey,
              ),
              child: Text(category),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCumulativeSleepTimeCard(String category) {
    final duration = _cumulativeSleepTime[category]!;
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    final targetSleepHours = {
      'Today': 14,
      'Yesterday': 14,
      'Last 7 Days': 98,
      'Last 14 Days': 196,
    };

    final targetHours = targetSleepHours[category]!;
    final progress = duration.inHours / targetHours;

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              category,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '$hours hours $minutes minutes',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: Colors.grey[300],
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
            const SizedBox(height: 4),
            Text(
              '${(progress * 100).toStringAsFixed(1)}% of sleep hours achieved',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Actual Sleep: $hours h ${minutes} m',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                Text(
                  'Target: $targetHours h',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sleep History'),
        backgroundColor: Colors.indigo,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.indigo.shade50, Colors.white],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildCategorySelector(),
              const SizedBox(height: 16),
              _buildCumulativeSleepTimeCard(_selectedCategory),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: _categorizedSleepRecords[_selectedCategory]!.length,
                  itemBuilder: (context, index) {
                    final record = _categorizedSleepRecords[_selectedCategory]![index];
                    final startTime = DateFormat('MMM d, h:mm a')
                        .format(DateTime.parse(record['sleepStart']));
                    final endTime = DateFormat('MMM d, h:mm a')
                        .format(DateTime.parse(record['sleepEnd']));
                    final duration = Duration(seconds: record['duration']);
                    final hours = duration.inHours;
                    final minutes = duration.inMinutes.remainder(60);

                    return Dismissible(
                      key: Key(record['id'].toString()),
                      background: Container(
                        color: Colors.blue,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: 20.0),
                        child: const Icon(Icons.edit, color: Colors.white),
                      ),
                      secondaryBackground: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20.0),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (direction) async {
                        if (direction == DismissDirection.startToEnd) {
                          _showUpdateDialog(record);
                          return false;
                        } else if (direction == DismissDirection.endToStart) {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Confirm Deletion'),
                              content: const Text('Are you sure you want to delete this sleep record?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true) {
                            await _deleteSleepRecord(record['id']);
                            return true;
                          }
                        }
                        return false;
                      },
                      child: Card(
                        elevation: 4,
                        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          title: Text(
                            '$startTime - $endTime',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Duration: $hours hours $minutes minutes'),
                              Text('Notes: ${record['notes'] ?? 'No notes'}'),
                            ],
                          ),
                          trailing: const Icon(Icons.nightlight_round, color: Colors.indigo),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
