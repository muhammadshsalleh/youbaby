import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class FeedingHistoryPage extends StatefulWidget {
  final int userId;

  const FeedingHistoryPage({Key? key, required this.userId}) : super(key: key);

  @override
  _FeedingHistoryPageState createState() => _FeedingHistoryPageState();
}

class _FeedingHistoryPageState extends State<FeedingHistoryPage> {
  List<FeedingSession> feedingSessions = [];
  List<FeedingSession> filteredFeedingSessions = [];
  TimeRange selectedTimeRange = TimeRange.today;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFeedingSessions();
  }

  Future<void> _loadFeedingSessions() async {
  setState(() {
    isLoading = true;
  });

  final supabase = Supabase.instance.client;

  try {
    final response = await supabase
        .from('feedingTracker')
        .select()
        .eq('userID', widget.userId)
        .order('startTime', ascending: false);

    if (response != null && response is List) {
      Map<String, FeedingSession> sessionMap = {};

      for (var record in response) {
        String sessionKey = DateFormat('yyyyMMddHHmm').format(DateTime.parse(record['startTime']));
        
        if (!sessionMap.containsKey(sessionKey)) {
          // Determine the feeding type based on the record data
          FeedingType feedingType;
            if (record['feedingType'] == 'Breast') {
              feedingType = FeedingType.Breast;
            } else if (record['feedingType'] == 'Bottle') {
              feedingType = FeedingType.Bottle;
            } else if (record['feedingType'] == 'Pumping') {
              feedingType = FeedingType.Pumping;
            } else {
              feedingType = FeedingType.Breast; // Default to Breast if unknown
            }

            sessionMap[sessionKey] = FeedingSession(
              id: sessionKey,
              dateTime: DateTime.parse(record['startTime']),
              totalTime: 0,
              leftBreastDuration: 0,
              rightBreastDuration: 0,
              feedingType: feedingType,
            );
        }

        FeedingSession session = sessionMap[sessionKey]!;
        session.totalTime += record['duration'] as int;
        
        if (record['breastSide'] == 'Left') {
          session.leftBreastDuration += record['duration'] as int;
        } else if (record['breastSide'] == 'Right') {
          session.rightBreastDuration += record['duration'] as int;
        }
      }

      setState(() {
        feedingSessions = sessionMap.values.toList()
          ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
        _filterFeedingSessions();
        isLoading = false;
      });
    } else {
      setState(() {
        feedingSessions = [];
        filteredFeedingSessions = [];
        isLoading = false;
      });
    }
  } catch (e) {
    print('Error fetching records: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error loading feeding records: $e')),
    );
    setState(() {
      isLoading = false;
    });
  }
}

  void _filterFeedingSessions() {
    DateTime now = DateTime.now();
    DateTime startDate;
    DateTime endDate = now;

    switch (selectedTimeRange) {
      case TimeRange.today:
        startDate = DateTime(now.year, now.month, now.day);
        break;
      case TimeRange.yesterday:
        startDate = DateTime(now.year, now.month, now.day - 1);
        endDate = DateTime(now.year, now.month, now.day).subtract(const Duration(seconds: 1));
        break;
      case TimeRange.last7Days:
        startDate = now.subtract(const Duration(days: 7));
        break;
      case TimeRange.last14Days:
        startDate = now.subtract(const Duration(days: 14));
        break;
    }

    setState(() {
      filteredFeedingSessions = feedingSessions
          .where((session) => session.dateTime.isAfter(startDate) && session.dateTime.isBefore(endDate.add(const Duration(seconds: 1))))
          .toList();
    });
  }

 @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feeding History'),
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
        child: Column(
          children: [
              SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: _buildTimeRangeButtons(),
            ),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredFeedingSessions.isEmpty
                      ? Center(
                          child: Text(
                            'No feeding records for the selected time range',
                            style: TextStyle(fontSize: 16, color: Colors.grey[800]),
                          ),
                        )
                      : _buildFeedingSessionsList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeRangeButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          _buildTimeRangeButton(TimeRange.today, 'Today'),
          _buildTimeRangeButton(TimeRange.yesterday, 'Yesterday'),
          _buildTimeRangeButton(TimeRange.last7Days, 'Last 7 Days'),
          _buildTimeRangeButton(TimeRange.last14Days, 'Last 14 Days'),
        ],
      ),
    );
  }

   Widget _buildTimeRangeButton(TimeRange range, String label) {
    return ElevatedButton(
      onPressed: () {
        setState(() {
          selectedTimeRange = range;
          _filterFeedingSessions();
        });
      },
      style: ElevatedButton.styleFrom(
        foregroundColor: selectedTimeRange == range ? Colors.white : Colors.pink[800],
        backgroundColor: selectedTimeRange == range ? Colors.pink[800] : Colors.pink[100],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      child: Text(label, style: const TextStyle(fontSize: 14)),
    );
  }

  Widget _buildFeedingSessionsList() {
    return ListView.builder(
      itemCount: filteredFeedingSessions.length,
      itemBuilder: (context, index) {
        final session = filteredFeedingSessions[index];
        return Dismissible(
          key: Key(session.id),
          background: _buildDismissibleBackground(
            alignment: Alignment.centerLeft,
            color: Colors.red,
            icon: Icons.delete,
          ),
          secondaryBackground: _buildDismissibleBackground(
            alignment: Alignment.centerRight,
            color: Colors.blue,
            icon: Icons.edit,
          ),
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.startToEnd) {
              return await _showDeleteConfirmationDialog(session);
            } else if (direction == DismissDirection.endToStart) {
              await _showUpdateDialog(session);
              return false;
            }
            return false;
          },
          onDismissed: (direction) {
            if (direction == DismissDirection.startToEnd) {
              _deleteSession(session);
            }
          },
          child: _buildFeedingSessionCard(session),
        );
      },
    );
  }

  Widget _buildDismissibleBackground({
    required AlignmentGeometry alignment,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      color: color,
      child: Align(
        alignment: alignment,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }

 Widget _buildFeedingSessionCard(FeedingSession session) {
  IconData mainIcon;
  Color mainIconColor;

  // Determine main icon (feeding type)
  switch (session.feedingType) {
    case FeedingType.Breast:
      mainIcon = Icons.child_care;
      mainIconColor = Colors.pink;
      break;
    case FeedingType.Bottle:
      mainIcon = Icons.baby_changing_station;
      mainIconColor = Colors.blue;
      break;
    case FeedingType.Pumping:
      mainIcon = Icons.water_drop;
      mainIconColor = Colors.purple;
      break;
    default:
      mainIcon = Icons.help_outline;
      mainIconColor = Colors.grey;
  }

  return Card(
    margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(15),
    ),
    elevation: 4,
    child: InkWell(
      onTap: () => _showFeedingDetails(session),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(mainIcon, size: 40, color: mainIconColor),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatDateTime(session.dateTime),
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Type: ${session.feedingType.toString().split('.').last}',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.pink[800]),
                      ),
                      Text(
                        _formatDuration(Duration(seconds: session.totalTime)),
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue[800]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}


  void _showFeedingDetails(FeedingSession session) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Feeding Details', style: TextStyle(color: Colors.pink[800])),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Date: ${_formatDateTime(session.dateTime)}'),
            const SizedBox(height: 8),
            Text('Total Time: ${_formatDuration(Duration(seconds: session.totalTime))}', 
                 style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Left Breast: ${_formatDuration(Duration(seconds: session.leftBreastDuration))}'),
            Text('Right Breast: ${_formatDuration(Duration(seconds: session.rightBreastDuration))}'),
          ],
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            child: Text('Close', style: TextStyle(color: Colors.pink[800])),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Future<bool> _showDeleteConfirmationDialog(FeedingSession session) async {
    return await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text("Confirm Deletion"),
              content: const Text(
                  "Are you sure you want to delete this feeding session?"),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text("Cancel"),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text("Delete"),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Future<void> _showUpdateDialog(FeedingSession session) async {
    int leftDuration = session.leftBreastDuration;
    int rightDuration = session.rightBreastDuration;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Feeding Session'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              initialValue: leftDuration.toString(),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                leftDuration = int.tryParse(value) ?? leftDuration;
              },
              decoration: const InputDecoration(labelText: 'Left Breast Duration (seconds)'),
            ),
            TextFormField(
              initialValue: rightDuration.toString(),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                rightDuration = int.tryParse(value) ?? rightDuration;
              },
              decoration: const InputDecoration(labelText: 'Right Breast Duration (seconds)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: const Text('Update'),
            onPressed: () async {
              await _updateFeedingSession(session, leftDuration, rightDuration);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSession(FeedingSession session) async {
    setState(() {
      feedingSessions.removeWhere((s) => s.id == session.id);
      filteredFeedingSessions.removeWhere((s) => s.id == session.id);
    });
    await _deleteFeedingSessionFromSupabase(session.id);
  }

  Future<void> _deleteFeedingSessionFromSupabase(String id) async {
    final supabase = Supabase.instance.client;
    try {
      await supabase.from('feedingTracker').delete().eq('id', id);
    } catch (e) {
      print('Error deleting session: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting feeding session: $e')),
      );
    }
  }

  Future<void> _updateFeedingSession(
      FeedingSession session, int leftDuration, int rightDuration) async {
    final supabase = Supabase.instance.client;
    try {
      await supabase.from('feedingTracker').update({
        'leftBreastDuration': leftDuration,
        'rightBreastDuration': rightDuration,
        'totalTime': leftDuration + rightDuration,
      }).eq('id', session.id);

      setState(() {
        session.leftBreastDuration = leftDuration;
        session.rightBreastDuration = rightDuration;
        session.totalTime = leftDuration + rightDuration;
        _filterFeedingSessions();
      });
    } catch (e) {
      print('Error updating session: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating feeding session: $e')),
      );
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('dd/MM/yyyy hh:mm a').format(dateTime);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }
}

enum TimeRange { today, yesterday, last7Days, last14Days }
enum FeedingType { Breast, Bottle, Pumping }

class FeedingSession {
  String id;
  DateTime dateTime;
  int totalTime;
  int leftBreastDuration;
  int rightBreastDuration;
  FeedingType feedingType;

  FeedingSession({
    required this.id,
    required this.dateTime,
    required this.totalTime,
    required this.leftBreastDuration,
    required this.rightBreastDuration,
    required this.feedingType,
  });
}
