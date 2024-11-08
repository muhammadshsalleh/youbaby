import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:youbaby/directFeedInsights.dart';
import 'package:youbaby/pumpingInsightsPage.dart';

class FeedingOverviewInsightsPage extends StatefulWidget {
  final int userID;
  const FeedingOverviewInsightsPage({Key? key, required this.userID})
      : super(key: key);

  @override
  _FeedingOverviewInsightsPageState createState() =>
      _FeedingOverviewInsightsPageState();
}

class _FeedingOverviewInsightsPageState
    extends State<FeedingOverviewInsightsPage>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _feedingData = [];
  bool _isLoading = true;
  Map<String, dynamic> _insights = {};
  TimePeriod _selectedPeriod = TimePeriod.today;
  DateTime? _babyBirthday;
  int _babyAgeInMonths = 0;
  late TabController _tabController;

  int _breastfeedings = 0;
  int _bottleFeedings = 0;
  int _pumpingSessions = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchUserData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserData() async {
    try {
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

      await _fetchFeedingData();
    } catch (e) {
      print('Error fetching user data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  int _calculateAgeInMonths(DateTime birthDate) {
    DateTime now = DateTime.now();
    int months = (now.year - birthDate.year) * 12 + now.month - birthDate.month;
    if (now.day < birthDate.day) {
      months--;
    }
    return months;
  }

  Future<void> _fetchFeedingData() async {
    try {
      setState(() => _isLoading = true);

      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('feedingTracker')
          .select()
          .eq('userID', widget.userID)
          .order('startTime', ascending: false)
          .limit(500);

      setState(() {
        _feedingData = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });

      _analyzeData();
    } catch (e) {
      print('Error fetching feeding data: $e');
      setState(() {
        _isLoading = false;
        // Optionally show an error message to the user
      });
    }
  }

  void _analyzeData() {
    List<Map<String, dynamic>> filteredData = _getFilteredData();

    if (filteredData.isEmpty) {
      setState(() {
        _insights = {
          'totalFeedings': 0,
          'feedingsPerDay': 0.0,
          'typeDistribution': {'Breast': 0, 'Bottle': 0, 'Pumping': 0},
          'mostCommonType': 'N/A',
          'averageDuration': Duration.zero,
          'totalVolume': 0,
          'favoriteBreast': 'N/A',
          'averageBottleVolume': 0.0,
          'mostProductiveTime': 'N/A',
          'longestStretchBetweenFeedings': Duration.zero,
          'averageTimeBetweenFeedings': Duration.zero,
          'feedingIntervals': <Duration>[],
          'dailyFeedingTrend': [],
          'volumeTrend': [],
        };
      });
      return;
    }

    Map<String, int> typeCount = {'Breast': 0, 'Bottle': 0, 'Pumping': 0};
    Duration totalDuration = Duration.zero;
    int totalVolume = 0;
    Map<String, int> breastCount = {'Left': 0, 'Right': 0};
    List<int> bottleVolumes = [];
    Map<String, int> timeOfDayCount = {
      'Morning': 0,
      'Afternoon': 0,
      'Evening': 0,
      'Night': 0
    };

    List<Duration> feedingIntervals = [];
    DateTime? lastFeedingTime;

    _breastfeedings = 0;
    _bottleFeedings = 0;
    _pumpingSessions = 0;

    for (var feeding in filteredData) {
      String feedingType = feeding['feedingType'] ?? 'Unknown';
      typeCount[feedingType] = (typeCount[feedingType] ?? 0) + 1;

      DateTime startTime = DateTime.parse(feeding['startTime']);
      DateTime endTime = DateTime.parse(feeding['endTime']);
      Duration feedingDuration = endTime.difference(startTime);
      totalDuration += feedingDuration;

      if (feedingType == 'Bottle') {
        _bottleFeedings++;
        double quantity = (feeding['quantity'] as num?)?.toDouble() ?? 0;
        totalVolume += quantity.toInt();
        bottleVolumes.add(quantity.toInt());
      } else if (feedingType == 'Breast') {
        _breastfeedings++;
        String breast = feeding['breastSide'] ?? 'Unknown';
        breastCount[breast] = (breastCount[breast] ?? 0) + 1;
      } else if (feedingType == 'Pumping') {
        _pumpingSessions++;
        double quantity = (feeding['quantity'] as num?)?.toDouble() ?? 0;
        totalVolume += quantity.toInt();
      }

      String timeOfDay = _getTimeOfDay(startTime);
      timeOfDayCount[timeOfDay] = (timeOfDayCount[timeOfDay] ?? 0) + 1;

      if (lastFeedingTime != null && feedingType != 'Pumping') {
        Duration interval = startTime.difference(lastFeedingTime!);
        feedingIntervals.add(interval);
      }
      if (feedingType != 'Pumping') {
        lastFeedingTime = startTime;
      }
    }

    Map<String, int> dailyFeedingCount = {};
    Map<String, int> dailyVolume = {};

    for (var feeding in filteredData) {
      DateTime feedingDate = DateTime.parse(feeding['startTime']).toLocal();
      String dateKey = DateFormat('yyyy-MM-dd').format(feedingDate);

      if (feeding['feedingType'] != 'Pumping') {
        dailyFeedingCount[dateKey] = (dailyFeedingCount[dateKey] ?? 0) + 1;
      }

      if (feeding['feedingType'] == 'Bottle' ||
          feeding['feedingType'] == 'Pumping') {
        double quantity = (feeding['quantity'] as num?)?.toDouble() ?? 0;
        dailyVolume[dateKey] = (dailyVolume[dateKey] ?? 0) + quantity.toInt();
      }
    }

    List<Map<String, dynamic>> dailyFeedingTrend = dailyFeedingCount.entries
        .map((entry) => {
              'date': entry.key,
              'count': entry.value,
            })
        .toList()
      ..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));

    List<MapEntry<String, int>> sortedDailyVolume = dailyVolume.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    String mostCommonType =
        typeCount.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    String favoriteBreast =
        breastCount.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    String mostProductiveTime =
        timeOfDayCount.entries.reduce((a, b) => a.value > b.value ? a : b).key;

    double daysInPeriod = _getDaysInPeriod();
    double feedingsPerDay = _breastfeedings / daysInPeriod;
    double averageBottleVolume = bottleVolumes.isNotEmpty
        ? bottleVolumes.reduce((a, b) => a + b) / bottleVolumes.length
        : 0;

    Duration longestStretch = feedingIntervals.isNotEmpty
        ? feedingIntervals.reduce((a, b) => a > b ? a : b)
        : Duration.zero;
    Duration averageInterval = feedingIntervals.isNotEmpty
        ? Duration(
            minutes: feedingIntervals.fold<int>(
                    0, (sum, duration) => sum + duration.inMinutes) ~/
                feedingIntervals.length)
        : Duration.zero;

    Duration averageDuration = _breastfeedings > 0
        ? Duration(minutes: totalDuration.inMinutes ~/ _breastfeedings)
        : Duration.zero;

    setState(() {
      _insights = {
        'totalFeedings': _breastfeedings,
        'feedingsPerDay': feedingsPerDay,
        'typeDistribution': typeCount,
        'mostCommonType': mostCommonType,
        'averageDuration': averageDuration,
        'totalVolume': totalVolume,
        'favoriteBreast': favoriteBreast,
        'averageBottleVolume': averageBottleVolume,
        'mostProductiveTime': mostProductiveTime,
        'longestStretchBetweenFeedings': longestStretch,
        'averageTimeBetweenFeedings': averageInterval,
        'feedingIntervals': feedingIntervals,
        'dailyFeedingTrend': dailyFeedingTrend,
        'volumeTrend': sortedDailyVolume,
      };
    });
  }

  List<Map<String, dynamic>> _getFilteredData() {
    DateTime now = DateTime.now();
    DateTime periodStart;

    switch (_selectedPeriod) {
      case TimePeriod.today:
        periodStart = DateTime(now.year, now.month, now.day);
        break;
      case TimePeriod.lastWeek:
        periodStart = now.subtract(const Duration(days: 7));
        break;
      case TimePeriod.lastTwoWeeks:
        periodStart = now.subtract(const Duration(days: 14));
        break;
      case TimePeriod.lastMonth:
        periodStart = DateTime(now.year, now.month - 1, now.day);
        break;
    }

    return _feedingData.where((feeding) {
      return DateTime.parse(feeding['startTime']).isAfter(periodStart);
    }).toList();
  }

  double _getDaysInPeriod() {
    switch (_selectedPeriod) {
      case TimePeriod.today:
        return 1;
      case TimePeriod.lastWeek:
        return 7;
      case TimePeriod.lastTwoWeeks:
        return 14;
      case TimePeriod.lastMonth:
        return 30;
    }
  }

  String _getTimeOfDay(DateTime time) {
    int hour = time.hour;
    if (hour >= 5 && hour < 12) return 'Morning';
    if (hour >= 12 && hour < 17) return 'Afternoon';
    if (hour >= 17 && hour < 21) return 'Evening';
    return 'Night';
  }

   @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Feeding Insights'),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Overview'),
              Tab(text: 'Direct Feeding'),
              Tab(text: 'Pumping'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildOverviewTab(),
            DirectFeedingInsightsPage(
                userId: widget.userID, babyAgeInMonths: _babyAgeInMonths),
            PumpingInsightsPage(
                userId: widget.userID, babyAgeInMonths: _babyAgeInMonths),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTimePeriodSelector(),
          _buildOverviewCard(),
          _buildFeedingTypeDistribution(),
          _buildDailyFeedingTrendChart(),
          _buildVolumeTrendChart(),
          _buildRecommendations(),
        ],
      ),
    );
  }

  Widget _buildTimePeriodSelector() {
    return Container(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildTimePeriodButton(TimePeriod.today, 'Today'),
          _buildTimePeriodButton(TimePeriod.lastWeek, 'Last 7 Days'),
          _buildTimePeriodButton(TimePeriod.lastTwoWeeks, 'Last 14 Days'),
          _buildTimePeriodButton(TimePeriod.lastMonth, 'Last Month'),
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

  Widget _buildOverviewCard() {
    if (_feedingData.isEmpty) {
      return Card(
        margin: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Feeding Overview for Your ${_babyAgeInMonths}-Month-Old',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text('No feeding data available yet. Start tracking to see insights!'),
            ],
          ),
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
              'Feeding Overview for Your ${_babyAgeInMonths}-Month-Old',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text('Total Feedings: ${_insights['totalFeedings']}'),
            Text(
                'Average Feedings per Day: ${(_insights['feedingsPerDay'] as double).toStringAsFixed(1)}'),
            Text('Most Common Feeding Type: ${_insights['mostCommonType']}'),
            Text(
                'Average Duration: ${(_insights['averageDuration'] as Duration).inMinutes} minutes'),
            Text('Breastfeedings: $_breastfeedings'),
            Text('Bottle Feedings: $_bottleFeedings'),
            Text('Pumping Sessions: $_pumpingSessions'),
          ],
        ),
      ),
    );
  }

