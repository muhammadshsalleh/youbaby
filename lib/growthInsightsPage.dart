import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class GrowthInsightsPage extends StatefulWidget {
  final int userId;
  const GrowthInsightsPage({super.key, required this.userId});

  @override
  State<GrowthInsightsPage> createState() => _GrowthInsightsPageState();
}

class _GrowthInsightsPageState extends State<GrowthInsightsPage> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _growthData = [];
  List<Map<String, dynamic>> _filteredData = [];
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  AgeFilter _currentFilter = AgeFilter.year2;  // Default to 0-2 years view

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final userData = await _supabase
          .from('users')
          .select('babyGender, babyBirthday')
          .eq('id', widget.userId)
          .single();

      final growthData = await _supabase
          .from('growthTracker')
          .select()
          .eq('userID', widget.userId)
          .order('created_at');

      setState(() {
        _userData = userData;
        _growthData = List<Map<String, dynamic>>.from(growthData);
        _applyFilter(_currentFilter);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching data: $e');
      setState(() => _isLoading = false);
    }
  }

  void _applyFilter(AgeFilter filter) {
    if (_userData == null) return;

    final birthDate = DateTime.parse(_userData!['babyBirthday']);
    final now = DateTime.now();

    setState(() {
      _currentFilter = filter;
      switch (filter) {
        case AgeFilter.month6:
          final cutoffDate = birthDate.add(const Duration(days: 183)); // ~6 months
          _filteredData = _growthData.where((data) {
            final date = DateTime.parse(data['created_at']);
            return date.isAfter(birthDate) && date.isBefore(cutoffDate);
          }).toList();
          break;
        case AgeFilter.year1:
          final cutoffDate = birthDate.add(const Duration(days: 365)); // 1 year
          _filteredData = _growthData.where((data) {
            final date = DateTime.parse(data['created_at']);
            return date.isAfter(birthDate) && date.isBefore(cutoffDate);
          }).toList();
          break;
        case AgeFilter.year2:
          final cutoffDate = birthDate.add(const Duration(days: 730)); // 2 years
          _filteredData = _growthData.where((data) {
            final date = DateTime.parse(data['created_at']);
            return date.isAfter(birthDate) && date.isBefore(cutoffDate);
          }).toList();
          break;
        case AgeFilter.year5:
          final cutoffDate = birthDate.add(const Duration(days: 1825)); // 5 years
          _filteredData = _growthData.where((data) {
            final date = DateTime.parse(data['created_at']);
            return date.isAfter(birthDate) && date.isBefore(cutoffDate);
          }).toList();
          break;
        case AgeFilter.all:
          _filteredData = List.from(_growthData);
          break;
      }
    });
  }

  List<FlSpot> _getDataSpots(String measurement) {
    if (_filteredData.isEmpty) return [];
    
    // Normalize the data points to make the graph smoother
    final minX = 0.0;
    final maxX = (_filteredData.length - 1).toDouble();
    
    return _filteredData.asMap().entries.map((entry) {
      return FlSpot(
        entry.key.toDouble(),
        entry.value[measurement].toDouble(),
      );
    }).toList();
  }

  Widget _buildFilterChips() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: AgeFilter.values.map((filter) {
            final label = switch (filter) {
              AgeFilter.month6 => '0-6 Months',
              AgeFilter.year1 => '0-1 Year',
              AgeFilter.year2 => '0-2 Years',
              AgeFilter.year5 => '0-5 Years',
              AgeFilter.all => 'All Time',
            };

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(label),
                selected: _currentFilter == filter,
                onSelected: (selected) => _applyFilter(filter),
                selectedColor: Theme.of(context).colorScheme.primaryContainer,
                checkmarkColor: Theme.of(context).colorScheme.primary,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildGrowthChart(String measurement, Color color, String label, String unit) {
    if (_filteredData.isEmpty) {
      return _buildEmptyState();
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        height: 300,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  unit,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 5,
                  ),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: _filteredData.length > 7 ? 2 : 1,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= _filteredData.length) {
                            return const Text('');
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              DateFormat('MMM d').format(
                                DateTime.parse(_filteredData[value.toInt()]['created_at']),
                              ),
                              style: TextStyle(
                                fontSize: 10,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        interval: 10,
                      ),
                    ),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _getDataSpots(measurement),
                      color: color,
                      isCurved: true,
                      curveSmoothness: 0.35,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 6,
                            color: Colors.white,
                            strokeWidth: 2,
                            strokeColor: color,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            color.withOpacity(0.3),
                            color.withOpacity(0.0),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      //tooltipBgColor: Theme.of(context).colorScheme.surface,
                      tooltipRoundedRadius: 8,
                      getTooltipItems: (List<LineBarSpot> spots) {
                        return spots.map((spot) {
                          final data = _filteredData[spot.x.toInt()];
                          return LineTooltipItem(
                            '${data[measurement]} $unit\n${DateFormat('MMM d, yyyy').format(DateTime.parse(data['created_at']))}',
                            TextStyle(color: Theme.of(context).colorScheme.onSurface),
                          );
                        }).toList();
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    if (_filteredData.isEmpty) return const SizedBox.shrink();

    final latestRecord = _filteredData.last;
    final previousRecord = _filteredData.length > 1 
        ? _filteredData[_filteredData.length - 2] 
        : null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current Growth Stats',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  icon: Icons.monitor_weight_outlined,
                  label: 'Weight',
                  value: '${latestRecord['weight']}',
                  unit: 'kg',
                  change: previousRecord != null
                      ? (latestRecord['weight'] - previousRecord['weight']).toStringAsFixed(1)
                      : null,
                ),
                _buildStatItem(
                  icon: Icons.height,
                  label: 'Height',
                  value: '${latestRecord['height']}',
                  unit: 'cm',
                  change: previousRecord != null
                      ? (latestRecord['height'] - previousRecord['height']).toStringAsFixed(1)
                      : null,
                ),
                _buildStatItem(
                  icon: Icons.show_chart,
                  label: 'Percentile',
                  value: '${latestRecord['growthPercentile']}',
                  unit: '%',
                  change: null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required String unit,
    String? change,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          size: 24,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        RichText(
          text: TextSpan(
            style: Theme.of(context).textTheme.headlineSmall,
            children: [
              TextSpan(text: value),
              TextSpan(
                text: ' $unit',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (change != null) ...[
          const SizedBox(height: 4),
          Text(
            '${double.parse(change) >= 0 ? '+' : ''}$change',
            style: TextStyle(
              color: double.parse(change) >= 0 ? Colors.green : Colors.red,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEmptyState() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        height: 300,
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.show_chart,
                size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                'No growth data available',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Add measurements to see your baby\'s growth chart',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      // appBar: AppBar(
      //   title: const Text('Growth Insights'),
      //   actions: [
      //     IconButton(
      //       icon: const Icon(Icons.info_outline),
      //       onPressed: () {
      //         // Show WHO guidelines info dialog
      //         showDialog(
      //           context: context,
      //           builder: (context) => AlertDialog(
      //             title: const Text('About Growth Charts'),
      //             content: const Text(
      //               'These growth charts are based on WHO Child Growth Standards, which describe normal child growth from birth to 5 years. The charts show how your child grows compared to children of the same age and sex.'
      //             ),
      //             actions: [
      //               TextButton(
      //                 child: const Text('Close'),
      //                 onPressed: () => Navigator.of(context).pop(),
      //               ),
      //             ],
      //           ),
      //         );
      //       },
      //     ),
      //   ],
      // ),
      body: RefreshIndicator(
        onRefresh: _fetchData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFilterChips(),
              _buildStatsCard(),
              _buildGrowthChart('weight', Colors.blue, 'Weight Progress', 'kg'),
              _buildGrowthChart('height', Colors.green, 'Height Progress', 'cm'),
            ],
          ),
        ),
      ),
    );
  }
}

enum AgeFilter {
  month6,    // 0-6 months
  year1,     // 0-1 year
  year2,     // 0-2 years
  year5,     // 0-5 years
  all        // All time
}