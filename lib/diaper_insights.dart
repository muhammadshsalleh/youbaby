import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'diaper_entry.dart';  
import 'diaper_tracker_page.dart';  
import 'dart:math' show max, pi;

class DiaperInsightsPage extends StatefulWidget {
  final int userID;
  final VoidCallback navigateToNewEntry;

  const DiaperInsightsPage({
    super.key, 
    required this.userID,  
    required this.navigateToNewEntry,
    }); 

  @override
  _DiaperInsightsPageState createState() => _DiaperInsightsPageState();
}

class _DiaperInsightsPageState extends State<DiaperInsightsPage> {
  bool isLoading = true;
  bool hasError = false;
  String errorMessage = '';
  List<Map<String, dynamic>> diaperEntries = [];
  String selectedTimeRange = 'today';
  int? touchedIndex; // for pie chart touch
  int? colorDistributionTouchedIndex;

  // Statistics
  Map<String, dynamic> stats = {
    'today': {'total': 0, 'poo': 0, 'pee': 0, 'mixed': 0},
    '7days': {'total': 0, 'poo': 0, 'pee': 0, 'mixed': 0},
    '14days': {'total': 0, 'poo': 0, 'pee': 0, 'mixed': 0},
  };
  double averageDiapersPerDay = 0.0;
  int diaperRashOccurrences = 0;
  List<FlSpot> trendData = [];
  Map<String, int> diaperTypeDistribution = {};
  Map<String, int> pooColorDistribution = {};
  Map<String, int> pooTextureDistribution = {};
  Map<int, int> timeOfDayDistribution = {};

  // General color palette for various datasets
  final List<Color> defaultColorPalette = [
    Colors.blue,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.indigo,
    Colors.pink,
    Colors.lime,
  ];

  final List<String> predefinedLabels = [
    'Brown',
    'Yellow',
    'Green',
    'Black',
    'Red',
  ];

  final List<String> poopColors = [
    'Yellow',
    'Red',
    'Green',
    'Brown',
    'Black',
    'White'
  ];

  final List<Color> poopColorValues = [
    const Color.fromARGB(255, 223, 177, 42), // Amber Yellow
    const Color.fromARGB(255, 168, 64, 64), // Muted Red
    const Color.fromARGB(255, 99, 128, 42), // Yellow-Green
    const Color(0xFF8D6E63), // Lighter Brown
    const Color(0xFF424242), // Light Black
    const Color(0xFFFFFFFF), // White
  ];

  final Map<String, Map<String, Color>> chartColors = {
    'timeDistribution': {
      '6am - 12pm': const Color.fromARGB(255, 120, 198, 250), // Light Yellow
      '12pm - 5pm': const Color(0xFFFFEB3B), // Bright Yellow
      '5pm - 8pm': const Color(0xFFFF9800), // Orange
      '8pm - 12am': const Color(0xFF0D47A1), // Dark Blue
      '12am - 6am': const Color(0xFF4A148C),
    },
    'textureDistribution': {
      'Watery': const Color(0xFF29B6F6), // Light Blue
      'Soft': const Color(0xFFAB47BC), // Purple
      'Mixed': const Color(0xFF8BC34A), // Light Green
      'Hard': const Color(0xFFFFB300), // Amber
      'Mucousy': const Color(0xFF009688), // Teal
      // 'Seedy': const Color(0xFFFF5722),       // Deep Orange
    }
  };

  Color getColorForKey(String key, String chartType) {
    if (chartType == 'poopColor') {
      final int predefinedIndex = poopColors.indexOf(key);
      if (predefinedIndex != -1) {
        return poopColorValues[predefinedIndex];
      }
    }

    if (chartColors.containsKey(chartType) &&
        chartColors[chartType]!.containsKey(key)) {
      return chartColors[chartType]![key]!;
    }

    return Colors.grey;
  }

  @override
  void initState() {
    super.initState();
    _fetchDiaperInsights();
  }

