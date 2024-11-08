import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';

class GrowthInsightsPage extends StatefulWidget {
  final int userId;
  
  const GrowthInsightsPage({
    super.key, 
    required this.userId,
  });

  @override
  State<GrowthInsightsPage> createState() => _GrowthInsightsPageState();
}

class _GrowthInsightsPageState extends State<GrowthInsightsPage> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  List<Map<String, dynamic>> growthData = [];
  Map<String, dynamic>? userData;
  String? babyName;
  String? babyGender;
  DateTime? babyBirthday;

  // WHO Standard Data (simplified example - you should replace with complete WHO data)
  final Map<String, Map<String, List<double>>> whoStandards = {
    'male': {
      'height': [
        49.9, 54.7, 58.4, 61.4, 63.9, 65.9, // 0-5 months
        67.6, 69.2, 70.6, 72.0, 73.3, 74.5, // 6-11 months
      ],
      'heightP3': [
        48.0, 52.8, 56.4, 59.4, 61.9, 63.9, // 0-5 months lower bound
        65.6, 67.2, 68.6, 70.0, 71.3, 72.5, // 6-11 months lower bound
      ],
      'heightP97': [
        51.8, 56.7, 60.4, 63.4, 65.9, 67.9, // 0-5 months upper bound
        69.6, 71.2, 72.6, 74.0, 75.3, 76.5, // 6-11 months upper bound
      ],
      'weight': [
        3.3, 4.5, 5.6, 6.4, 7.0, 7.5, // 0-5 months
        7.9, 8.3, 8.6, 8.9, 9.2, 9.4, // 6-11 months
      ],
      'weightP3': [
        2.9, 4.0, 5.1, 5.8, 6.4, 6.9, // 0-5 months lower bound
        7.3, 7.7, 8.0, 8.3, 8.6, 8.8, // 6-11 months lower bound
      ],
      'weightP97': [
        3.9, 5.2, 6.3, 7.2, 7.8, 8.3, // 0-5 months upper bound
        8.7, 9.1, 9.4, 9.7, 10.0, 10.2, // 6-11 months upper bound
      ],
    },
    'female': { /// female data need to checked
      'height': [
        49.1, 53.7, 57.1, 59.8, 62.1, 64.0, // 0-5 months
        65.7, 67.3, 68.7, 70.1, 71.5, 72.8, // 6-11 months
      ],
      'heightP3': [
        47.3, 51.7, 55.0, 57.7, 59.9, 61.8, // 0-5 months lower bound
        63.5, 65.1, 66.5, 67.9, 69.3, 70.6, // 6-11 months lower bound
      ],
      'heightP97': [
        51.8, 56.7, 60.4, 63.4, 65.9, 67.9, // 0-5 months upper bound
        69.6, 71.2, 72.6, 74.0, 75.3, 76.5, // 6-11 months upper bound
      ],
      'weight': [
        3.3, 4.5, 5.6, 6.4, 7.0, 7.5, // 0-5 months
        7.9, 8.3, 8.6, 8.9, 9.2, 9.4, // 6-11 months
      ],
      'weightP3': [
        2.9, 4.0, 5.1, 5.8, 6.4, 6.9, // 0-5 months lower bound
        7.3, 7.7, 8.0, 8.3, 8.6, 8.8, // 6-11 months lower bound
      ],
      'weightP97': [
        3.9, 5.2, 6.3, 7.2, 7.8, 8.3, // 0-5 months upper bound
        8.7, 9.1, 9.4, 9.7, 10.0, 10.2, // 6-11 months upper bound
      ],
    },
  };

  @override
  void initState() {
    super.initState();
    _loadUserAndGrowthData();
  }

  Future<void> _loadUserAndGrowthData() async {
    try {
      // First fetch user data to get baby details
      final userResponse = await supabase
          .from('users')
          .select()
          .eq('id', widget.userId)
          .single();
      
      if (userResponse != null) {
        setState(() {
          userData = userResponse;
          babyName = userResponse['babyName'];
          babyGender = userResponse['babyGender']?.toLowerCase();
          babyBirthday = DateTime.parse(userResponse['babyBirthday']);
        });
      }

      // Then fetch growth data
      final growthResponse = await supabase
          .from('growthTracker')
          .select()
          .eq('userID', widget.userId)
          .order('created_at', ascending: true);

      // Process growth data to include age in months
      final processedGrowthData = List<Map<String, dynamic>>.from(growthResponse)
          .map((entry) {
        final measurementDate = DateTime.parse(entry['created_at']);
        final ageInMonths = _calculateAgeInMonths(babyBirthday!, measurementDate);
        return {
          ...entry,
          'ageInMonths': ageInMonths,
        };
      }).toList();

      setState(() {
        growthData = processedGrowthData;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading data: $e');
      setState(() => isLoading = false);
    }
  }

  int _calculateAgeInMonths(DateTime birthDate, DateTime currentDate) {
    int months = (currentDate.year - birthDate.year) * 12 +
        currentDate.month -
        birthDate.month;
    
    // Adjust for day of month
    if (currentDate.day < birthDate.day) {
      months--;
    }
    
    return months;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (userData == null || babyGender == null || babyBirthday == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.warning, size: 48, color: Colors.orange),
              const SizedBox(height: 16),
              const Text(
                'Baby information not found',
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                'Please complete your baby\'s profile first',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBabyInfo(),
            const SizedBox(height: 24),
            _buildHeightChart(),
            const SizedBox(height: 24),
            _buildWeightChart(),
            const SizedBox(height: 24),
            _buildGrowthSummary(),
          ],
        ),
      ),
    );
  }

  Widget _buildBabyInfo() {
    final age = _calculateAgeInMonths(babyBirthday!, DateTime.now());
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              babyName ?? 'Baby',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Age: ${age < 12 ? "$age months" : "${(age / 12).floor()} years ${age % 12} months"}',
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              'Gender: ${babyGender?.substring(0, 1).toUpperCase()}${babyGender?.substring(1)}',
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              'Birthday: ${babyBirthday?.toString().split(' ')[0]}',
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeightChart() {
  if (growthData.isEmpty || babyGender == null || 
      !whoStandards.containsKey(babyGender) ||
      whoStandards[babyGender]?['height'] == null) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text('No height data available yet.'),
      ),
    );
  }

  final standards = whoStandards[babyGender]!;
  final heightData = standards['height'] ?? [];
  final heightP3Data = standards['heightP3'] ?? [];
  final heightP97Data = standards['heightP97'] ?? [];

  return Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Height Growth',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 300,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: true),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text('${value.toInt()} mo');
                      },
                      reservedSize: 30,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text('${value.toInt()} cm');
                      },
                      reservedSize: 40,
                    ),
                  ),
                ),
                borderData: FlBorderData(show: true),
                lineBarsData: [
                  // Actual height data
                  LineChartBarData(
                    spots: List.generate(growthData.length, (index) {
                      return FlSpot(
                        growthData[index]['ageInMonths'].toDouble(),
                        growthData[index]['height'].toDouble(),
                      );
                    }),
                    isCurved: true,
                    color: Colors.blue,
                    dotData: FlDotData(show: true),
                  ),
                  // WHO median line
                  if (heightData.isNotEmpty) LineChartBarData(
                    spots: List.generate(
                      heightData.length,
                      (index) => FlSpot(
                        index.toDouble(),
                        heightData[index],
                      ),
                    ),
                    isCurved: true,
                    color: Colors.green,
                    dotData: FlDotData(show: false),
                    dashArray: [5, 5],
                  ),
                  // WHO P3 line
                  if (heightP3Data.isNotEmpty) LineChartBarData(
                    spots: List.generate(
                      heightP3Data.length,
                      (index) => FlSpot(
                        index.toDouble(),
                        heightP3Data[index],
                      ),
                    ),
                    isCurved: true,
                    color: Colors.orange,
                    dotData: FlDotData(show: false),
                    dashArray: [5, 5],
                  ),
                  // WHO P97 line
                  if (heightP97Data.isNotEmpty) LineChartBarData(
                    spots: List.generate(
                      heightP97Data.length,
                      (index) => FlSpot(
                        index.toDouble(),
                        heightP97Data[index],
                      ),
                    ),
                    isCurved: true,
                    color: Colors.orange,
                    dotData: FlDotData(show: false),
                    dashArray: [5, 5],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Legend
          Wrap(
            spacing: 16,
            children: [
              _buildLegendItem('Your Baby', Colors.blue),
              _buildLegendItem('WHO Median', Colors.green),
              _buildLegendItem('WHO Range', Colors.orange),
            ],
          ),
        ],
      ),
    ),
  );
}

  Widget _buildWeightChart() {
  if (growthData.isEmpty || babyGender == null || 
      !whoStandards.containsKey(babyGender) ||
      whoStandards[babyGender]?['weight'] == null) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text('No weight data available yet.'),
      ),
    );
  }

  final standards = whoStandards[babyGender]!;
  final weightData = standards['weight'] ?? [];
  final weightP3Data = standards['weightP3'] ?? [];
  final weightP97Data = standards['weightP97'] ?? [];

  return Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Weight Growth',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 300,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: true),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text('${value.toInt()} mo');
                      },
                      reservedSize: 30,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text('${value.toInt()} kg');
                      },
                      reservedSize: 40,
                    ),
                  ),
                ),
                borderData: FlBorderData(show: true),
                lineBarsData: [
                  // Actual weight data
                  LineChartBarData(
                    spots: List.generate(growthData.length, (index) {
                      return FlSpot(
                        growthData[index]['ageInMonths'].toDouble(),
                        growthData[index]['weight'].toDouble(),
                      );
                    }),
                    isCurved: true,
                    color: Colors.blue,
                    dotData: FlDotData(show: true),
                  ),
                  // WHO median line
                  if (weightData.isNotEmpty) LineChartBarData(
                    spots: List.generate(
                      weightData.length,
                      (index) => FlSpot(
                        index.toDouble(),
                        weightData[index],
                      ),
                    ),
                    isCurved: true,
                    color: Colors.green,
                    dotData: FlDotData(show: false),
                    dashArray: [5, 5],
                  ),
                  // WHO P3 line
                  if (weightP3Data.isNotEmpty) LineChartBarData(
                    spots: List.generate(
                      weightP3Data.length,
                      (index) => FlSpot(
                        index.toDouble(),
                        weightP3Data[index],
                      ),
                    ),
                    isCurved: true,
                    color: Colors.orange,
                    dotData: FlDotData(show: false),
                    dashArray: [5, 5],
                  ),
                  // WHO P97 line
                  if (weightP97Data.isNotEmpty) LineChartBarData(
                    spots: List.generate(
                      weightP97Data.length,
                      (index) => FlSpot(
                        index.toDouble(),
                        weightP97Data[index],
                      ),
                    ),
                    isCurved: true,
                    color: Colors.orange,
                    dotData: FlDotData(show: false),
                    dashArray: [5, 5],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Legend
          Wrap(
            spacing: 16,
            children: [
              _buildLegendItem('Your Baby', Colors.blue),
              _buildLegendItem('WHO Median', Colors.green),
              _buildLegendItem('WHO Range', Colors.orange),
            ],
          ),
        ],
      ),
    ),
  );
}

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 2,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(label),
      ],
    );
  }

  Widget _buildGrowthSummary() {
    if (growthData.isEmpty) return const SizedBox.shrink();

    final latestEntry = growthData.last;
    final firstEntry = growthData.first;
    final ageInMonths = latestEntry['ageInMonths'] as int;

    final totalHeightGain = latestEntry['height'] - firstEntry['height'];
    final totalWeightGain = latestEntry['weight'] - firstEntry['weight'];
    
    // Safely get WHO standards for comparison
    double? whoHeight;
    double? whoWeight;
    
    if (babyGender != null && ageInMonths <= 11) {
      final standards = whoStandards[babyGender];
      if (standards != null) {
        final heightData = standards['height'];
        final weightData = standards['weight'];
        
        if (heightData != null && heightData.length > ageInMonths) {
          whoHeight = heightData[ageInMonths];
        }
        
        if (weightData != null && weightData.length > ageInMonths) {
          whoWeight = weightData[ageInMonths];
        }
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Growth Summary',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text('Current Height: ${latestEntry['height'].toStringAsFixed(1)} cm'),
            if (whoHeight != null)
              Text('WHO Expected Height: ${whoHeight.toStringAsFixed(1)} cm')
            else if (ageInMonths > 11)
              const Text(
                'WHO height data only available for ages 0-12 months',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            const SizedBox(height: 8),
            Text('Current Weight: ${latestEntry['weight'].toStringAsFixed(1)} kg'),
            if (whoWeight != null)
              Text('WHO Expected Weight: ${whoWeight.toStringAsFixed(1)} kg')
            else if (ageInMonths > 11)
              const Text(
                'WHO weight data only available for ages 0-12 months',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            const SizedBox(height: 8),
            Text('Total Height Gain: ${totalHeightGain.toStringAsFixed(1)} cm'),
            Text('Total Weight Gain: ${totalWeightGain.toStringAsFixed(1)} kg'),
          ],
        ),
      ),
    );
}
}