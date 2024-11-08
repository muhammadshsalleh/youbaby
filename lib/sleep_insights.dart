import 'dart:math' show max;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

enum TimePeriod { today, lastWeek, lastTwoWeeks, custom }

class SleepInsightsPage extends StatefulWidget {
  final int userID;
  const SleepInsightsPage({Key? key, required this.userID}) : super(key: key);
  @override
  _SleepInsightsPageState createState() => _SleepInsightsPageState();
}

class _SleepInsightsPageState extends State<SleepInsightsPage> {
  List<Map<String, dynamic>> _sleepData = [];
  bool _isLoading = true;
  Map<String, dynamic> _insights = {};
  TimePeriod _selectedPeriod = TimePeriod.today;
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  DateTime? _babyBirthday;
  int _babyAgeInMonths = 0;

  @override
  void initState() {
    super.initState();
    _fetchSleepData();
  }

  Future<void> _fetchUserData() async {
    final supabase = Supabase.instance.client;
    final response = await supabase
        .from('users')
        .select('babyBirthday')
        .eq('id', widget.userID)
        .single();

    if (response != null && response['babyBirthday'] != null) {
      setState(() {
        _babyBirthday = DateTime.parse(response['babyBirthday']);
        _babyAgeInMonths = _calculateAgeInMonths(_babyBirthday!);
      });
    }

    _fetchSleepData();
  }

  int _calculateAgeInMonths(DateTime birthDate) {
    DateTime now = DateTime.now();
    int months = (now.year - birthDate.year) * 12 + now.month - birthDate.month;
    if (now.day < birthDate.day) {
      months--;
    }
    return months;
  }

  Future<void> _fetchSleepData() async {
    final supabase = Supabase.instance.client;
    final response = await supabase
        .from('sleepTracker')
        .select()
        .eq('userID', widget.userID)
        .order('sleepStart', ascending: false)
        .limit(100);

    setState(() {
      _sleepData = List<Map<String, dynamic>>.from(response);
      _isLoading = false;
    });

    _analyzeData();
  }

  void _analyzeData() {
    List<Map<String, dynamic>> filteredData = _getFilteredData();
    print("Filtered data count: ${filteredData.length}");

    if (filteredData.isEmpty) {
      setState(() {
        _insights = {
          'averageDuration': 0.0,
          'mostCommonQuality': 'N/A',
          'longestSleepSession': 0.0,
          'qualityDistribution': {'Excellent': 0, 'Good': 0, 'Poor': 0},
          'mostCommonBedtime': 'N/A',
          'bedtimeDistribution': {},
          'estimatedSleepStart': null,
          'estimatedSleepEnd': null,
          'environmentDistribution': <String, int>{},
        };
      });
      return;
    }

    Map<String, int> qualityDistribution = {
      'Excellent': 0,
      'Good': 0,
      'Poor': 0
    };
    Map<DateTime, List<Map<String, dynamic>>> sleepByDay = {};
    double totalDuration = 0;
    double longestSleepSession = 0;
    List<DateTime> sleepStartTimes = [];
    List<DateTime> sleepEndTimes = [];
    Map<String, int> environmentDistribution = {};

    for (var sleep in filteredData) {
      DateTime? sleepStart = _parseDateTime(sleep['sleepStart']);
      if (sleepStart == null) continue;

      DateTime sleepDateOnly =
          DateTime(sleepStart.year, sleepStart.month, sleepStart.day);

      if (!sleepByDay.containsKey(sleepDateOnly)) {
        sleepByDay[sleepDateOnly] = [];
      }
      sleepByDay[sleepDateOnly]!.add(sleep);

      double duration = (sleep['duration'] as int).toDouble();
      totalDuration += duration;
      if (duration > longestSleepSession) longestSleepSession = duration;

      sleepStartTimes.add(sleepStart);
      sleepEndTimes.add(_parseDateTime(sleep['sleepEnd']) ??
          sleepStart.add(Duration(seconds: sleep['duration'])));

      String quality = sleep['quality'] ?? 'Poor';
      qualityDistribution[quality] = (qualityDistribution[quality] ?? 0) + 1;

      // Process environment data
      String environment = sleep['environment'] ?? 'Unknown';
      environmentDistribution[environment] =
          (environmentDistribution[environment] ?? 0) + 1;
    }

    String mostCommonQuality = qualityDistribution.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;

    // Calculate average duration per day
    double averageDuration = sleepByDay.values.map((daySleeps) {
          return daySleeps.fold<double>(
                  0, (sum, sleep) => sum + sleep['duration']) /
              3600;
        }).reduce((a, b) => a + b) /
        sleepByDay.length;

    // Calculate the most common bedtime
    Map<String, int> bedtimeDistribution =
        _calculateBedtimeDistribution(filteredData);
    String mostCommonBedtime = _getMostCommonBedtime(bedtimeDistribution);

    // Calculate estimated sleep time range
    sleepStartTimes.sort();
    sleepEndTimes.sort();
    DateTime estimatedSleepStart = _calculateEstimatedTime(sleepStartTimes);
    DateTime estimatedSleepEnd = _calculateEstimatedTime(sleepEndTimes);

    setState(() {
      _insights = {
        'averageDuration': averageDuration,
        'mostCommonQuality': mostCommonQuality,
        'longestSleepSession': longestSleepSession / 3600, // Convert to hours
        'qualityDistribution': qualityDistribution,
        'mostCommonBedtime': mostCommonBedtime,
        'bedtimeDistribution': bedtimeDistribution,
        'estimatedSleepStart': estimatedSleepStart,
        'estimatedSleepEnd': estimatedSleepEnd,
        'environmentDistribution': environmentDistribution,
      };
    });
  }