  Future<void> _fetchDiaperInsights() async {
    try {
      setState(() {
        isLoading = true;
        hasError = false;
      });

      final response = await Supabase.instance.client
          .from('diaperTracker')
          .select()
          .eq('userID', widget.userID)
          .order('date_time', ascending: true);

      if (response == null || (response as List).isEmpty) {
        setState(() {
          isLoading = false;
          hasError = true;
          errorMessage = 'No diaper entries found';
        });
        return;
      }

      diaperEntries = List<Map<String, dynamic>>.from(response);
      _calculateStatistics();

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        hasError = true;
        errorMessage = 'Error fetching diaper data: $e';
      });
    }
  }

  List<Map<String, dynamic>> _getFilteredEntries() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return diaperEntries.where((entry) {
      final entryDate = DateTime.parse(entry['date_time']);
      final entryDay = DateTime(entryDate.year, entryDate.month, entryDate.day);

      switch (selectedTimeRange) {
        case 'today':
          return entryDay.isAtSameMomentAs(today);
        case '7days':
          return entryDay.isAfter(today.subtract(const Duration(days: 7))) ||
              entryDay
                  .isAtSameMomentAs(today.subtract(const Duration(days: 7)));
        case '14days':
          return entryDay.isAfter(today.subtract(const Duration(days: 14))) ||
              entryDay
                  .isAtSameMomentAs(today.subtract(const Duration(days: 14)));
        default:
          return false;
      }
    }).toList();
  }

  void _calculateStatistics() {
    final filteredEntries = _getFilteredEntries();

    // Reset all statistics
    stats = {
      'today': {'total': 0, 'poo': 0, 'pee': 0, 'mixed': 0},
      '7days': {'total': 0, 'poo': 0, 'pee': 0, 'mixed': 0},
      '14days': {'total': 0, 'poo': 0, 'pee': 0, 'mixed': 0},
    };
    diaperTypeDistribution.clear();
    pooColorDistribution.clear();
    pooTextureDistribution.clear();
    timeOfDayDistribution.clear();
    trendData.clear();
    diaperRashOccurrences = 0;

    if (filteredEntries.isEmpty) return;

    // Calculate type distribution and stats
    for (var entry in filteredEntries) {
      // Update type counts
      final type = entry['type'] as String;
      stats[selectedTimeRange]['total']++;
      stats[selectedTimeRange][type.toLowerCase()]++;

      // Update diaper type distribution
      diaperTypeDistribution[type] = (diaperTypeDistribution[type] ?? 0) + 1;

      // Update time distribution
      final entryTime = DateTime.parse(entry['date_time']);
      final hour = entryTime.hour;
      timeOfDayDistribution[hour] = (timeOfDayDistribution[hour] ?? 0) + 1;

      // Update poo-related distributions if applicable
      if (type.toLowerCase() == 'poo' || type.toLowerCase() == 'mixed') {
        if (entry['poo_color'] != null) {
          final color = entry['poo_color'] as String;
          pooColorDistribution[color] = (pooColorDistribution[color] ?? 0) + 1;
        }
        if (entry['poo_texture'] != null) {
          final texture = entry['poo_texture'] as String;
          pooTextureDistribution[texture] =
              (pooTextureDistribution[texture] ?? 0) + 1;
        }
      }

      // Count diaper rash occurrences
      if (entry['diaper_rash'] == true) {
        diaperRashOccurrences++;
      }
    }

    // Calculate average diapers per day
    final int days = selectedTimeRange == 'today'
        ? 1
        : selectedTimeRange == '7days'
            ? 7
            : 14;
    averageDiapersPerDay = stats[selectedTimeRange]['total'] / days;

    // Calculate daily trends
    Map<DateTime, int> dailyCounts = {};
    for (var entry in filteredEntries) {
      final entryDate = DateTime.parse(entry['date_time']);
      final dateKey = DateTime(entryDate.year, entryDate.month, entryDate.day);
      dailyCounts[dateKey] = (dailyCounts[dateKey] ?? 0) + 1;
    }

    // Create trend data points
    if (selectedTimeRange != 'today') {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final days = selectedTimeRange == '7days' ? 7 : 14;

      for (int i = days - 1; i >= 0; i--) {
        final date = today.subtract(Duration(days: i));
        final count = dailyCounts[date] ?? 0;
        trendData.add(FlSpot((days - 1 - i).toDouble(), count.toDouble()));
      }
    }
  }

  // time range selection
  Widget _buildTimeRangeSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(child: _timeRangeButton('Today', 'today')),
          const SizedBox(width: 8),
          Expanded(child: _timeRangeButton('7 Days', '7days')),
          const SizedBox(width: 8),
          Expanded(child: _timeRangeButton('14 Days', '14days')),
        ],
      ),
    );
  }
  // time range button
  Widget _timeRangeButton(String label, String value) {
    final isSelected = selectedTimeRange == value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() {
          selectedTimeRange = value;
          _calculateStatistics();
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFA91B60) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? const Color(0xFFA91B60) : Colors.grey[300]!,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPieChart() {
    // Calculate total for percentage calculation
    final totalValue = (stats[selectedTimeRange]['poo'] +
            stats[selectedTimeRange]['pee'] +
            stats[selectedTimeRange]['mixed'])
        .toDouble();

    return AspectRatio(
      aspectRatio: 1,
      child: PieChart(
        PieChartData(
          sectionsSpace: 0,
          centerSpaceRadius: 60,
          pieTouchData: PieTouchData(
            touchCallback: (FlTouchEvent event, pieTouchResponse) {
              if (event is FlTapUpEvent || event is FlPointerHoverEvent) {
                final sectionIndex =
                    pieTouchResponse?.touchedSection?.touchedSectionIndex;
                if (sectionIndex != null) {
                  setState(() {
                    touchedIndex = sectionIndex;
                  });
                }
              }
            },
          ),
          sections: [
            _buildPieChartSection(
              value: stats[selectedTimeRange]['poo'].toDouble(),
              title: 'Poo',
              color: const Color(0xFF4285F4),
              index: 0,
              totalValue: totalValue,
            ),
            _buildPieChartSection(
              value: stats[selectedTimeRange]['pee'].toDouble(),
              title: 'Pee',
              color: const Color(0xFF34A853),
              index: 1,
              totalValue: totalValue,
            ),
            _buildPieChartSection(
              value: stats[selectedTimeRange]['mixed'].toDouble(),
              title: 'Mixed',
              color: const Color(0xFFFBBC05),
              index: 2,
              totalValue: totalValue,
            ),
          ],
        ),
      ),
    );
  }

  PieChartSectionData _buildPieChartSection({
    required double value,
    required String title,
    required Color color,
    required int index,
    required double totalValue,
  }) {
    final isTouched = index == touchedIndex;

    // Adjust font size and pie chart size on touch
    final fontSize = isTouched ? 14.0 : 12.0;
    final radius = isTouched ? 63.0 : 60.0;

    // Calculate percentage
    final percentage = totalValue > 0 ? (value / totalValue * 100).round() : 0;

    // Adjust offset based on the index to avoid covering text
    final offset = index % 2 == 0 ? 1.3 : 1.1;

    return PieChartSectionData(
      color: color,
      value: value,
      title: '$title\n$percentage%',
      radius: radius,
      titleStyle: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      badgeWidget: isTouched
          ? Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                '$title\nTotal: ${value.toInt()}\nPercentage: $percentage%',
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
      badgePositionPercentageOffset: offset,
    );
  }

 Widget _buildColorDistributionPieChart(
    Map<String, int> distribution,
    List<String> predefinedLabels,
    List<Color> predefinedColors,
  ) {
    final totalValue =
        distribution.values.fold(0, (sum, count) => sum + count).toDouble();

    // String mostCommonColor =
    //     distribution.entries.reduce((a, b) => a.value > b.value ? a : b).key;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0), // Add horizontal padding
          child: AspectRatio(
            aspectRatio: 1,
            child: PieChart(
              PieChartData(
                sectionsSpace: 0,
                centerSpaceRadius: 0,
                pieTouchData: PieTouchData(
                  touchCallback: (FlTouchEvent event, pieTouchResponse) {
                    if (event is FlTapUpEvent || event is FlPointerHoverEvent) {
                      final sectionIndex =
                          pieTouchResponse?.touchedSection?.touchedSectionIndex;
                      if (sectionIndex != null) {
                        setState(() {
                          colorDistributionTouchedIndex = sectionIndex;
                        });
                      }
                    }
                  },
                ),
                sections: List.generate(predefinedLabels.length, (index) {
                  final label = predefinedLabels[index];
                  final value = (distribution[label] ?? 0).toDouble();
                  return _buildColorDistributionSection(
                    value: value,
                    title: label,
                    color: predefinedColors[index],
                    index: index,
                    totalValue: totalValue,
                  );
                }),
              ),
            ),
          ),
        ),
      ],
    );
  }

  PieChartSectionData _buildColorDistributionSection({
    required double value,
    required String title,
    required Color color,
    required int index,
    required double totalValue,
  }) {
    final isTouched = index == colorDistributionTouchedIndex;
    final fontSize = isTouched ? 13.0 : 12.0;
    final radius = isTouched ? 120.0 : 116.0; // Slightly reduced radius

    final percentage = totalValue > 0 ? (value / totalValue * 100).round() : 0;
    final textColor = (color == Colors.white) ? Colors.black : Colors.white;
    
    // Enhanced badge positioning calculation
    final offset = _calculateBadgeOffset(index, predefinedLabels.length, value, totalValue);

    return PieChartSectionData(
      color: color,
      value: value,
      title: value > 0 ? '$title\n$percentage%' : '',
      radius: radius,
      titleStyle: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w500,
        color: textColor,
      ),
      badgeWidget: isTouched && value > 0
          ? Container(
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints(
                maxWidth: 90, // Reduced max width
                minWidth: 80, // Added min width for consistency
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                '$title\nCount: ${value.toInt()}\nPercentage: $percentage%',
                style: TextStyle(
                  color: color == Colors.white ? Colors.black : color,
                  fontSize: 11, // Slightly reduced font size
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            )
          : null,
      badgePositionPercentageOffset: offset,
    );
  }

  // Enhanced badge offset calculation
  double _calculateBadgeOffset(int index, int totalSections, double value, double totalValue) {
      final angle = (index / totalSections) * 2 * pi;
      final percentage = (value / totalValue) * 100;
      
      // Base offset calculations with adjustments for small sections
      double offset;
      if (angle <= pi / 2) {
          offset = percentage < 10 ? 1.5 : 1.3; // Right side
      } else if (angle <= pi) {
          offset = percentage < 10 ? 1.6 : 1.4; // Bottom
      } else if (angle <= 3 * pi / 2) {
          offset = percentage < 10 ? 1.4 : 1.2; // Left side - Increased offset
      } else {
          offset = percentage < 10 ? 1.3 : 1.1; // Top
      }
      
      // Additional adjustment for Redmi 9C screen size
      if (angle > pi && angle <= 3 * pi / 2) {
          offset += 0.2; // Extra offset for left side to prevent cutoff
      }
      
      return offset;
  }

  // Helper method to get the most common color
String getMostCommonColor(Map<String, int> distribution) {
  if (distribution.isEmpty) return '';
  return distribution.entries
      .reduce((a, b) => a.value > b.value ? a : b)
      .key;
}
// color insigths
Widget _buildColorInsights(String colorRecommendation) {
    return Card(
      color: const Color.fromARGB(255, 255, 228, 241),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lightbulb,
                  color: Color.fromARGB(255, 247, 119, 180),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tips: ${_getColorRecommendation(colorRecommendation)}',
                    style: const TextStyle(
                      fontSize: 13, 
                      fontWeight: FontWeight.w300,
                      height: 1.5,
                      color: Colors.black87,
                      fontFamily: 'Roboto',
                    ),
                    textAlign: TextAlign.justify,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getColorRecommendation(String color) {
    switch (color) {
      case 'Yellow':
        return 'Yellow is common for healthy breastfed babies and typically indicates good digestion.';
      case 'Green':
        return 'Green is usually normal, but may indicate rapid digestion. Monitor if it persists.';
      case 'Brown':
        return 'Brown is typical as babies transition to solid foods and indicates healthy gut bacteria.';
      case 'Red':
        return 'Red may be from food but could indicate blood. Consult a pediatrician if frequent.';
      case 'Black':
        return 'Black can indicate bleeding. Seek medical advice if your baby is not a newborn.';
      case 'White':
        return 'White stool may indicate liver issues. Contact a pediatrician immediately.';
      default:
        return 'No specific insights available.';
    }
  }


  Widget _buildTrendLineChart() {
    if (trendData.isEmpty || selectedTimeRange == 'today') {
      return const Center(child: Text('No trend data available'));
    }

    final totalDays = selectedTimeRange == '14days' ? 14 : 7;
    final now = DateTime.now();

    // Create spots with proper x-axis values
    List<FlSpot> getAdjustedSpots() {
      List<FlSpot> adjustedSpots = [];
      final startDate = now.subtract(Duration(days: totalDays - 1));

      // Convert your existing trend data to a map with date strings as keys
      final dataMap = <String, double>{};
      for (var spot in trendData) {
        final date = now
            .subtract(Duration(days: (trendData.length - 1 - spot.x).toInt()));
        final dateStr = DateFormat('dd/MM').format(date);
        dataMap[dateStr] = spot.y;
      }

      // Create new spots with proper x indices
      for (int i = 0; i < totalDays; i++) {
        final date = startDate.add(Duration(days: i));
        final dateStr = DateFormat('dd/MM').format(date);
        final value = dataMap[dateStr] ?? 0;
        adjustedSpots.add(FlSpot(i.toDouble(), value));
      }

      return adjustedSpots;
    }

    // Get formatted dates for x-axis
    List<String> getFormattedDates() {
      final dates = <String>[];
      final startDate = now.subtract(Duration(days: totalDays - 1));

      for (int i = 0; i < totalDays; i++) {
        final date = startDate.add(Duration(days: i));

        if (selectedTimeRange == '14days') {
          // For 14 days, show date every 2 days (on even days) and always show the last date
          if (i == totalDays - 1 || (i - 1) % 2 == 0) {
            dates.add(DateFormat('dd/MM').format(date));
          } else {
            dates.add(''); // Empty string for odd-numbered days
          }
        } else {
          // For 7 days, show all dates
          dates.add(DateFormat('dd/MM').format(date));
        }
      }
      return dates;
    }

    final formattedDates = getFormattedDates();
    final adjustedSpots = getAdjustedSpots();

    return AspectRatio(
      aspectRatio: 1.6,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: true,
            horizontalInterval: 1,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.grey[200],
                strokeWidth: 1,
              );
            },
            getDrawingVerticalLine: (value) {
              return FlLine(
                color: Colors.grey[200],
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              axisNameWidget: Container(
                margin: const EdgeInsets.only(top: 2),
                child: const Text(
                  'Date',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ),
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < formattedDates.length) {
                    // Only show the label if it's not an empty string
                    if (formattedDates[index].isNotEmpty) {
                      return SideTitleWidget(
                        axisSide: meta.axisSide,
                        child: Text(
                          formattedDates[index],
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      );
                    }
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            // y axis
            leftTitles: AxisTitles(
              axisNameWidget: Container(
                margin: const EdgeInsets.only(bottom: 2),
                child: const Text(
                  'Count',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ),
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text(
                      value.toInt().toString(),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  );
                },
              ),
            ),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border(
              bottom: BorderSide(color: Colors.grey[300]!, width: 1),
              left: BorderSide(color: Colors.grey[300]!, width: 1),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: adjustedSpots,
              isCurved: true,
              color: const Color(0xFF6200EE),
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 4,
                    color: Colors.white,
                    strokeWidth: 2,
                    strokeColor: const Color(0xFF6200EE),
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                color: const Color(0xFF6200EE).withOpacity(0.1),
              ),
            ),
          ],
          minY: 0,
          maxX: (totalDays - 1).toDouble(),
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              tooltipRoundedRadius: 8,
              tooltipPadding: const EdgeInsets.all(8),
              tooltipBorder: const BorderSide(
                color: Colors.blueGrey,
                width: 1,
              ),
              tooltipMargin: 8,
              getTooltipItems: (List<LineBarSpot> touchedSpots) {
                return touchedSpots.map((LineBarSpot touchedSpot) {
                  final date = now.subtract(
                      Duration(days: (totalDays - 1 - touchedSpot.x).toInt()));
                  final dateStr = DateFormat('dd/MM').format(date);
                  return LineTooltipItem(
                    '${dateStr}\nTotal: ${touchedSpot.y.toInt()}',
                    const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                }).toList();
              },
            ),
            handleBuiltInTouches: true,
          ),
        ),
      ),
    );
  }

  dynamic _buildDistributionBarChart(
    Map<String, int> data,
    String title,
    String xAxisLabel,
    String yAxisLabel, {
    String chartType = '',
    List<String>? predefinedLabels,
    List<Color>? predefinedColors,
  }) {
    if (data.isEmpty) {
      return chartType == 'textureDistribution' 
          ? (Center(child: Text('No $title data available')), '')
          : Center(child: Text('No $title data available'));
    }

    // Calculate most common value if it's texture distribution
    String mostCommonValue = '';
    if (chartType == 'textureDistribution') {
      int highestCount = 0;
      data.forEach((texture, count) {
        if (count > highestCount) {
          highestCount = count;
          mostCommonValue = texture;
        }
      });
    }

    final List<BarChartGroupData> barGroups = [];
    final List<String> labels = [];
    int index = 0;

    data.forEach((key, value) {
      labels.add(key);
      final Color barColor = getColorForKey(key, chartType);

      barGroups.add(
        BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: value.toDouble(),
              color: barColor,
              width: 16,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ],
        ),
      );
      index++;
    });

    Widget chart = SizedBox(
      height: 300,
      child: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            barGroups: barGroups,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 1,
              getDrawingHorizontalLine: (value) {
                return FlLine(
                  color: Colors.grey[200],
                  strokeWidth: 1,
                );
              },
            ),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                axisNameWidget: Container(
                  margin: const EdgeInsets.only(top: 2),
                  child: Text(
                    xAxisLabel,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ),
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 44,
                  getTitlesWidget: (value, meta) {
                    if (value < 0 || value >= labels.length)
                      return const Text('');
                    return SideTitleWidget(
                      axisSide: meta.axisSide,
                      child: Container(
                        margin: const EdgeInsets.only(top: 6),
                        width: 50,
                        child: Text(
                          labels[value.toInt()],
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 10,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                        ),
                      ),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                axisNameWidget: Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: Text(
                    yAxisLabel,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ),
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 35,
                  interval: 1,
                  getTitlesWidget: (value, meta) {
                    return SideTitleWidget(
                      axisSide: meta.axisSide,
                      child: Text(
                        value.toInt().toString(),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    );
                  },
                ),
              ),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(
              show: true,
              border: Border(
                bottom: BorderSide(color: Colors.grey[300]!, width: 1),
                left: BorderSide(color: Colors.grey[300]!, width: 1),
              ),
            ),
            maxY: data.values.reduce(max).toDouble() + 1,
            minY: 0,
          ),
        ),
      ),
    );

    // Return type depends on chartType
    return chartType == 'textureDistribution' 
        ? (chart, mostCommonValue)
        : chart;
  }

  String _getTextureAdvice(String texture) {
    switch (texture) {
      case 'Watery':
        return 'Watery stools might indicate possible dehydration risk, changes in the digestive system, or potential infection. Contact your pediatrician if this is persistent or accompanied by other symptoms.';
      case 'Soft':
        return 'Soft stools are typically healthy and indicate good hydration, proper digestion, and adequate nutrition. This is the ideal consistency for most babies.';
      case 'Mixed':
        return 'Mixed consistency can be normal due to dietary changes, developmental transitions, or varying feeding patterns. Monitor for any concerning changes.';
      case 'Hard':
        return 'Hard stools might indicate dehydration, dietary adjustments needed, or possible constipation. Ensure adequate fluid intake and consult your pediatrician if this is persistent.';
      case 'Mucousy':
        return 'Mucousy stools warrant attention as they could indicate mild irritation, possible digestive sensitivity, or dietary-related issues. Contact your pediatrician if this occurs frequently or is accompanied by other symptoms.';
      default:
        return 'Monitor stool consistency and report significant changes to your pediatrician.';
    }
  }

  //texture insights
  Widget _buildTextureInsights(String texture) {
    String textureAdvice = _getTextureAdvice(texture);

    return Card(
      color: const Color.fromARGB(255, 255, 228, 241), // Set the card color
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0), // Optional: Add border radius for a softer look
      ),
      elevation: 2, // Optional: Add elevation for shadow effect
      child: Padding(
        padding: const EdgeInsets.all(16.0), // Padding inside the card
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                 Icons.lightbulb,
                  color: Color.fromARGB(255, 247, 119, 180),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tips: $textureAdvice',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w300,
                      height: 1.5,
                      color: Colors.black87,
                      fontFamily: 'Roboto',
                    ),
                    textAlign: TextAlign.justify,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildTimeDistributionChart() {
    if (timeOfDayDistribution.isEmpty) {
      return const Center(child: Text('No time distribution data available'));
    }

    // Define the order of time slots
    final List<String> orderedTimeSlots = [
      '6am - 12pm',
      '12pm - 5pm',
      '5pm - 8pm',
      '8pm - 12am',
      '12am - 6am',
    ];

    // Convert Map<int, int> to ordered Map<String, int>
    Map<String, int> formattedTimeDistribution =
        Map.fromEntries(orderedTimeSlots.map((slot) => MapEntry(slot, 0)));

    timeOfDayDistribution.forEach((hour, count) {
      String timeLabel = _getTimeSlot(hour);
      formattedTimeDistribution[timeLabel] =
          (formattedTimeDistribution[timeLabel] ?? 0) + count;
    });

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             _buildDistributionBarChart(
              formattedTimeDistribution,
              'Time Distribution',
              'Time of Day',
              'Count',
              chartType: 'timeDistribution',
            ),
            const SizedBox(height: 16),
            
          ],
        ),
      ),
    );
  }

  // Helper method to get formatted time distribution
