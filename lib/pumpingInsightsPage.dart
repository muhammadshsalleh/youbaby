import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';
import 'package:youbaby/pumpingInsightsRecommendationPage.dart';

class PumpingInsightsPage extends StatefulWidget {
  final int userId;
  final int babyAgeInMonths;

  const PumpingInsightsPage({
    Key? key,
    required this.userId,
    required this.babyAgeInMonths,
  }) : super(key: key);

  @override
  _PumpingInsightsPageState createState() => _PumpingInsightsPageState();
}

class _PumpingInsightsPageState extends State<PumpingInsightsPage> {
  TimePeriod _selectedTimePeriod = TimePeriod.today;
  late Future<Map<String, dynamic>> _insightsFuture;

  @override
  void initState() {
    super.initState();
    _insightsFuture = _fetchInsights();
  }

  Future<Map<String, dynamic>> _fetchInsights() async {
    try {
      final supabase = Supabase.instance.client;
      final now = DateTime.now();
      final startDate = _getStartDate(now);

      final response = await supabase
          .from('feedingTracker')
          .select()
          .eq('userID', widget.userId)
          .gte('startTime', startDate.toIso8601String())
          .order('startTime');

      final List<Map<String, dynamic>> pumpingData =
          List<Map<String, dynamic>>.from(response);
      return _calculateInsights(pumpingData);
    } catch (e) {
      print('Error fetching insights: $e');
      return {
        'error': 'Failed to fetch data',
        'totalPumpings': 0,
        'averageDuration': Duration.zero,
        'totalVolume': 0.0,
        'averageVolume': 0.0,
        'pumpingsByDay': <String, List<Map<String, dynamic>>>{},
      };
    }
  }

  DateTime _getStartDate(DateTime now) {
    switch (_selectedTimePeriod) {
      case TimePeriod.lastWeek:
        return now.subtract(const Duration(days: 7));
      case TimePeriod.lastTwoWeeks:
        return now.subtract(const Duration(days: 14));
      case TimePeriod.today:
        return DateTime(now.year, now.month, now.day);
    }
  }

   Map<String, dynamic> _calculateInsights(
      List<Map<String, dynamic>> pumpingData) {
    int totalPumpings = 0;
  int totalDurationSeconds = 0;
  double totalVolume = 0;
  double leftBreastVolume = 0;
  double rightBreastVolume = 0;
  Map<String, List<Map<String, dynamic>>> pumpingsByDay = {};

    for (var pumping in pumpingData) {
      DateTime startTime = DateTime.parse(pumping['startTime']);
      String day = DateFormat('yyyy-MM-dd').format(startTime);

      pumpingsByDay[day] ??= [];
      pumpingsByDay[day]!.add(pumping);

      totalPumpings++;
      totalDurationSeconds += pumping['duration'] as int;

      if (pumping['quantity'] != null) {
        double quantity = (pumping['quantity'] as num).toDouble();
         totalVolume += quantity;

        // Assuming we have a 'breast' field in the pumping data
        // where 'left' represents the left breast and 'right' represents the right breast
        if (pumping['breastSide'] == 'Left') {
          leftBreastVolume += quantity;
        } else if (pumping['breastSide'] == 'Right') {
          rightBreastVolume += quantity;
        }
      }      
    }

    double averageVolume = totalPumpings > 0 ? totalVolume / totalPumpings : 0;
    int averageDurationSeconds =
        totalPumpings > 0 ? totalDurationSeconds ~/ totalPumpings : 0;

    return {
      'totalPumpings': totalPumpings,
    'averageDuration': Duration(seconds: averageDurationSeconds),
    'averageVolume': averageVolume,
    'totalVolume': totalVolume,
    'leftBreastVolume': leftBreastVolume,
    'rightBreastVolume': rightBreastVolume,
    'pumpingsByDay': pumpingsByDay,
    };
  }

