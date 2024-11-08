import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';

class DirectFeedingInsightsPage extends StatefulWidget {
  final int babyAgeInMonths;
  final int userId;

  const DirectFeedingInsightsPage({
    Key? key,
    required this.babyAgeInMonths,
    required this.userId,
  }) : super(key: key);

  @override
  _DirectFeedingInsightsPageState createState() => _DirectFeedingInsightsPageState();
}

class _DirectFeedingInsightsPageState extends State<DirectFeedingInsightsPage> {
  TimePeriod _selectedTimePeriod = TimePeriod.today;
  late Future<Map<String, dynamic>> _insightsFuture;

  bool _showBreastFeeding = true;
  bool _showBottleFeeding = true;

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

      // if (response == null) {
      //   throw Exception('No data received');
      // }

      final List<Map<String, dynamic>> feedingData = List<Map<String, dynamic>>.from(response);
      return _calculateInsights(feedingData);
    } catch (e) {
      print('Error fetching insights: $e');
      return {
        'error': 'Failed to fetch data',
        'totalFeedings': 0,
        'breastFeedings': 0,
        'bottleFeedings': 0,
        'averageDuration': Duration.zero,
        'durationByDay': <String, int>{},
        'averageQuantity': 0.0,
        'feedingsByDay': <String, List<Map<String, dynamic>>>{},
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

  Map<String, dynamic> _calculateInsights(List<Map<String, dynamic>> feedingData) {
    int breastFeedings = 0;
    int bottleFeedings = 0;
    int totalDurationSeconds = 0;
    double totalQuantityOz = 0;
    int lastBreastFeedingDurationSeconds = 0;
    double lastBottleFeedingQuantityOz = 0;
    Map<String, int> durationByDay = {};
    Map<String, List<Map<String, dynamic>>> feedingsByDay = {};

    // Sort feedingData by startTime in descending order to get the latest feedings first
    feedingData.sort((a, b) => DateTime.parse(b['startTime']).compareTo(DateTime.parse(a['startTime'])));

    for (var feeding in feedingData) {
      DateTime startTime = DateTime.parse(feeding['startTime']);
      String day = DateFormat('yyyy-MM-dd').format(startTime);
      
      feedingsByDay[day] ??= [];
      feedingsByDay[day]!.add(feeding);
      
      int duration = feeding['duration'] as int;
      
      if (feeding['feedingType'] == 'Breast') {
        breastFeedings++;
        totalDurationSeconds += duration;
        
        // Update last breast feeding duration if it hasn't been set yet
        if (lastBreastFeedingDurationSeconds == 0) {
          lastBreastFeedingDurationSeconds = duration;
        }
      } else if (feeding['feedingType'] == 'Bottle') {
        bottleFeedings++;
        totalDurationSeconds += duration;
        double quantity = (feeding['quantity'] as num).toDouble();
        String unit = feeding['unit'] as String;
        if (unit.toLowerCase() == 'ml') {
          quantity = quantity / 29.5735; // Convert ml to oz
        }
        totalQuantityOz += quantity;
        
        // Update last bottle feeding quantity if it hasn't been set yet
        if (lastBottleFeedingQuantityOz == 0) {
          lastBottleFeedingQuantityOz = quantity;
        }
      }
      
      durationByDay[day] = (durationByDay[day] ?? 0) + duration;
    }

    int totalFeedings = breastFeedings + bottleFeedings;
    double averageQuantityOz = bottleFeedings > 0 ? totalQuantityOz / bottleFeedings : 0;
    Duration averageDuration = totalFeedings > 0 ? Duration(seconds: totalDurationSeconds ~/ totalFeedings) : Duration.zero;

    return {
      'totalFeedings': totalFeedings,
      'breastFeedings': breastFeedings,
      'bottleFeedings': bottleFeedings,
      'totalDurationSeconds': totalDurationSeconds,
      'averageDuration': averageDuration,
      'durationByDay': durationByDay,
      'averageQuantityOz': averageQuantityOz,
      'lastBottleFeedingQuantityOz': lastBottleFeedingQuantityOz,
      'lastBreastFeedingDurationSeconds': lastBreastFeedingDurationSeconds,
      'feedingsByDay': feedingsByDay,
    };
  }

  Map<String, dynamic> _getFeedingRecommendation(int ageInMonths) {
    if (ageInMonths < 1) {
      return {
        'recommendedFrequency': 8.0,
        'recommendedVolumeOz': 2.0, // 60 ml converted to oz
        'recommendedVolumeRange': '2-3 oz',
        'recommendation': 'Feed your baby 8-12 times per day, about 2-3 ounces (60-90 ml) per feeding.',
      };
    } else if (ageInMonths < 3) {
      return {
        'recommendedFrequency': 7.0,
        'recommendedVolumeOz': 3.5, // 105 ml (average of 90-120 ml) converted to oz
        'recommendedVolumeRange': '3-4 oz',
        'recommendation': 'Feed your baby 6-8 times per day, about 3-4 ounces (90-120 ml) per feeding.',
      };
    } else if (ageInMonths <= 6) {
      return {
        'recommendedFrequency': 6.0,
        'recommendedVolumeOz': 5.0, // 150 ml (average of 120-180 ml) converted to oz
        'recommendedVolumeRange': '4-6 oz',
        'recommendation': 'Feed your baby 5-6 times per day, about 4-6 ounces (120-180 ml) per feeding.',
      };
    } else {
      return {
        'recommendedFrequency': 5.0,
        'recommendedVolumeOz': 6.0,
        'recommendedVolumeRange': '6-8 oz',
        'recommendation': 'Feed your baby 4-5 times per day, about 6-8 ounces (180-240 ml) per feeding.',
      };
    }
  }

  Map<String, dynamic> _getBreastfeedingRecommendation(int ageInMonths) {
    if (ageInMonths < 1) {
      return {
        'ageGroup': 'Newborn (0-1 Month)',
        'sessionDuration': '20-45 minutes',
        'frequency': 'Every 2-3 hours, 8-12 times per day',
        'note': 'Newborns may take longer to feed as they are still learning how to latch and suck effectively. They may also fall asleep during feedings and need to be gently awakened to finish.',
      };
    } else if (ageInMonths < 3) {
      return {
        'ageGroup': '1-3 Months',
        'sessionDuration': '15-30 minutes',
        'frequency': 'Every 2-4 hours, 7-9 times per day',
        'note': 'As babies grow, they become more efficient at sucking, reducing the time needed per session.',
      };
    } else if (ageInMonths < 6) {
      return {
        'ageGroup': '3-6 Months',
        'sessionDuration': '10-20 minutes',
        'frequency': 'Every 3-4 hours, 6-8 times per day',
        'note': 'At this stage, babies can usually get enough milk within shorter periods due to stronger suction.',
      };
    } else if (ageInMonths < 12) {
      return {
        'ageGroup': '6-12 Months',
        'sessionDuration': '5-15 minutes',
        'frequency': 'Every 4-6 hours, 5-7 times per day',
        'note': 'Babies are starting to eat solid foods around this time, which can decrease the need for frequent and long breastfeeding sessions.',
      };
    } else {
      return {
        'ageGroup': '12 Months and Beyond',
        'sessionDuration': '5-10 minutes',
        'frequency': 'On demand or 3-4 times per day',
        'note': 'Breastfeeding can become more of a comfort or bonding activity rather than a primary source of nutrition.',
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
                if (snapshot.hasError || !snapshot.hasData) {
                  return const Center(child: Text('Error loading insights'));
                }

                final insights = snapshot.data!;
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildOverviewCard(insights),
                      const SizedBox(height: 16),
                      _buildBreastVsBottleComparison(insights),
                      const SizedBox(height: 16),
                      _buildFeedingProgressBar(insights),
                      const SizedBox(height: 16),
                      _buildFeedingDurationChart(insights, _selectedTimePeriod),
                      const SizedBox(height: 16),
                      _buildBreastfeedingRecommendations(insights),
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
            'Feeding Overview',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildOverviewItem('Total Feedings', insights['totalFeedings']?.toString() ?? 'N/A'),
          _buildOverviewItem('Breast Feedings', insights['breastFeedings']?.toString() ?? 'N/A'),
          _buildOverviewItem('Bottle Feedings', insights['bottleFeedings']?.toString() ?? 'N/A'),
          _buildOverviewItem(
            'Total Feeding Time',
            _formatDurationSafely(insights['totalDurationSeconds'] ?? 0),
          ),
          _buildOverviewItem(
            'Average Feeding Time',
            _formatDurationSafely(insights['averageDurationSeconds']),
          ),
        ],
      ),
    ),
  );
}