Map<String, int> getFormattedTimeDistribution() {
    final List<String> orderedTimeSlots = chartColors['timeDistribution']!.keys.toList();
    
    Map<String, int> formattedTimeDistribution =
        Map.fromEntries(orderedTimeSlots.map((slot) => MapEntry(slot, 0)));

    timeOfDayDistribution.forEach((hour, count) {
      String timeLabel = _getTimeSlot(hour);
      formattedTimeDistribution[timeLabel] =
          (formattedTimeDistribution[timeLabel] ?? 0) + count;
    });

    return formattedTimeDistribution;
}

  // time insights
  Widget _buildTimeInsights(Map<String, int> timeDistribution) {
  String peakTime = timeDistribution.entries
      .reduce((a, b) => a.value > b.value ? a : b)
      .key;
  String timeAdvice = _getTimeAdvice(peakTime);

  return Card(
    color: const Color.fromARGB(255, 255, 228, 241),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8.0),
    ),
    elevation: 2,
    child: Padding(
      padding: const EdgeInsets.all(16.0), // Apply uniform padding
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.lightbulb,
                // color: Colors.amber,
                color: Color.fromARGB(255, 247, 119, 180),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tips: $timeAdvice',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w300,
                    height: 1.5,
                    color: Colors.black87,
                    fontFamily: 'Roboto',
                  ),
                  textAlign: TextAlign.justify,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

  String _getTimeAdvice(String peakTime) {
    switch (peakTime) {
      case '6am - 12pm':
        return 'A morning peak is common and healthy. Babies often have more bowel movements in the morning due to natural circadian rhythms, increased morning feeding, and gastrocolic reflex activation. Consider preparing extra supplies for morning changes.';
      case '12pm - 5pm':
        return 'Afternoon activity is normal and may be linked to post-lunch digestion, active feeding periods, and natural digestive patterns. Maintain a regular feeding schedule for consistent patterns.';
      case '5pm - 8pm':
        return 'Evening peaks might be related to cluster feeding periods, pre-bedtime routines, and normal daily rhythms. Consider adjusting evening feeding times if night sleep is affected.';
      case '8pm - 12am':
        return 'Night activity might indicate late feeding patterns, necessary sleep schedule adjustments, and normal nocturnal patterns for young infants. Consider reviewing the bedtime routine if it remains consistent.';
      default:
        return 'Early morning changes are common in newborns. For older babies, consider reviewing the feeding schedule, adjusting the bedtime routine, and ensuring proper night feeding patterns.';
    }
  }