  Map<String, dynamic> _getPumpingRecommendation(int ageInMonths) {
    if (ageInMonths < 1) {
      return {
        'recommendedFrequency': 8,
        'recommendedVolumeRange': [60.0, 90.0],
        'recommendation': 'Pump 8-12 times per day, aiming for 60-90 ml per session.',
      };
    } else if (ageInMonths < 6) {
      return {
        'recommendedFrequency': 6,
        'recommendedVolumeRange': [120.0, 180.0],
        'recommendation': 'Pump 6-8 times per day, aiming for 120-180 ml per session.',
      };
    } else {
      return {
        'recommendedFrequency': 5,
        'recommendedVolumeRange': [180.0, 240.0],
        'recommendation': 'Pump 5-6 times per day, aiming for 180-240 ml per session.',
      };
    }
  }

  @override
Widget build(BuildContext context) {
  return Scaffold(
    body: Column(
      children: [
        _buildTimePeriodSelector(),
        Expanded(
          child: FutureBuilder<Map<String, dynamic>>(
            future: _insightsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return const Center(child: Text('Error loading insights'));
              }
              
              final insights = snapshot.data ?? {};
              final hasData = insights['totalPumpings'] != null && 
                             insights['totalPumpings'] > 0;
              
              if (!hasData) {
                return _buildNoDataMessage();
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildOverviewCard(insights),
                    const SizedBox(height: 16),
                    _buildPumpingProgressBar(insights),
                    const SizedBox(height: 16),
                    _buildBreastMilkDistributionChart(insights), // Add this line
                    const SizedBox(height: 16),
                    _buildPumpingVolumeChart(insights, _selectedTimePeriod),
                    const SizedBox(height: 16),
                    _buildPumpingRecommendations(insights),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}

  Widget _buildNoDataMessage() {
    String periodText;
    switch (_selectedTimePeriod) {
      case TimePeriod.today:
        periodText = 'today';
        break;
      case TimePeriod.lastWeek:
        periodText = 'in the last week';
        break;
      case TimePeriod.lastTwoWeeks:
        periodText = 'in the last two weeks';
        break;
    }
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.water_drop_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No Pumping Data Available',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'There is no pumping data recorded $periodText.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildTimePeriodSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: TimePeriod.values.map((TimePeriod period) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text(period.toString().split('.').last),
              selected: _selectedTimePeriod == period,
              onSelected: (bool selected) {
                if (selected) {
                  setState(() {
                    _selectedTimePeriod = period;
                    _insightsFuture = _fetchInsights();
                  });
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildOverviewCard(Map<String, dynamic> insights) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pumping Overview',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildOverviewItem('Total Pumping Sessions',
                insights['totalPumpings']?.toString() ?? 'N/A'),
            _buildOverviewItem(
              'Average Pumping Time',
              _formatDuration(insights['averageDuration'] as Duration),
            ),
            _buildOverviewItem(
              'Average Volume per Session',
              '${insights['averageVolume']?.toStringAsFixed(1) ?? 'N/A'} ml',
            ),
            _buildOverviewItem(
              'Total Volume',
              '${insights['totalVolume']?.toStringAsFixed(1) ?? 'N/A'} ml',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    int minutes = duration.inMinutes;
    int seconds = duration.inSeconds % 60;
    return '${minutes}m ${seconds}s';
  }

  Widget _buildPumpingProgressBar(Map<String, dynamic> insights) {
    Map<String, dynamic> recommendation =
        _getPumpingRecommendation(widget.babyAgeInMonths);
    int recommendedFrequency = recommendation['recommendedFrequency'];
    List<double> recommendedVolumeRange =
        recommendation['recommendedVolumeRange'].cast<double>();

    double minRecommendedVolume = recommendedVolumeRange[0];
    double maxRecommendedVolume = recommendedVolumeRange[1];

    int totalPumpings = insights['totalPumpings'] ?? 0;
    double avgVolume = insights['averageVolume'] ?? 0.0;

    double frequencyProgress = totalPumpings / recommendedFrequency;
    double volumeProgress =
        avgVolume / ((minRecommendedVolume + maxRecommendedVolume) / 2);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pumping Progress',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildProgressBar(
              'Pumping Frequency',
              frequencyProgress,
              '$totalPumpings',
              '$recommendedFrequency per day',
              Colors.blue,
            ),
            const SizedBox(height: 24),
            _buildProgressBar(
              'Average Volume',
              volumeProgress,
              '${avgVolume.toStringAsFixed(1)} ml',
              '${minRecommendedVolume.toStringAsFixed(0)}-${maxRecommendedVolume.toStringAsFixed(0)} ml per session',
              Colors.green,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(String label, double progress, String current,
      String target, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: progress.clamp(0.0, 1.0),
          minHeight: 10,
          backgroundColor: color.withOpacity(0.2),
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Current',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  Text(current,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Target',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  Text(target,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBreastMilkDistributionChart(Map<String, dynamic> insights) {
  double leftBreastVolume = insights['leftBreastVolume'] ?? 0.0;
  double rightBreastVolume = insights['rightBreastVolume'] ?? 0.0;
  double totalVolume = leftBreastVolume + rightBreastVolume;

  return Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Breast Milk Distribution',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sectionsSpace: 0,
                centerSpaceRadius: 40,
                sections: [
                  PieChartSectionData(
                    color: Colors.blue,
                    value: leftBreastVolume,
                    title: '${(leftBreastVolume / totalVolume * 100).toStringAsFixed(1)}%',
                    radius: 65,
                    titleStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  PieChartSectionData(
                    color: Colors.green,
                    value: rightBreastVolume,
                    title: '${(rightBreastVolume / totalVolume * 100).toStringAsFixed(1)}%',
                    radius: 65,
                    titleStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(Colors.blue, 'Left Breast'),
              const SizedBox(width: 16),
              _buildLegendItem(Colors.green, 'Right Breast'),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Left Breast: ${leftBreastVolume.toStringAsFixed(1)} ml',
            style: const TextStyle(fontSize: 16),
          ),
          Text(
            'Right Breast: ${rightBreastVolume.toStringAsFixed(1)} ml',
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    ),
  );
}

Widget _buildLegendItem(Color color, String label) {
  return Row(
    children: [
      Container(
        width: 16,
        height: 16,
        color: color,
      ),
      const SizedBox(width: 4),
      Text(label),
    ],
  );
}

  Widget _buildPumpingVolumeChart(
      Map<String, dynamic> insights, TimePeriod selectedTimePeriod) {
    final Map<String, List<Map<String, dynamic>>> pumpingsByDay =
        Map<String, List<Map<String, dynamic>>>.from(insights['pumpingsByDay']);

    if (pumpingsByDay.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: Text('No pumping data available')),
        ),
      );
    }

    List<FlSpot> volumeSpots = [];
    double maxVolume = 0;

    DateTime now = DateTime.now();
    DateTime startDate = _getStartDate(now);

    if (selectedTimePeriod == TimePeriod.today) {
      String todayKey = DateFormat('yyyy-MM-dd').format(now);
      List<Map<String, dynamic>> todayPumpings = pumpingsByDay[todayKey] ?? [];

      for (var pumping in todayPumpings) {
        DateTime pumpingTime = DateTime.parse(pumping['startTime']);
        double hour = pumpingTime.hour + (pumpingTime.minute / 60.0);
        double volume = (pumping['quantity'] as num?)?.toDouble() ?? 0.0;

        volumeSpots.add(FlSpot(hour, volume));
        maxVolume = max(maxVolume, volume);
      }
    } else {
      int dayIndex = 0;
      for (DateTime date = startDate;
          date.isBefore(now.add(const Duration(days: 1)));
          date = date.add(const Duration(days: 1))) {
        String dateKey = DateFormat('yyyy-MM-dd').format(date);
        List<Map<String, dynamic>> dayPumpings = pumpingsByDay[dateKey] ?? [];

        if (dayPumpings.isNotEmpty) {
          double totalVolume = dayPumpings.fold(0.0,
              (sum, pumping) => sum + ((pumping['quantity'] as num?)?.toDouble() ?? 0.0));
          double avgVolume = totalVolume / dayPumpings.length;
          volumeSpots.add(FlSpot(dayIndex.toDouble(), avgVolume));
          maxVolume = max(maxVolume, avgVolume);
        }

        dayIndex++;
      }
    }

    Map<String, dynamic> pumpingRecommendation =
        _getPumpingRecommendation(widget.babyAgeInMonths);
    List<double> recommendedVolume =
        pumpingRecommendation['recommendedVolumeRange'];

    double minRecommendedVolume = recommendedVolume[0];
    double maxRecommendedVolume = recommendedVolume[1];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pumping Volume',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 320,
              child: LineChart(
                LineChartData(
                  lineBarsData: [
                    LineChartBarData(
                      spots: volumeSpots,
                      isCurved: false,
                      color: Colors.purple,
                      dotData: FlDotData(show: true),
                      belowBarData: BarAreaData(show: false),
                    ),
                  ],
                  minY: 0,
                  maxY: max(maxRecommendedVolume, maxVolume) * 1.2,
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (selectedTimePeriod == TimePeriod.today) {
                            int hour = value.toInt();
                            if (hour % 4 == 0 || hour == 23) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  '${hour.toString().padLeft(2, '0')}:00',
                                  style: const TextStyle(fontSize: 10),
                                ),
                              );
                            }
                          } else {
                            DateTime date =
                                startDate.add(Duration(days: value.toInt()));
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                DateFormat('MM/dd').format(date),
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                        reservedSize: 30,
                        interval: 1,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Text('${value.toInt()} ml',
                              style: const TextStyle(fontSize: 10));
                        },
                        reservedSize: 40,
                        interval: 30,
                      ),
                    ),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(show: true, drawVerticalLine: false),
                  borderData: FlBorderData(show: true),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                        return touchedBarSpots.map((barSpot) {
                          final flSpot = barSpot;
                          String xLabel = selectedTimePeriod == TimePeriod.today
                              ? DateFormat('HH:mm').format(DateTime(
                                  now.year,
                                  now.month,
                                  now.day,
                                  flSpot.x.toInt(),
                                  ((flSpot.x % 1) * 60).toInt()))
                              : DateFormat('MM/dd').format(startDate
                                  .add(Duration(days: flSpot.x.toInt())));
                          return LineTooltipItem(
                            '$xLabel\n${flSpot.y.toStringAsFixed(1)} ml',
                            const TextStyle(color: Colors.white),
                          );
                        }).toList();
                      },
                    ),
                  ),
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      HorizontalLine(
                        y: minRecommendedVolume,
                        color: Colors.green.withOpacity(0.8),
                        strokeWidth: 2,
                        dashArray: [5, 5],
                        label: HorizontalLineLabel(
                          show: true,
                          alignment: Alignment.topRight,
                          padding: const EdgeInsets.only(right: 5, bottom: 5),
                          style: const TextStyle(
                              color: Colors.green, fontSize: 10),
                          labelResolver: (line) => 'Min Target',
                        ),
                      ),
                      HorizontalLine(
                        y: maxRecommendedVolume,
                        color: Colors.green.withOpacity(0.8),
                        strokeWidth: 2,
                        dashArray: [5, 5],
                        label: HorizontalLineLabel(
                          show: true,
                          alignment: Alignment.bottomRight,
                          padding: const EdgeInsets.only(right: 5, top: 5),
                          style: const TextStyle(
                              color: Colors.green, fontSize: 10),
                          labelResolver: (line) => 'Max Target',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPumpingRecommendations(Map<String, dynamic> insights) {
  return EnhancedPumpingRecommendations(
    babyAgeInMonths: widget.babyAgeInMonths,
    averageVolumePerSession: insights['averageVolume'] ?? 0.0,
    pumpingFrequencyPerDay: insights['totalPumpings'] ?? 0,
  );
}

  Widget _buildRecommendationItem({required IconData icon, required String text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.blue),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

enum TimePeriod { today, lastWeek, lastTwoWeeks }