  DateTime _calculateEstimatedTime(List<DateTime> times) {
    if (times.isEmpty) return DateTime.now();
    times.sort();
    int middleIndex = times.length ~/ 2;
    return times[middleIndex];
  }

  String _formatTimeRange(DateTime? start, DateTime? end) {
    if (start == null || end == null) return 'N/A';
    return '${DateFormat.jm().format(start)} - ${DateFormat.jm().format(end)}';
  }

  DateTime? _parseDateTime(String? dateTimeString) {
    if (dateTimeString == null) return null;
    try {
      return DateTime.parse(dateTimeString);
    } catch (e) {
      print('Error parsing date: $dateTimeString');
      return null;
    }
  }

  Map<String, int> _calculateBedtimeDistribution(
      List<Map<String, dynamic>> data) {
    Map<String, int> distribution = {};
    for (var sleep in data) {
      DateTime? sleepStart = _parseDateTime(sleep['sleepStart']);
      if (sleepStart == null)
        continue; // Skip this entry if the date is invalid
      String bedtime = DateFormat('HH:mm').format(sleepStart);
      distribution[bedtime] = (distribution[bedtime] ?? 0) + 1;
    }
    return distribution;
  }

  String _getMostCommonBedtime(Map<String, int> bedtimeDistribution) {
    if (bedtimeDistribution.isEmpty) return 'N/A';

    var sortedEntries = bedtimeDistribution.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedEntries.first.key;
  }

  List<Map<String, dynamic>> _getFilteredData() {
    DateTime now = DateTime.now();
    switch (_selectedPeriod) {
      case TimePeriod.today:
        return _sleepData.where((sleep) {
          DateTime sleepDate = DateTime.parse(sleep['sleepStart']);
          return sleepDate.year == now.year &&
              sleepDate.month == now.month &&
              sleepDate.day == now.day;
        }).toList();
      case TimePeriod.lastWeek:
        DateTime weekAgo = now.subtract(const Duration(days: 7));
        return _sleepData.where((sleep) {
          return DateTime.parse(sleep['sleepStart']).isAfter(weekAgo);
        }).toList();
      case TimePeriod.lastTwoWeeks:
        DateTime twoWeeksAgo = now.subtract(const Duration(days: 14));
        return _sleepData.where((sleep) {
          return DateTime.parse(sleep['sleepStart']).isAfter(twoWeeksAgo);
        }).toList();
      case TimePeriod.custom:
        if (_customStartDate != null && _customEndDate != null) {
          return _sleepData.where((sleep) {
            DateTime sleepDate = DateTime.parse(sleep['sleepStart']);
            return sleepDate.isAfter(_customStartDate!) &&
                sleepDate
                    .isBefore(_customEndDate!.add(const Duration(days: 1)));
          }).toList();
        }
        return _sleepData;
    }
  }