// Helper function to convert hour to time slot string
  String _getTimeSlot(int hour) {
    if (hour >= 0 && hour < 6) return '12am - 6am';
    if (hour >= 6 && hour < 12) return '6am - 12pm';
    if (hour >= 12 && hour < 17) return '12pm - 5pm';
    if (hour >= 17 && hour < 20) return '5pm - 8pm';
    return '8pm - 12am';
  }

  Widget _buildSummaryCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPieChart(),
            const SizedBox(height: 5),
            const Divider(),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(
                      'Total Changes',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      stats[selectedTimeRange]['total'].toString(),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
                // Vertical Divider as Container
                Container(
                  width: 1, // Width of the divider
                  height: 55, // Adjust height as needed
                  color: const Color.fromARGB(255, 207, 207, 207),
                ),

                Column(
                  children: [
                    Text(
                      'Avg Per Day',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      averageDiapersPerDay.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                // Vertical Divider as Container
                Container(
                  width: 1,
                  height: 55,
                  color: const Color.fromARGB(255, 207, 207, 207),
                ),
                // const VerticalDivider(),

                Column(
                  children: [
                    Text(
                      'Rash Cases',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      diaperRashOccurrences.toString(),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (hasError) {
      return Center(
        child: GestureDetector(  // Added child: here
          onTap: widget.navigateToNewEntry,  // Added widget. here
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_circle_outline,
                  size: 48, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No entries found',
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Add your first diaper change',
                style: TextStyle(color: Colors.grey[500], fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          const SizedBox(height: 16),
          _buildTimeRangeSelector(),
          const SizedBox(height: 24),

          // Check if there's no data for selected time range
          if (stats[selectedTimeRange]['total'] == 0)
            Expanded(
              child: Center(
                child: GestureDetector(
                  onTap: widget.navigateToNewEntry,  // Added widget. here
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_circle_outline,
                          size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No entries found',
                        style: TextStyle(color: Colors.grey[600], fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add your first diaper change',
                        style: TextStyle(color: Colors.grey[500], fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Summary',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 16),

                      _buildSummaryCard(),
                      const SizedBox(height: 24),

                      // Trend Chart
                      Text('Trend',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 16),
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey[200]!),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: _buildTrendLineChart(),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Time Distribution Chart
                      Text('Time Distribution',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 16),
                      _buildTimeDistributionChart(),
                      const SizedBox(height: 8),
                      if (timeOfDayDistribution.isNotEmpty)
                        _buildTimeInsights(getFormattedTimeDistribution()),
                      const SizedBox(height: 24),
                   

                     // Color Distribution
                      if (pooColorDistribution.isNotEmpty) ...[
                        Text(
                          'Color Distribution',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey[200]!),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: _buildColorDistributionPieChart(
                              pooColorDistribution,
                              poopColors,
                              poopColorValues,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (pooColorDistribution.isNotEmpty) ...[
                          _buildColorInsights(getMostCommonColor(pooColorDistribution)),  
                        ]
                      ],
                      const SizedBox(height: 24),

                      // Texture Distribution
                      if (pooTextureDistribution.isNotEmpty) ...[
                        Text('Texture Distribution',
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 16),
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey[200]!),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: () {
                              final (chart, mostCommonTexture) = _buildDistributionBarChart(
                                pooTextureDistribution,
                                'Texture Distribution',
                                'Texture',
                                'Count',
                                chartType: 'textureDistribution',
                              );
                              return chart;
                            }(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (pooTextureDistribution.isNotEmpty) ...[
                          _buildTextureInsights(() {
                            final (_, mostCommonTexture) = _buildDistributionBarChart(
                              pooTextureDistribution,
                              'Texture Distribution',
                              'Texture',
                              'Count',
                              chartType: 'textureDistribution',
                            );
                            return mostCommonTexture;
                          }()),
                        ]
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