String _formatDurationSafely(dynamic seconds) {
  if (seconds == null || seconds is! int) {
    return 'N/A';
  }
  return _formatDuration(Duration(seconds: seconds));
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

  Widget _buildBreastVsBottleComparison(Map<String, dynamic> insights) {
    final breastFeedings = insights['breastFeedings'] as int;
    final bottleFeedings = insights['bottleFeedings'] as int;
    final total = breastFeedings + bottleFeedings;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Breast vs Bottle Comparison',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: total > 0 ? PieChart(
                PieChartData(
                  sections: [
                    PieChartSectionData(
                      color: Colors.pink,
                      value: breastFeedings.toDouble(),
                      title: '${(breastFeedings / total * 100).toStringAsFixed(1)}%',
                      radius: 70,
                      titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    PieChartSectionData(
                      color: Colors.blue,
                      value: bottleFeedings.toDouble(),
                      title: '${(bottleFeedings / total * 100).toStringAsFixed(1)}%',
                      radius: 70,
                      titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                  sectionsSpace: 0,
                  centerSpaceRadius: 40,
                ),
              ) : const Center(child: Text('No feeding data available')),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem('Breast', Colors.pink),
                const SizedBox(width: 16),
                _buildLegendItem('Bottle', Colors.blue),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
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

 Widget _buildFeedingProgressBar(Map<String, dynamic> insights) {
    Map<String, dynamic> recommendation = _getFeedingRecommendation(widget.babyAgeInMonths);
    int recommendedFrequency = recommendation['recommendedFrequency'].round();
    double recommendedVolumeOz = recommendation['recommendedVolumeOz'];
    
    Map<String, dynamic> breastRecommendation = _getBreastfeedingRecommendation(widget.babyAgeInMonths);
    List<String> recommendedDuration = breastRecommendation['sessionDuration'].split('-');
    int minRecommendedDuration = int.parse(recommendedDuration[0].replaceAll(RegExp(r'[^0-9]'), ''));
    int maxRecommendedDuration = int.parse(recommendedDuration[1].replaceAll(RegExp(r'[^0-9]'), ''));
    int recommendedDurationSeconds = ((minRecommendedDuration + maxRecommendedDuration) / 2 * 60).round();
    
    double frequencyProgress = (insights['totalFeedings'] as int) / recommendedFrequency;
    
    double? lastBottleFeedingQuantityOz = insights['lastBottleFeedingQuantityOz'] as double?;
    int? lastBreastFeedingDurationSeconds = insights['lastBreastFeedingDurationSeconds'] as int?;
    
    double bottleVolumeProgress = 0.0;
    String bottleVolumeText = 'N/A';
    
    double breastDurationProgress = 0.0;
    String breastDurationText = 'N/A';
    
    if (lastBottleFeedingQuantityOz != null) {
      bottleVolumeProgress = lastBottleFeedingQuantityOz / recommendedVolumeOz;
      bottleVolumeText = '${lastBottleFeedingQuantityOz.toStringAsFixed(1)} oz';
    }

    if (lastBreastFeedingDurationSeconds != null) {
      breastDurationProgress = lastBreastFeedingDurationSeconds / recommendedDurationSeconds;
      breastDurationText = _formatDuration(Duration(seconds: lastBreastFeedingDurationSeconds));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Feeding Progress',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildProgressBar(
              'Feeding Frequency', 
              frequencyProgress, 
              '${insights['totalFeedings']}', 
              '$recommendedFrequency per day',
              Colors.blue,
            ),
            const SizedBox(height: 24),
            _buildProgressBar(
              'Last Bottle Feeding Volume', 
              bottleVolumeProgress, 
              bottleVolumeText, 
              '${recommendation['recommendedVolumeRange']} per session',
              Colors.green,
            ),
            const SizedBox(height: 24),
            _buildProgressBar(
              'Last Breast Feeding Duration', 
              breastDurationProgress, 
              breastDurationText, 
              '${breastRecommendation['sessionDuration']} per session',
              Colors.pink,
            ),
          ],
        ),
      ),
    );
  }