  String _formatDuration(double hours) {
    if (hours == 0) return 'No data';
    int totalMinutes = (hours * 60).round();
    int displayHours = totalMinutes ~/ 60;
    int displayMinutes = totalMinutes % 60;
    return '$displayHours hr ${displayMinutes.toString().padLeft(2, '0')} min';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sleep Insights'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  _buildIntroduction(),
                  _buildScrollableTimePeriodSelector(),
                  _buildCustomDateRangePicker(),
                  _buildSummary(),
                  _buildSleepQualityChart(),
                  _buildKeyMetrics(),
                  _buildWeeklySleepSummary(),
                  _buildSleepConsistencyView(),
                  _buildSleepQualityDistribution(),
                  _buildSleepPatternInsights(),
                  _buildSleepRecommendations(),
                ],
              ),
            ),
    );
  }

  Widget _buildIntroduction() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: const Card(
        elevation: 4,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sleep Insights for Your Baby!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Here’s how your baby’s sleep has been recently:',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScrollableTimePeriodSelector() {
    return Container(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildTimePeriodButton(TimePeriod.today, 'Today'),
          _buildTimePeriodButton(TimePeriod.lastWeek, 'Last 7 Days'),
          _buildTimePeriodButton(TimePeriod.lastTwoWeeks, 'Last 14 Days'),
          _buildTimePeriodButton(TimePeriod.custom, 'Custom Range'),
        ],
      ),
    );
  }

  Widget _buildTimePeriodButton(TimePeriod period, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: ElevatedButton(
        onPressed: () {
          setState(() {
            _selectedPeriod = period;
          });
          _analyzeData();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor:
              _selectedPeriod == period ? Colors.blue : Colors.grey,
        ),
        child: Text(label),
      ),
    );
  }

  Widget _buildCustomDateRangePicker() {
    if (_selectedPeriod != TimePeriod.custom) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _customStartDate ?? DateTime.now(),
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  setState(() {
                    _customStartDate = picked;
                  });
                  _analyzeData();
                }
              },
              child: Text(_customStartDate == null
                  ? 'Start Date'
                  : DateFormat('MM/dd/yyyy').format(_customStartDate!)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _customEndDate ?? DateTime.now(),
                  firstDate: _customStartDate ??
                      DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  setState(() {
                    _customEndDate = picked;
                  });
                  _analyzeData();
                }
              },
              child: Text(_customEndDate == null
                  ? 'End Date'
                  : DateFormat('MM/dd/yyyy').format(_customEndDate!)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    if (_insights.isEmpty) {
      return const Card(
        margin: EdgeInsets.all(16),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No sleep data available for the selected period.'),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Summary (${_getTimePeriodLabel()})',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              'Average sleep: ${_formatDuration(_insights['averageDuration'] ?? 0)}',
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              'Most common sleep quality: ${_insights['mostCommonQuality'] ?? 'N/A'}',
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              'Most common bedtime: ${_insights['mostCommonBedtime'] ?? 'N/A'}',
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  String _getTimePeriodLabel() {
    switch (_selectedPeriod) {
      case TimePeriod.today:
        return 'Today';
      case TimePeriod.lastWeek:
        return 'Last 7 Days';
      case TimePeriod.lastTwoWeeks:
        return 'Last 14 Days';
      case TimePeriod.custom:
        return 'Custom Range';
    }
  }

  Widget _buildKeyMetrics() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildMetricCard('Average Sleep',
                _formatDuration(_insights['averageDuration'] ?? 0)),
            _buildMetricCard('Longest Sleep',
                _formatDuration(_insights['longestSleepSession'] ?? 0)),
            _buildMetricCard(
                'Quality', _insights['mostCommonQuality'] ?? 'N/A'),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String label, String value) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text(value,
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklySleepSummary() {
    Map<String, double> dailySummary = _calculateDailySummary();
    double minDailyTarget = 14.0;
    double maxDailyTarget = 17.0;

    double maxSleepHours = dailySummary.values.isNotEmpty
        ? dailySummary.values.reduce((a, b) => a > b ? a : b)
        : 0;

    // Setting yAxisMax to include a buffer and ensuring it is not less than the max daily target
    double yAxisMax =
        max(maxDailyTarget + 2, (maxSleepHours.ceil() / 2).ceilToDouble() * 2);
    double yAxisMin = 0.0; // Set to 0 to ensure data starts from 0 hrs

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sleep Summary (${_getTimePeriodLabel()})',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 350,
              child: dailySummary.isNotEmpty
                  ? Stack(
                      children: [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: _selectedPeriod == TimePeriod.lastTwoWeeks
                                ? 800
                                : 400,
                            child: BarChart(
                              BarChartData(
                                alignment: BarChartAlignment.spaceAround,
                                minY: yAxisMin, // Ensuring minY starts at 0
                                maxY:
                                    yAxisMax, // Adjusted maxY to match data range
                                barTouchData: BarTouchData(
                                  touchTooltipData: BarTouchTooltipData(
                                    getTooltipItem:
                                        (group, groupIndex, rod, rodIndex) {
                                      String date =
                                          _getChartLabels()[groupIndex];
                                      return BarTooltipItem(
                                        '$date\n${rod.toY.toStringAsFixed(1)} hrs',
                                        const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold),
                                      );
                                    },
                                  ),
                                ),
                                titlesData: FlTitlesData(
                                  show: true,
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (value, meta) {
                                        List<String> labels = _getChartLabels();
                                        if (value.toInt() < labels.length) {
                                          return Padding(
                                            padding:
                                                const EdgeInsets.only(top: 8.0),
                                            child: Text(
                                              labels[value.toInt()],
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 10),
                                              textAlign: TextAlign.center,
                                            ),
                                          );
                                        }
                                        return const SizedBox.shrink();
                                      },
                                      reservedSize: 20,
                                    ),
                                  ),
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (value, meta) {
                                        return Text(
                                          '${value.toInt()} hr',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 10),
                                        );
                                      },
                                      reservedSize: 30,
                                    ),
                                    axisNameWidget: const Text('Hours',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    axisNameSize: 20,
                                  ),
                                  topTitles: const AxisTitles(
                                      sideTitles:
                                          SideTitles(showTitles: false)),
                                  rightTitles: const AxisTitles(
                                      sideTitles:
                                          SideTitles(showTitles: false)),
                                ),
                                borderData: FlBorderData(show: false),
                                barGroups: dailySummary.entries.map((entry) {
                                  Color barColor =
                                      entry.value >= minDailyTarget &&
                                              entry.value <= maxDailyTarget
                                          ? Colors.green
                                          : Colors.blue;
                                  return BarChartGroupData(
                                    x: dailySummary.keys
                                        .toList()
                                        .indexOf(entry.key),
                                    barRods: [
                                      BarChartRodData(
                                        toY: entry
                                            .value, // Ensure this value correctly represents sleep hours
                                        color: barColor,
                                        width: _selectedPeriod ==
                                                TimePeriod.lastTwoWeeks
                                            ? 16
                                            : 20,
                                        borderRadius:
                                            const BorderRadius.vertical(
                                                top: Radius.circular(5)),
                                      ),
                                    ],
                                  );
                                }).toList(),
                                gridData: FlGridData(
                                  show: true,
                                  drawVerticalLine: false,
                                  horizontalInterval:
                                      2, // Adjusted interval to align with y-axis values
                                  getDrawingHorizontalLine: (value) {
                                    return FlLine(
                                      color: Colors.grey[300],
                                      strokeWidth: 1,
                                    );
                                  },
                                ),
                                extraLinesData: ExtraLinesData(
                                  horizontalLines: [
                                    HorizontalLine(
                                      y: minDailyTarget,
                                      color: Colors.red.withOpacity(0.8),
                                      strokeWidth: 2,
                                      dashArray: [5, 5],
                                      label: HorizontalLineLabel(
                                        show: true,
                                        alignment: Alignment.topRight,
                                        padding: const EdgeInsets.only(
                                            right: 5, bottom: -20),
                                        style: const TextStyle(
                                            color: Colors.red,
                                            fontWeight: FontWeight.bold),
                                        labelResolver: (line) =>
                                            'Min: ${minDailyTarget.toStringAsFixed(0)} hrs',
                                      ),
                                    ),
                                    HorizontalLine(
                                      y: maxDailyTarget,
                                      color: Colors.green.withOpacity(0.8),
                                      strokeWidth: 2,
                                      dashArray: [5, 5],
                                      label: HorizontalLineLabel(
                                        show: true,
                                        alignment: Alignment.bottomRight,
                                        padding: const EdgeInsets.only(
                                            right: 5, top: -20),
                                        style: const TextStyle(
                                            color: Colors.green,
                                            fontWeight: FontWeight.bold),
                                        labelResolver: (line) =>
                                            'Max: ${maxDailyTarget.toStringAsFixed(0)} hrs',
                                      ),
                                    ),
                                  ],
                                ),
                                backgroundColor: Colors.white,
                                groupsSpace: 40,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Center(
                      child: Text(
                          'No sleep data available for ${_getTimePeriodLabel()}')),
            ),
            const SizedBox(height: 16),
            Center(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  'Daily target: ${minDailyTarget.toStringAsFixed(0)}-${maxDailyTarget.toStringAsFixed(0)} hours',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            if (_selectedPeriod != TimePeriod.today)
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Text(
                    'Swipe left/right to view all data',
                    style: TextStyle(
                        fontStyle: FontStyle.italic, color: Colors.grey),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Map<String, double> _calculateDailySummary() {
    Map<String, double> summary = {};
    DateTime now = DateTime.now();
    DateTime startDate;
    DateTime endDate = now;

    switch (_selectedPeriod) {
      case TimePeriod.today:
        startDate = DateTime(now.year, now.month, now.day);
        break;
      case TimePeriod.lastWeek:
        startDate = now.subtract(const Duration(days: 6));
        break;
      case TimePeriod.lastTwoWeeks:
        startDate = now.subtract(const Duration(days: 13));
        break;
      case TimePeriod.custom:
        startDate = _customStartDate ?? now.subtract(const Duration(days: 7));
        endDate = _customEndDate ?? now;
        break;
    }

    for (var sleep in _sleepData) {
      DateTime sleepDate = DateTime.parse(sleep['sleepStart']);
      if (sleepDate.isAfter(startDate.subtract(const Duration(days: 1))) &&
          sleepDate.isBefore(endDate.add(const Duration(days: 1)))) {
        String key;
        switch (_selectedPeriod) {
          case TimePeriod.today:
            if (sleepDate.day == now.day &&
                sleepDate.month == now.month &&
                sleepDate.year == now.year) {
              key = 'Today';
            } else {
              continue; // Skip if not today
            }
            break;
          case TimePeriod.lastWeek:
            key = DateFormat('E').format(sleepDate);
            break;
          default:
            key = DateFormat('MM/dd').format(sleepDate);
        }
        double duration = sleep['duration'] / 3600; // Convert to hours
        summary[key] = (summary[key] ?? 0) + duration;
      }
    }

    return summary;
  }

  List<String> _getChartLabels() {
    switch (_selectedPeriod) {
      case TimePeriod.today:
        return ['Today'];
      case TimePeriod.lastWeek:
        return ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      case TimePeriod.lastTwoWeeks:
        return List.generate(14, (index) {
          DateTime date = DateTime.now().subtract(Duration(days: 13 - index));
          return DateFormat('MM/dd').format(date);
        });
      case TimePeriod.custom:
        if (_customStartDate != null && _customEndDate != null) {
          List<String> labels = [];
          for (DateTime date = _customStartDate!;
              date.isBefore(_customEndDate!.add(const Duration(days: 1)));
              date = date.add(const Duration(days: 1))) {
            labels.add(DateFormat('MM/dd').format(date));
          }
          return labels;
        }
        return ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    }
  }

  Widget _buildSleepConsistencyView() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sleep Consistency (${_getTimePeriodLabel()})',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(
                      label: Text('Date', style: TextStyle(fontSize: 14))),
                  DataColumn(
                      label:
                          Text('First Sleep', style: TextStyle(fontSize: 14))),
                  DataColumn(
                      label: Text('Last Wake', style: TextStyle(fontSize: 14))),
                  DataColumn(
                      label:
                          Text('Total Sleep', style: TextStyle(fontSize: 14))),
                  DataColumn(
                      label: Text('Quality', style: TextStyle(fontSize: 14))),
                ],
                rows: _getSelectedPeriodData().map((day) {
                  return DataRow(cells: [
                    DataCell(Text(day['date']!,
                        style: const TextStyle(fontSize: 12))),
                    DataCell(Text(day['firstSleep']!,
                        style: const TextStyle(fontSize: 12))),
                    DataCell(Text(day['lastWake']!,
                        style: const TextStyle(fontSize: 12))),
                    DataCell(Text(day['totalSleep']!,
                        style: const TextStyle(fontSize: 12))),
                    DataCell(Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                            day['quality'] == 'Good'
                                ? Icons.check
                                : Icons.close,
                            color: day['quality'] == 'Good'
                                ? Colors.green
                                : Colors.red),
                        const SizedBox(width: 4),
                        Text(day['quality']!,
                            style: const TextStyle(fontSize: 12)),
                      ],
                    )),
                  ]);
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Table Explanation:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('• First Sleep: Time when your baby first fell asleep'),
            const Text('• Last Wake: Time when your baby last woke up'),
            const Text('• Total Sleep: Total amount of sleep in 24 hours'),
            const Text('• Quality: Good (14+ hours) or Poor (<14 hours)'),
          ],
        ),
      ),
    );
  }

  List<Map<String, String>> _getSelectedPeriodData() {
    List<Map<String, String>> selectedPeriodData = [];
    DateTime now = DateTime.now();
    DateTime startDate;
    DateTime endDate;

    switch (_selectedPeriod) {
      case TimePeriod.today:
        startDate = DateTime(now.year, now.month, now.day);
        endDate = startDate;
        break;
      case TimePeriod.lastWeek:
        startDate = now.subtract(const Duration(days: 6));
        endDate = now;
        break;
      case TimePeriod.lastTwoWeeks:
        startDate = now.subtract(const Duration(days: 13));
        endDate = now;
        break;
      case TimePeriod.custom:
        startDate = _customStartDate ?? now.subtract(const Duration(days: 7));
        endDate = _customEndDate ?? now;
        break;
    }

    for (DateTime date = startDate;
        date.isBefore(endDate.add(const Duration(days: 1)));
        date = date.add(const Duration(days: 1))) {
      String dateStr = DateFormat('MM/dd').format(date);
      String firstSleep = '-';
      String lastWake = '-';
      double totalSleepHours = 0;

      List<Map<String, dynamic>> dayData = _sleepData.where((sleep) {
        DateTime sleepStart = DateTime.parse(sleep['sleepStart']);
        return sleepStart.year == date.year &&
            sleepStart.month == date.month &&
            sleepStart.day == date.day;
      }).toList();

      if (dayData.isNotEmpty) {
        dayData.sort((a, b) => DateTime.parse(a['sleepStart'])
            .compareTo(DateTime.parse(b['sleepStart'])));
        firstSleep = DateFormat('HH:mm')
            .format(DateTime.parse(dayData.first['sleepStart']));
        DateTime lastSleepEnd = DateTime.parse(dayData.last['sleepStart'])
            .add(Duration(seconds: dayData.last['duration']));
        lastWake = DateFormat('HH:mm').format(lastSleepEnd);
        totalSleepHours =
            dayData.fold(0, (sum, sleep) => sum + sleep['duration'] / 3600);
      }

      String quality = totalSleepHours >= 14
          ? 'Good'
          : totalSleepHours == 0
              ? 'N/A'
              : 'Poor';

      selectedPeriodData.add({
        'date': dateStr,
        'firstSleep': firstSleep,
        'lastWake': lastWake,
        'totalSleep': _formatDuration(totalSleepHours),
        'quality': quality,
      });
    }
    return selectedPeriodData;
  }

  Widget _buildSleepQualityDistribution() {
    Map<String, int> qualityDistribution =
        Map<String, int>.from(_insights['qualityDistribution'] ?? {});

    // Filter to include only Excellent, Good, and Poor
    Map<String, int> filteredDistribution = {
      'Excellent': qualityDistribution['Excellent'] ?? 0,
      'Good': qualityDistribution['Good'] ?? 0,
      'Poor': qualityDistribution['Poor'] ?? 0,
    };

    int totalSleepEpisodes =
        filteredDistribution.values.reduce((a, b) => a + b);

    // Calculate target naps based on baby's age
    int targetNaps = _calculateTargetNaps();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sleep Quality Distribution',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
                'Most common sleep quality: ${_getMostCommonQuality(filteredDistribution)}'),
            const SizedBox(height: 16),
            totalSleepEpisodes > 0
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: filteredDistribution.entries.map((entry) {
                      return Column(
                        children: [
                          Text(entry.key,
                              style: TextStyle(
                                  color: _getQualityColor(entry.key))),
                          Text('${entry.value}',
                              style: const TextStyle(
                                  fontSize: 24, fontWeight: FontWeight.bold)),
                          Text(
                              '${((entry.value / totalSleepEpisodes) * 100).toStringAsFixed(1)}%',
                              style: const TextStyle(fontSize: 14)),
                        ],
                      );
                    }).toList(),
                  )
                : const Text('No sleep data available'),
            const SizedBox(height: 16),
            Text('Total sleep episodes: $totalSleepEpisodes',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Excellent: 1-2 hours per nap',
                style: TextStyle(color: _getQualityColor('Excellent'))),
            Text('Good: 45 minutes - 1 hour per nap',
                style: TextStyle(color: _getQualityColor('Good'))),
            Text('Poor: Less than 45 minutes per nap',
                style: TextStyle(color: _getQualityColor('Poor'))),
            const SizedBox(height: 16),
            _buildTargetNapsInfo(targetNaps, totalSleepEpisodes),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetNapsInfo(int targetNaps, int actualNaps) {
    int daysInPeriod = _getDaysInSelectedPeriod();
    int totalTargetNaps = targetNaps * daysInPeriod;
    double targetSleepHours = _calculateTargetSleepHours();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Target naps for $daysInPeriod day(s): $totalTargetNaps',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
            'Target sleep hours per day: ${targetSleepHours.toStringAsFixed(1)} hours',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: actualNaps / totalTargetNaps,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(
              _getProgressColor(actualNaps, totalTargetNaps)),
        ),
        const SizedBox(height: 8),
        Text(
          _getNapProgressMessage(actualNaps, totalTargetNaps, targetSleepHours),
          style: const TextStyle(fontStyle: FontStyle.italic),
        ),
      ],
    );
  }

  int _getDaysInSelectedPeriod() {
    switch (_selectedPeriod) {
      case TimePeriod.today:
        return 1;
      case TimePeriod.lastWeek:
        return 7;
      case TimePeriod.lastTwoWeeks:
        return 14;
      case TimePeriod.custom:
        if (_customStartDate != null && _customEndDate != null) {
          return _customEndDate!.difference(_customStartDate!).inDays + 1;
        }
        return 7; // Default to a week if custom dates are not set
    }
  }

  int _calculateTargetNaps() {
    if (_babyAgeInMonths <= 3) {
      return 4; // Newborns (0-3 months)
    } else if (_babyAgeInMonths <= 6) {
      return 3; // Infants (4-6 months)
    } else if (_babyAgeInMonths <= 12) {
      return 2; // Babies (6-12 months)
    } else {
      return 1; // Toddlers (1-2 years)
    }
  }

  double _calculateTargetSleepHours() {
    if (_babyAgeInMonths <= 3) {
      return 15.5; // Newborns (0-3 months): 14-17 hours, average 15.5
    } else if (_babyAgeInMonths <= 6) {
      return 13.5; // Infants (4-6 months): 12-15 hours, average 13.5
    } else if (_babyAgeInMonths <= 12) {
      return 13; // Babies (6-12 months): 12-14 hours, average 13
    } else {
      return 12.5; // Toddlers (1-2 years): 11-14 hours, average 12.5
    }
  }

  Color _getProgressColor(int actual, int target) {
    if (actual >= target) return Colors.green;
    if (actual >= target * 0.7) return Colors.amber;
    return Colors.red;
  }

  String _getNapProgressMessage(
      int actual, int target, double targetSleepHours) {
    if (actual >= target) {
      return "Great job! Your baby is getting enough naps. Keep aiming for ${targetSleepHours.toStringAsFixed(1)} hours of sleep per day.";
    } else if (actual >= target * 0.7) {
      return "Almost there! Try to fit in ${target - actual} more nap(s) if possible. Remember, the goal is ${targetSleepHours.toStringAsFixed(1)} hours of total sleep per day.";
    } else {
      return "Your baby might need more naps. Aim for $target naps in total and ${targetSleepHours.toStringAsFixed(1)} hours of sleep per day.";
    }
  }

  String _getMostCommonQuality(Map<String, int> qualityDistribution) {
    if (qualityDistribution.isEmpty) return 'N/A';
    return qualityDistribution.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  Widget _buildSleepPatternInsights() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sleep Pattern Insights',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildInsightItem(
              icon: Icons.access_time,
              text:
                  'Estimated sleep time: ${_formatTimeRange(_insights['estimatedSleepStart'], _insights['estimatedSleepEnd'])}',
            ),
            _buildInsightItem(
              icon: Icons.brightness_3,
              text:
                  'Your baby tends to fall asleep around ${DateFormat.jm().format(_insights['estimatedSleepStart'] ?? DateTime.now())}.',
            ),
            _buildInsightItem(
              icon: Icons.wb_sunny,
              text:
                  'Your baby typically wakes up around ${DateFormat.jm().format(_insights['estimatedSleepEnd'] ?? DateTime.now())}.',
            ),
            _buildInsightItem(
              icon: Icons.repeat,
              text:
                  'Consistent sleep schedules tend to result in better sleep quality.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightItem({required IconData icon, required String text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue),
          const SizedBox(width: 16),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Widget _buildSleepRecommendations() {
    Map<String, Map<String, dynamic>> ageRecommendations = {
      'Newborns (0-3 months)': {
        'totalSleep': '14-17 hours',
        'description':
            'Spread across both daytime naps and nighttime sleep. Sleep is typically broken into shorter periods due to frequent feedings and irregular patterns.',
      },
      'Infants (4-6 months)': {
        'totalSleep': '12-15 hours',
        'description':
            'Usually includes 2-3 naps during the day and longer stretches of sleep at night.',
      },
      'Babies (6-12 months)': {
        'totalSleep': '12-14 hours',
        'description':
            'By this age, babies often sleep 10-12 hours at night with 1-2 naps during the day.',
      },
      'Toddlers (1-2 years)': {
        'totalSleep': '11-14 hours',
        'description':
            'Toddlers typically sleep through the night with one nap during the day.',
      },
    };

    String ageGroup;
    if (_babyAgeInMonths <= 3) {
      ageGroup = 'Newborns (0-3 months)';
    } else if (_babyAgeInMonths <= 6) {
      ageGroup = 'Infants (4-6 months)';
    } else if (_babyAgeInMonths <= 12) {
      ageGroup = 'Babies (6-12 months)';
    } else {
      ageGroup = 'Toddlers (1-2 years)';
    }

    Map<String, dynamic> currentRecommendation = ageRecommendations[ageGroup]!;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sleep Recommendations',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Text('Age group: $ageGroup',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
                'Recommended total sleep: ${currentRecommendation['totalSleep']} per day'),
            const SizedBox(height: 8),
            Text(currentRecommendation['description']),
            const SizedBox(height: 16),
            const Text('Tips for Better Sleep:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ..._generateRecommendations()
                .map((rec) => _buildRecommendationItem(rec)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationItem(Map<String, dynamic> recommendation) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            recommendation['isImplemented']
                ? Icons.check_circle
                : Icons.bubble_chart_rounded,
            color: recommendation['isImplemented']
                ? Colors.green
                : Colors.lightBlue,
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(recommendation['text'])),
        ],
      ),
    );
  }

  Widget _buildSleepQualityChart() {
    Map<String, int> qualityDistribution = _insights['qualityDistribution'] ??
        {'Excellent': 0, 'Good': 0, 'Poor': 0};
    int totalSleepEpisodes = qualityDistribution.values.reduce((a, b) => a + b);

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sleep Quality Distribution (${_getTimePeriodLabel()})',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                SizedBox(
                  height: 150,
                  width: 150,
                  child: totalSleepEpisodes > 0
                      ? PieChart(
                          PieChartData(
                            sections: _getSleepQualitySections(
                                qualityDistribution, totalSleepEpisodes),
                            sectionsSpace: 0,
                            centerSpaceRadius: 30,
                            startDegreeOffset: 180,
                          ),
                        )
                      : const Center(child: Text('No data available')),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children:
                        _buildLegend(qualityDistribution, totalSleepEpisodes),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<PieChartSectionData> _getSleepQualitySections(
      Map<String, int> qualityDistribution, int totalSleepEpisodes) {
    return qualityDistribution.entries.map((entry) {
      final percentage = entry.value / totalSleepEpisodes;
      return PieChartSectionData(
        color: _getQualityColor(entry.key),
        value: percentage * 100,
        title: '${(percentage * 100).toStringAsFixed(1)}%',
        radius: 60,
        titleStyle: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();
  }

  List<Widget> _buildLegend(
      Map<String, int> qualityDistribution, int totalSleepEpisodes) {
    return qualityDistribution.entries.map((entry) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: _getQualityColor(entry.key),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${entry.key}: ${entry.value} (${(entry.value / totalSleepEpisodes * 100).toStringAsFixed(1)}%)',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  List<Map<String, dynamic>> _generateRecommendations() {
    List<Map<String, dynamic>> recommendations = [];
    Map<String, int> qualityDistribution =
        Map<String, int>.from(_insights['qualityDistribution'] ?? {});
    Map<String, int> environmentDistribution =
        Map<String, int>.from(_insights['environmentDistribution'] ?? {});

    int totalNaps = qualityDistribution.values.reduce((a, b) => a + b);
    if (totalNaps == 0) return recommendations;

    double excellentPercentage =
        (qualityDistribution['Excellent'] ?? 0) / totalNaps * 100;
    double poorPercentage =
        (qualityDistribution['Poor'] ?? 0) / totalNaps * 100;

    // Sleep quality recommendations
    if (excellentPercentage >= 50) {
      recommendations.add({
        'text':
            'Great job! You\'re achieving excellent sleep quality. Keep maintaining your current sleep routine.',
        'isImplemented': true
      });
    } else {
      recommendations.add({
        'text':
            'Aim for more naps in the 1-2 hour range for optimal sleep quality.',
        'isImplemented': false
      });
    }

    if (poorPercentage > 30) {
      recommendations.add({
        'text':
            'Try to extend short naps by creating a more conducive sleep environment.',
        'isImplemented': false
      });
    }

    recommendations.add({
      'text':
          'Maintain a consistent nap schedule to help regulate your baby\'s sleep patterns.',
      'isImplemented': true
    });

    // Environment recommendations
    double darkPercentage = (environmentDistribution['dark'] ?? 0) / totalNaps;
    double quietPercentage =
        (environmentDistribution['quiet'] ?? 0) / totalNaps;
    double whiteNoisePercentage =
        (environmentDistribution['white noise'] ?? 0) / totalNaps;
    double coolPercentage = (environmentDistribution['cool'] ?? 0) / totalNaps;

    recommendations.add({
      'text': darkPercentage >= 0.7
          ? 'You\'re doing great with keeping the room dark. This helps promote better sleep.'
          : 'Try to ensure the room is darker during naps for better sleep quality.',
      'isImplemented': darkPercentage >= 0.7
    });

    recommendations.add({
      'text': quietPercentage >= 0.7 || whiteNoisePercentage >= 0.7
          ? 'You\'re maintaining a good sound environment. Keep it up!'
          : 'Consider using white noise or ensuring a quieter environment for naps.',
      'isImplemented': quietPercentage >= 0.7 || whiteNoisePercentage >= 0.7
    });

    recommendations.add({
      'text': coolPercentage >= 0.7
          ? 'The room temperature seems comfortable. This is great for your baby\'s sleep.'
          : 'Try to keep the room at a comfortable temperature (68-72°F or 20-22°C) for naps.',
      'isImplemented': coolPercentage >= 0.7
    });

    return recommendations;
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
}