Widget _buildFeedingTypeDistribution() {
    final typeDistribution = _insights['typeDistribution'] as Map<String, int>? ?? {};
    if (typeDistribution.isEmpty) {
      return _buildNoDataMessage('Not enough feeding type data available');
    }

    final total = typeDistribution.values.reduce((a, b) => a + b);
    final feedingTypes = ['Breast', 'Bottle', 'Pumping'];
    final colors = [Colors.blue, Colors.green, Colors.orange];

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Feeding Type Distribution',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: total == 0
                      ? Center(child: Text('Not enough data', style: TextStyle(fontSize: 16, color: Colors.grey[600])))
                      : SizedBox(
                          width: 150,
                          height: 200,
                          child: PieChart(
                            PieChartData(
                              sections: feedingTypes.map((type) {
                                final index = feedingTypes.indexOf(type);
                                final value = typeDistribution[type] ?? 0;
                                return PieChartSectionData(
                                  color: colors[index],
                                  value: value.toDouble(),
                                  title: '',
                                  radius: 50,
                                  titleStyle: const TextStyle(fontSize: 0),
                                );
                              }).toList(),
                              sectionsSpace: 0,
                              centerSpaceRadius: 30,
                              startDegreeOffset: 180,
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  flex: 1,
                  child: total == 0
                      ? Container()
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: feedingTypes.map((type) {
                            final index = feedingTypes.indexOf(type);
                            final value = typeDistribution[type] ?? 0;
                            final percentage = total > 0 ? (value / total * 100) : 0;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    color: colors[index],
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '$type: ${percentage.toStringAsFixed(1)}% ($value)',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyFeedingTrendChart() {
    List<Map<String, dynamic>> dailyFeedingTrend =
        ((_insights['dailyFeedingTrend'] as List<dynamic>?) ?? [])
            .map((item) => item as Map<String, dynamic>)
            .toList();
    if (dailyFeedingTrend.isEmpty) {
      return _buildNoDataMessage('No daily feeding trend data available');
    }

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _getChartTitle(),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height:
                  300, // Set a fixed height or use Expanded if inside a Column
              child: _buildEnhancedChart(dailyFeedingTrend, isVolume: false),
            ),
            if (_selectedPeriod != TimePeriod.today) ...[
              const SizedBox(height: 16),
              _buildChartLegend(isVolume: false),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVolumeTrendChart() {
    List<Map<String, dynamic>> volumeTrend =
        (_insights['volumeTrend'] as List?)?.map((item) {
              final entry = item as MapEntry<String, int>;
              return {
                'date': entry.key,
                'volume': entry.value.toDouble(),
              };
            }).toList() ??
            [];

    if (volumeTrend.isEmpty) {
      return _buildNoDataMessage('No volume trend data available');
    }

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _getVolumeChartTitle(),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height:
                  300, // Set a fixed height or use Expanded if inside a Column
              child: _buildEnhancedChart(volumeTrend, isVolume: true),
            ),
            if (_selectedPeriod != TimePeriod.today) ...[
              const SizedBox(height: 16),
              _buildChartLegend(isVolume: true),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNoDataMessage(String message) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(Icons.bar_chart, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Keep tracking your feedings to see insights here!',
              style: TextStyle(fontSize: 14, color: Colors.grey[400]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _getChartTitle() {
    switch (_selectedPeriod) {
      case TimePeriod.today:
        return 'Today\'s Feeding Frequency';
      case TimePeriod.lastWeek:
        return 'Last 7 Days Feeding Frequency';
      case TimePeriod.lastTwoWeeks:
        return 'Last 14 Days Feeding Frequency';
      case TimePeriod.lastMonth:
        return 'Last Month\'s Feeding Frequency';
    }
  }

  String _getVolumeChartTitle() {
    switch (_selectedPeriod) {
      case TimePeriod.today:
        return 'Today\'s Feeding Volume';
      case TimePeriod.lastWeek:
        return 'Last 7 Days Feeding Volume';
      case TimePeriod.lastTwoWeeks:
        return 'Last 14 Days Feeding Volume';
      case TimePeriod.lastMonth:
        return 'Last Month\'s Feeding Volume';
    }
  }

  Widget _buildEnhancedChart(List<Map<String, dynamic>> data,
      {required bool isVolume}) {
    return LayoutBuilder(builder: (context, constraints) {
      if (_selectedPeriod == TimePeriod.today) {
        return _buildTodayChart(data, constraints, isVolume: isVolume);
      } else {
        return _buildPeriodLineChart(data, constraints, isVolume: isVolume);
      }
    });
  }

  Widget _buildTodayChart(
      List<Map<String, dynamic>> data, BoxConstraints constraints,
      {required bool isVolume}) {
    // Group data by feeding type
    Map<String, Map<String, dynamic>> feedingTypeData = {
      'Breast': {'count': 0, 'volume': 0.0},
      'Bottle': {'count': 0, 'volume': 0.0},
      'Pumping': {'count': 0, 'volume': 0.0},
    };

    // Aggregate data by feeding type
    for (var feeding in _feedingData) {
      DateTime feedingTime = DateTime.parse(feeding['startTime']);
      if (feedingTime.day == DateTime.now().day) {
        String feedingType = feeding['feedingType'] ?? 'Unknown';
        double quantity = (feeding['quantity'] as num?)?.toDouble() ?? 0.0;

        if (feedingTypeData.containsKey(feedingType)) {
          feedingTypeData[feedingType]!['count'] =
              (feedingTypeData[feedingType]!['count'] as int) + 1;
          feedingTypeData[feedingType]!['volume'] =
              (feedingTypeData[feedingType]!['volume'] as double) + quantity;
        }
      }
    }

    List<Color> feedingColors = [
      const Color(0xFF6D9EEB), // Soft blue for breast
      const Color(0xFF93C47D), // Soft green for bottle
      const Color(0xFFF6B26B), // Soft orange for pumping
    ];

    // Find the maximum value for y-axis
    double maxY = 0.0; // Initialize as double
    if (isVolume) {
      maxY = feedingTypeData.values
          .map((e) => (e['volume'] as double))
          .reduce((a, b) => a > b ? a : b);
    } else {
      maxY = feedingTypeData.values
          .map((e) => (e['count'] as int).toDouble())
          .reduce((a, b) => a > b ? a : b);
    }

    // Adjust maxY for better visualization
    if (!isVolume) {
      maxY = max(maxY, 5.0); // Use 5.0 instead of 5
      maxY = (maxY / 1).ceilToDouble(); // Use ceilToDouble() instead of ceil()
    } else {
      maxY = max(maxY, 100.0);
      maxY = ((maxY / 50).ceil() * 50).toDouble();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (constraints.maxHeight >
            100) // Only show title if there's enough space
          Padding(
            padding: const EdgeInsets.only(left: 40, bottom: 8),
            child: Text(
              isVolume ? 'Volume (ml)' : 'Number of Feedings',
              style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.bold),
            ),
          ),
        Expanded(
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxY,
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  //tooltipBgColor: Colors.blueGrey.withOpacity(0.8),
                  tooltipRoundedRadius: 8,
                  tooltipPadding: const EdgeInsets.all(8),
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final feedingType =
                        ['Breast', 'Bottle', 'Pumping'][group.x.toInt()];
                    final data = feedingTypeData[feedingType]!;
                    return BarTooltipItem(
                      '$feedingType\n${isVolume ? '${data['volume'].round()} ml' : '${data['count']} times'}',
                      const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
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
                      List<String> titles = ['Breast', 'Bottle', 'Pumping'];
                      List<IconData> icons = [
                        Icons.child_care,
                        Icons.baby_changing_station,
                        Icons.water_drop
                      ];
                      return Column(
                        children: [
                          Icon(icons[value.toInt()],
                              size: min(30, constraints.maxWidth / 10),
                              color: feedingColors[value.toInt()]),
                          if (constraints.maxHeight >
                              200) // Only show text if enough space
                            Text(
                              titles[value.toInt()],
                              style: TextStyle(
                                  fontSize: min(14, constraints.maxWidth / 25),
                                  color: Colors.grey[600]),
                            ),
                        ],
                      );
                    },
                    reservedSize: constraints.maxHeight > 200 ? 60 : 40,
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        value.toInt().toString(),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      );
                    },
                    interval: isVolume ? maxY / 5 : 1,
                    reservedSize: 40,
                  ),
                ),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: isVolume ? maxY / 5 : 1,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                      color: Colors.grey[300],
                      strokeWidth: 1,
                      dashArray: [5, 5]);
                },
              ),
              borderData: FlBorderData(
                show: true,
                border: Border(
                  bottom: BorderSide(color: Colors.grey[400]!, width: 1),
                  left: BorderSide(color: Colors.grey[400]!, width: 1),
                ),
              ),
              barGroups: feedingTypeData.entries.map((entry) {
                final index =
                    ['Breast', 'Bottle', 'Pumping'].indexOf(entry.key);
                final data = entry.value;
                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: isVolume
                          ? (data['volume'] as double)
                          : (data['count'] as int).toDouble(),
                      color: feedingColors[index],
                      width: constraints.maxWidth * 0.15, // Increase bar width
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(8)),
                      backDrawRodData: BackgroundBarChartRodData(
                        show: true,
                        toY: maxY,
                        color: feedingColors[index].withOpacity(0.1),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodLineChart(
      List<Map<String, dynamic>> data, BoxConstraints constraints,
      {required bool isVolume}) {
    final List<Color> gradientColors = [
      const Color(0xff23b6e6),
      const Color(0xff02d39a),
    ];

    // Prepare the data with feeding type counts
    List<Map<String, dynamic>> enhancedData = data.map((entry) {
      final date = DateTime.parse(entry['date']);
      int breastCount = 0;
      int bottleCount = 0;
      int pumpingCount = 0;
      double totalVolume = 0;

      for (var feeding in _feedingData) {
        final feedingDate = DateTime.parse(feeding['startTime']);
        if (feedingDate.year == date.year &&
            feedingDate.month == date.month &&
            feedingDate.day == date.day) {
          switch (feeding['feedingType']) {
            case 'Breast':
              breastCount++;
              break;
            case 'Bottle':
              bottleCount++;
              double quantity = (feeding['quantity'] as num?)?.toDouble() ?? 0;
              totalVolume += quantity;
              break;
            case 'Pumping':
              pumpingCount++;
              double quantity = (feeding['quantity'] as num?)?.toDouble() ?? 0;
              totalVolume += quantity;
              break;
          }
        }
      }

      return {
        ...entry,
        'breastCount': breastCount,
        'bottleCount': bottleCount,
        'pumpingCount': pumpingCount,
        'totalVolume': totalVolume,
      };
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (constraints.maxHeight > 100)
          Padding(
            padding: const EdgeInsets.only(left: 40, bottom: 8),
            child: Text(
              isVolume ? 'Volume (ml)' : 'Number of Feedings',
              style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.bold),
            ),
          ),
        Expanded(
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: true,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                      color: Colors.grey[300],
                      strokeWidth: 1,
                      dashArray: [5, 5]);
                },
                getDrawingVerticalLine: (value) {
                  return FlLine(
                      color: Colors.grey[300],
                      strokeWidth: 1,
                      dashArray: [5, 5]);
                },
              ),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: constraints.maxHeight > 200 ? 30 : 22,
                    interval: max(1, (data.length / 5).floor()).toDouble(),
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index >= 0 &&
                          index < enhancedData.length &&
                          index % max(1, (enhancedData.length / 5).floor()) ==
                              0) {
                        final date =
                            DateTime.parse(enhancedData[index]['date']);
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            DateFormat('MM/dd').format(date),
                            style: TextStyle(
                              color: const Color(0xff68737d),
                              fontWeight: FontWeight.bold,
                              fontSize: min(12, constraints.maxWidth / 30),
                            ),
                          ),
                        );
                      }
                      return const Text('');
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        isVolume
                            ? '${value.toInt()} ml'
                            : value.toInt().toString(),
                        style: const TextStyle(
                          color: Color(0xff67727d),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      );
                    },
                    reservedSize: 40,
                  ),
                ),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border.all(color: Colors.grey[400]!, width: 1),
              ),
              minX: 0,
              maxX: (enhancedData.length - 1).toDouble(),
              minY: 0,
              maxY: enhancedData.isEmpty
                  ? 10
                  : (enhancedData
                          .map((e) => isVolume
                              ? (e['totalVolume'] as num?)?.toDouble() ?? 0
                              : ((e['breastCount'] as int) +
                                      (e['bottleCount'] as int) +
                                      (e['pumpingCount'] as int))
                                  .toDouble())
                          .reduce((a, b) => a > b ? a : b) *
                      1.2),
              lineBarsData: [
                LineChartBarData(
                  spots: enhancedData.asMap().entries.map((entry) {
                    return FlSpot(
                      entry.key.toDouble(),
                      isVolume
                          ? (entry.value['totalVolume'] as num?)?.toDouble() ??
                              0
                          : ((entry.value['breastCount'] as int) +
                                  (entry.value['bottleCount'] as int) +
                                  (entry.value['pumpingCount'] as int))
                              .toDouble(),
                    );
                  }).toList(),
                  isCurved: true,
                  gradient: LinearGradient(colors: gradientColors),
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) {
                      return FlDotCirclePainter(
                        radius: 4,
                        color: Colors.white,
                        strokeWidth: 2,
                        strokeColor: gradientColors[0],
                      );
                    },
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: gradientColors
                          .map((color) => color.withOpacity(0.3))
                          .toList(),
                    ),
                  ),
                ),
              ],
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  //tooltipBgColor: Colors.blueGrey.withOpacity(0.8),
                  tooltipRoundedRadius: 8,
                  getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                    return touchedBarSpots.map((barSpot) {
                      final flSpot = barSpot;
                      final date = DateTime.parse(
                          enhancedData[flSpot.x.toInt()]['date']);
                      final feedingData = enhancedData[flSpot.x.toInt()];
                      return LineTooltipItem(
                        '${DateFormat('MM/dd').format(date)}',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        children: [
                          TextSpan(
                            text:
                                '\n${isVolume ? 'Total Volume: ${feedingData['totalVolume'].toInt()} ml' : 'Total Feedings: ${flSpot.y.toInt()}'}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.normal,
                              fontSize: 12,
                            ),
                          ),
                          TextSpan(
                            text: '\nBreast: ${feedingData['breastCount']}',
                            style: const TextStyle(
                              color: Colors.lightBlueAccent,
                              fontWeight: FontWeight.normal,
                              fontSize: 12,
                            ),
                          ),
                          TextSpan(
                            text: '\nBottle: ${feedingData['bottleCount']}',
                            style: const TextStyle(
                              color: Colors.lightGreenAccent,
                              fontWeight: FontWeight.normal,
                              fontSize: 12,
                            ),
                          ),
                          TextSpan(
                            text: '\nPumping: ${feedingData['pumpingCount']}',
                            style: const TextStyle(
                              color: Colors.orangeAccent,
                              fontWeight: FontWeight.normal,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      );
                    }).toList();
                  },
                ),
                handleBuiltInTouches: true,
                touchCallback:
                    (FlTouchEvent event, LineTouchResponse? lineTouch) {
                  // Handle touch events if needed
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChartLegend({required bool isVolume}) {
    if (_selectedPeriod == TimePeriod.today) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildLegendItem('Breast', Colors.blue),
          const SizedBox(width: 16),
          _buildLegendItem('Bottle', Colors.green),
          const SizedBox(width: 16),
          _buildLegendItem('Pumping', Colors.orange),
        ],
      );
    } else {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildLegendItem(
              isVolume ? 'Volume (ml)' : 'Feeding Count', Colors.blue),
        ],
      );
    }
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildRecommendations() {
    List<String> recommendations = [];

    // General feeding frequency recommendations
    double feedingsPerDay = (_insights['feedingsPerDay'] as num?)?.toDouble() ?? 0.0;
    if (_babyAgeInMonths <= 1) {
      if (feedingsPerDay < 8) {
        recommendations.add(
            'For newborns, aim for 8-12 feedings per day. Consider increasing feeding frequency to support optimal growth.');
      } else if (feedingsPerDay > 12) {
        recommendations.add(
            'Your feeding frequency is high, which is common for newborns. Ensure you\'re getting enough rest between feedings.');
      }
    } else if (_babyAgeInMonths <= 6) {
      if (feedingsPerDay < 6) {
        recommendations.add(
            'For babies 1-6 months old, aim for 6-8 feedings per day. Consider increasing feeding frequency for optimal nutrition.');
      }
    }

    // Breastfeeding-specific recommendations
    String favoriteBreast = _insights['favoriteBreast'] as String? ?? 'N/A';
    if (favoriteBreast != 'N/A') {
      recommendations.add(
          'You seem to favor the $favoriteBreast breast. Try to balance feedings between both breasts to maintain milk supply and prevent engorgement.');
    }

    // Bottle feeding recommendations
    double averageBottleVolume = (_insights['averageBottleVolume'] as num?)?.toDouble() ?? 0.0;
    if (_babyAgeInMonths <= 6) {
      if (averageBottleVolume > 180) {
        recommendations.add(
            'Your average bottle volume is high. For babies under 6 months, aim for 60-120 ml per feeding to prevent overfeeding.');
      }
    } else if (_babyAgeInMonths <= 12) {
      if (averageBottleVolume < 120) {
        recommendations.add(
            'Consider increasing your bottle volume slightly. Babies 6-12 months typically take 120-240 ml per feeding.');
      }
    }

    // Pumping recommendations
    int pumpingSessions = _pumpingSessions;
    if (_breastfeedings > 0 && pumpingSessions == 0) {
      recommendations.add(
          'Consider adding pumping sessions to build a milk supply reserve, especially if you plan to return to work or be away from your baby.');
    }

    // Night feeding recommendations
    Duration? longestStretch = _insights['longestStretchBetweenFeedings'] as Duration?;
    if (longestStretch != null) {
      if (_babyAgeInMonths <= 3 && longestStretch.inHours > 4) {
        recommendations.add(
            'Your baby is having long stretches between feedings. For babies under 3 months, consider adding a night feeding to support growth and maintain milk supply.');
      } else if (_babyAgeInMonths <= 6 && longestStretch.inHours > 6) {
        recommendations.add(
            'Your baby is sleeping for longer stretches. While this is normal development, ensure they\'re still getting enough feedings during the day.');
      }
    }

    // Feeding pattern variety
    if (_breastfeedings == 0 && _bottleFeedings > 0) {
      recommendations.add(
          'You\'re exclusively bottle feeding. If this is intentional, ensure you\'re using appropriate formula or expressed breast milk. If you\'re open to breastfeeding, consider consulting a lactation specialist.');
    }

    if (_breastfeedings > 0 && _bottleFeedings == 0 && _babyAgeInMonths >= 4) {
      recommendations.add(
          'You\'re exclusively breastfeeding. Around 4-6 months, you might consider introducing a bottle occasionally to help your baby adapt to different feeding methods.');
    }

    // Add a general positive note if everything looks good
    if (recommendations.isEmpty) {
      recommendations.add(
          'Great job! Your feeding patterns appear to be appropriate for your baby\'s age. Keep up the good work and continue to monitor your baby\'s growth and satisfaction after feedings.');
    }

    if (recommendations.isEmpty) {
      return _buildNoDataMessage('Not enough data for personalized recommendations');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Personalized Recommendations:',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...recommendations
            .map((rec) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline,
                          size: 18, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                          child:
                              Text(rec, style: const TextStyle(fontSize: 14))),
                    ],
                  ),
                ))
            .toList(),
      ],
    );
  }
}

enum TimePeriod { today, lastWeek, lastTwoWeeks, lastMonth }