Widget _buildProgressBar(String label, double progress, String current, String target, Color color) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                Text('Current', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                Text(current, style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Target', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                Text( target, style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    ],
  );
}

Widget _buildFeedingDurationChart(Map<String, dynamic> insights, TimePeriod selectedTimePeriod) {
    final Map<String, List<Map<String, dynamic>>> feedingsByDay = Map<String, List<Map<String, dynamic>>>.from(insights['feedingsByDay']);
    
    if (feedingsByDay.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: Text('No feeding data available')),
        ),
      );
    }

    List<FlSpot> breastFeedingSpots = [];
    List<FlSpot> bottleFeedingSpots = [];
    double maxDuration = 0;

    // Process feedings based on selected time period
    DateTime now = DateTime.now();
    DateTime startDate = _getStartDate(now);

    if (selectedTimePeriod == TimePeriod.today) {
      String todayKey = DateFormat('yyyy-MM-dd').format(now);
      List<Map<String, dynamic>> todayFeedings = feedingsByDay[todayKey] ?? [];

      for (var feeding in todayFeedings) {
        DateTime feedingTime = DateTime.parse(feeding['startTime']);
        double hour = feedingTime.hour + (feedingTime.minute / 60.0);
        int durationMinutes = (feeding['duration'] as int) ~/ 60;

        FlSpot spot = FlSpot(hour, durationMinutes.toDouble());

        if (feeding['feedingType'] == 'Breast') {
          breastFeedingSpots.add(spot);
        } else {
          bottleFeedingSpots.add(spot);
        }

        maxDuration = max(maxDuration, durationMinutes.toDouble());
      }
    } else {
      // For other time periods, aggregate data by day
      int dayIndex = 0;
      for (DateTime date = startDate; date.isBefore(now.add(const Duration(days: 1))); date = date.add(const Duration(days: 1))) {
        String dateKey = DateFormat('yyyy-MM-dd').format(date);
        List<Map<String, dynamic>> dayFeedings = feedingsByDay[dateKey] ?? [];

        double breastDurationSum = 0;
        double bottleDurationSum = 0;
        int breastCount = 0;
        int bottleCount = 0;

        for (var feeding in dayFeedings) {
          int durationMinutes = (feeding['duration'] as int) ~/ 60;

          if (feeding['feedingType'] == 'Breast') {
            breastDurationSum += durationMinutes;
            breastCount++;
          } else {
            bottleDurationSum += durationMinutes;
            bottleCount++;
          }
        }

        if (breastCount > 0) {
          double avgBreastDuration = breastDurationSum / breastCount;
          breastFeedingSpots.add(FlSpot(dayIndex.toDouble(), avgBreastDuration));
          maxDuration = max(maxDuration, avgBreastDuration);
        }

        if (bottleCount > 0) {
          double avgBottleDuration = bottleDurationSum / bottleCount;
          bottleFeedingSpots.add(FlSpot(dayIndex.toDouble(), avgBottleDuration));
          maxDuration = max(maxDuration, avgBottleDuration);
        }

        dayIndex++;
      }
    }

    Map<String, dynamic> breastfeedingRecommendation = _getBreastfeedingRecommendation(widget.babyAgeInMonths);
    List<String> recommendedDuration = breastfeedingRecommendation['sessionDuration'].split('-');
    
    double minRecommendedDuration = double.parse(recommendedDuration[0].replaceAll(RegExp(r'[^0-9]'), ''));
    double maxRecommendedDuration = double.parse(recommendedDuration[1].replaceAll(RegExp(r'[^0-9]'), ''));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Feeding Duration',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildFilterChip('Breast', Colors.pink, _showBreastFeeding, () => setState(() => _showBreastFeeding = !_showBreastFeeding)),
                _buildFilterChip('Bottle', Colors.blue, _showBottleFeeding, () => setState(() => _showBottleFeeding = !_showBottleFeeding)),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 320,
              child: LineChart(
                LineChartData(
                  lineBarsData: [
                    if (_showBreastFeeding)
                      LineChartBarData(
                        spots: breastFeedingSpots,
                        isCurved: false,
                        color: Colors.pink,
                        dotData: FlDotData(show: true),
                        belowBarData: BarAreaData(show: false),
                      ),
                    if (_showBottleFeeding)
                      LineChartBarData(
                        spots: bottleFeedingSpots,
                        isCurved: false,
                        color: Colors.blue,
                        dotData: FlDotData(show: true),
                        belowBarData: BarAreaData(show: false),
                      ),
                  ],
                  minY: 0,
                  maxY: max(maxRecommendedDuration, maxDuration) * 1.2,
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
                            DateTime date = startDate.add(Duration(days: value.toInt()));
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
                          return Text('${value.toInt()} min', style: const TextStyle(fontSize: 10));
                        },
                        reservedSize: 40,
                        interval: 10,
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(show: true, drawVerticalLine: false),
                  borderData: FlBorderData(show: true),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                        return touchedBarSpots.map((barSpot) {
                          final flSpot = barSpot;
                          String xLabel = selectedTimePeriod == TimePeriod.today
                            ? DateFormat('HH:mm').format(DateTime(now.year, now.month, now.day, flSpot.x.toInt(), ((flSpot.x % 1) * 60).toInt()))
                            : DateFormat('MM/dd').format(startDate.add(Duration(days: flSpot.x.toInt())));
                          return LineTooltipItem(
                            '$xLabel\n${flSpot.y.toStringAsFixed(1)} min',
                            const TextStyle(color: Colors.white),
                          );
                        }).toList();
                      },
                    ),
                  ),
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      HorizontalLine(
                        y: minRecommendedDuration,
                        color: Colors.green.withOpacity(0.8),
                        strokeWidth: 2,
                        dashArray: [5, 5],
                        label: HorizontalLineLabel(
                          show: true,
                          alignment: Alignment.topRight,
                          padding: const EdgeInsets.only(right: 5, bottom: 5),
                          style: const TextStyle(color: Colors.green, fontSize: 10),
                          labelResolver: (line) => 'Min Target',
                        ),
                      ),
                      HorizontalLine(
                        y: maxRecommendedDuration,
                        color: Colors.green.withOpacity(0.8),
                        strokeWidth: 2,
                        dashArray: [5, 5],
                        label: HorizontalLineLabel(
                          show: true,
                          alignment: Alignment.bottomRight,
                          padding: const EdgeInsets.only(right: 5, top: 5),
                          style: const TextStyle(color: Colors.green, fontSize: 10),
                          labelResolver: (line) => 'Max Target',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem('Breast', Colors.pink),
                const SizedBox(width: 16),
                _buildLegendItem('Bottle', Colors.blue),
              ],
            ),
          ],
        ),
      ),
    );
  }

Widget _buildFilterChip(String label, Color color, bool isSelected, VoidCallback onSelected) {
  return FilterChip(
    label: Text(label),
    selected: isSelected,
    onSelected: (_) => onSelected(),
    selectedColor: color.withOpacity(0.3),
    checkmarkColor: color,
  );
}

Widget _buildBreastfeedingRecommendations(Map<String, dynamic> insights) {
    Map<String, dynamic> recommendation = _getBreastfeedingRecommendation(widget.babyAgeInMonths);
    
    // Helper function to extract the first number from a string
    int? extractFirstNumber(String text) {
      final match = RegExp(r'\d+').firstMatch(text);
      return match != null ? int.parse(match.group(0)!) : null;
    }

    // Extract the minimum recommended frequency
    final frequencyText = recommendation['frequency'] as String;
    final minRecommendedFrequency = extractFirstNumber(frequencyText);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Breastfeeding Recommendations',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text('Age Group: ${recommendation['ageGroup']}'),
            const SizedBox(height: 8),
            Text('Recommended Session Duration: ${recommendation['sessionDuration']}'),
            const SizedBox(height: 8),
            Text('Recommended Frequency: ${recommendation['frequency']}'),
            const SizedBox(height: 8),
            Text('Note: ${recommendation['note']}'),
            const SizedBox(height: 16),
            const Text('Based on your baby\'s feeding patterns:'),
            const SizedBox(height: 8),
            if (insights['averageDuration'] != null)
              Text(
                '- Your average feeding duration is ${(insights['averageDuration'] as Duration).inMinutes} minutes. ' +
                (insights['averageDuration'].inMinutes < extractFirstNumber(recommendation['sessionDuration'])! ?
                'Try to extend feeding sessions if possible.' : 'This is within the recommended range.')
              ),
            if (insights['totalFeedings'] != null && minRecommendedFrequency != null)
              Text(
                '- You\'re currently feeding ${insights['totalFeedings']} times per day. ' +
                (insights['totalFeedings'] < minRecommendedFrequency ?
                'Consider increasing feeding frequency if your baby seems hungry.' : 'This is within the recommended range.')
              ),
          ],
        ),
      ),
    );
  }
}

enum TimePeriod { today, lastWeek, lastTwoWeeks }