import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class GrowthTrackerPage extends StatefulWidget {
  final int userId;
  const GrowthTrackerPage({super.key, required this.userId});

  @override
  State<GrowthTrackerPage> createState() => _GrowthTrackerPageState();
}

class _GrowthTrackerPageState extends State<GrowthTrackerPage> {
  double heightValue = 50.0;
  double weightValue = 3.0;
  DateTime selectedDate = DateTime.now();
  String babyName = '';
  DateTime? babyBirthday;
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  final TextEditingController noteController = TextEditingController();
  List<Map<String, dynamic>> growthHistory = [];
  Map<String, dynamic>? lastMeasurement;
  int activeStep = 0;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    noteController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final userResponse = await supabase
          .from('users')
          .select('babyName, babyBirthday')
          .eq('id', widget.userId)
          .single();
      
      final historyResponse = await supabase
          .from('growthTracker')
          .select()
          .eq('userID', widget.userId)
          .order('created_at', ascending: false)
          .limit(10);

      setState(() {
        babyName = userResponse['babyName'] ?? 'Baby';
        if (userResponse['babyBirthday'] != null) {
          babyBirthday = DateTime.parse(userResponse['babyBirthday']);
        }
        
        growthHistory = List<Map<String, dynamic>>.from(historyResponse);
        if (growthHistory.isNotEmpty) {
          lastMeasurement = growthHistory.first;
          heightValue = lastMeasurement!['height']?.toDouble() ?? 50.0;
          weightValue = lastMeasurement!['weight']?.toDouble() ?? 3.0;
        }
        
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading data: $e');
      setState(() => isLoading = false);
    }
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFA91B60), Color(0xFFD4317C)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Growth Tracker',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Track ${babyName}\'s growth journey',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          if (lastMeasurement != null) ...[
            const SizedBox(height: 20),
            _buildGrowthSummaryCards(),
          ],
        ],
      ),
    );
  }

  Widget _buildGrowthSummaryCards() {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            'Height Growth',
            '${lastMeasurement!['heightDelta']?.toStringAsFixed(1) ?? '0.0'} cm',
            Icons.trending_up,
            (lastMeasurement!['heightDelta'] ?? 0.0).toDouble() > 0,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSummaryCard(
            'Weight Gain',
            '${lastMeasurement!['weightDelta']?.toStringAsFixed(1) ?? '0.0'} kg',
            Icons.monitor_weight,
            (lastMeasurement!['weightDelta'] ?? 0.0).toDouble() > 0,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, bool isPositive) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: () async {
            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: selectedDate,
              firstDate: babyBirthday ?? DateTime(2020),
              lastDate: DateTime.now(),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.light(
                      primary: Color(0xFFA91B60),
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (picked != null && picked != selectedDate) {
              setState(() => selectedDate = picked);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF0F7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.calendar_today,
                        color: Color(0xFFA91B60),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Measurement Date',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('MMMM d, yyyy').format(selectedDate),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMeasurementCard(String title, IconData icon, String value, String unit, Widget slider) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF0F7),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            icon,
                            color: const Color(0xFFA91B60),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF0F7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$value $unit',
                        style: const TextStyle(
                          color: Color(0xFFA91B60),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                slider,
                if (lastMeasurement != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Previous: ${title == 'Height' ? lastMeasurement!['height']?.toStringAsFixed(1) : lastMeasurement!['weight']?.toStringAsFixed(1)} $unit',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // if (growthHistory.isNotEmpty) ...[
          //   Container(
          //     height: 100,
          //     padding: const EdgeInsets.all(16),
          //     child: _buildMiniChart(title.toLowerCase()),
          //   ),
          // ],
        ],
      ),
    );
  }

  // Widget _buildMiniChart(String metric) {
  //   final List<FlSpot> spots = growthHistory.asMap().entries.map((entry) {
  //     return FlSpot(
  //       entry.key.toDouble(),
  //       entry.value[metric]?.toDouble() ?? 0.0,
  //     );
  //   }).toList();

  //   return LineChart(
  //     LineChartData(
  //       gridData: FlGridData(show: false),
  //       titlesData: FlTitlesData(show: false),
  //       borderData: FlBorderData(show: false),
  //       lineBarsData: [
  //         LineChartBarData(
  //           spots: spots,
  //           isCurved: true,
  //           color: const Color(0xFFA91B60),
  //           barWidth: 2,
  //           dotData: FlDotData(show: false),
  //           belowBarData: BarAreaData(
  //             show: true,
  //             color: const Color(0xFFA91B60).withOpacity(0.1),
  //           ),
  //         ),
  //       ],
  //       minY: spots.map((spot) => spot.y).reduce((a, b) => a < b ? a : b) * 0.9,
  //       maxY: spots.map((spot) => spot.y).reduce((a, b) => a > b ? a : b) * 1.1,
  //     ),
  //   );
  // }

  Widget _buildNotesSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0F7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.note,
                    color: Color(0xFFA91B60),
                  ),
                ),
                const SizedBox(width: 15),
                const Text(
                  'Notes & Observations',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: noteController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Add any important observations...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                filled: true,
                fillColor: const Color(0xFFFFF0F7),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: ElevatedButton(
        onPressed: _saveGrowthData,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFA91B60),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          minimumSize: const Size(double.infinity, 50),
        ),
        child: const Text(
          'Save Measurement',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isLoading
          ? const Center(child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFA91B60)),
            ))
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildHeader()),
                SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 20),
                    _buildDateSelector(),
                    const SizedBox(height: 20),
                    _buildMeasurementCard(
                      'Height',
                      Icons.height,
                      heightValue.toStringAsFixed(1),
                      'cm',
                      _buildCustomSlider(
                        heightValue,
                        30.0,
                        120.0,
                        90,
                        (value) => setState(() => heightValue = value),
                      ),
                    ),
                    _buildMeasurementCard(
                      'Weight',
                      Icons.monitor_weight,
                      weightValue.toStringAsFixed(1),
                      'kg',
                      _buildCustomSlider(
                        weightValue,
                        2.0,
                        20.0,
                        180,
                        (value) => setState(() => weightValue = value),
                      ),
                    ),
                    _buildNotesSection(),
                    _buildSaveButton(),
                    const SizedBox(height: 20),
                  ]),
                ),
              ],
            ),
    );
  }

  Widget _buildCustomSlider(
    double value,
    double min,
    double max,
    int divisions,
    ValueChanged<double> onChanged,
  ) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor: const Color(0xFFA91B60),
        inactiveTrackColor: const Color(0xFFFFF0F7),
        thumbColor: const Color(0xFFA91B60),
        overlayColor: const Color(0xFFA91B60).withOpacity(0.2),
        valueIndicatorColor: const Color(0xFFA91B60),
        valueIndicatorTextStyle: const TextStyle(color: Colors.white),
        trackHeight: 6.0,
        thumbShape: const RoundSliderThumbShape(
          enabledThumbRadius: 12,
          elevation: 4,
        ),
        overlayShape: const RoundSliderOverlayShape(
          overlayRadius: 24,
        ),
      ),
      child: Slider(
        value: value,
        min: min,
        max: max,
        divisions: divisions,
        label: value.toStringAsFixed(1),
        onChanged: onChanged,
      ),
    );
  }

  Future<void> _saveGrowthData() async {
    try {
      setState(() => isLoading = true);

      final metrics = await _calculateGrowthMetrics(heightValue, weightValue);

      await supabase.from('growthTracker').insert({
        'userID': widget.userId,
        'height': heightValue,
        'weight': weightValue,
        'note': noteController.text,
        'created_at': selectedDate.toIso8601String(),
        'growthPercentile': metrics['growthPercentile'],
        'heightDelta': metrics['heightDelta'],
        'weightDelta': metrics['weightDelta'],
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 10),
                Text('Growth entry saved successfully!'),
              ],
            ),
            backgroundColor: const Color(0xFFA91B60),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(20),
          ),
        );
        noteController.clear();
        await _loadInitialData();
      }
    } catch (e) {
      debugPrint('Error saving data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 10),
                Text('Error saving data: $e'),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(20),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<Map<String, double>> _calculateGrowthMetrics(double height, double weight) async {
    try {
      double heightDelta = 0;
      double weightDelta = 0;
      double growthPercentile = 50.0;

      if (lastMeasurement != null) {
        heightDelta = height - (lastMeasurement!['height']?.toDouble() ?? height);
        weightDelta = weight - (lastMeasurement!['weight']?.toDouble() ?? weight);
      }
      
      if (babyBirthday != null) {
        final ageInMonths = DateTime.now().difference(babyBirthday!).inDays / 30.44;
        growthPercentile = _calculateSimplePercentile(height, weight, ageInMonths);
      }

      return {
        'heightDelta': heightDelta,
        'weightDelta': weightDelta,
        'growthPercentile': growthPercentile,
      };
    } catch (e) {
      debugPrint('Error calculating growth metrics: $e');
      return {
        'heightDelta': 0,
        'weightDelta': 0,
        'growthPercentile': 50.0,
      };
    }
  }

  double _calculateSimplePercentile(double height, double weight, double ageInMonths) {
    // This is a simplified calculation - in a real app, you'd want to use WHO or CDC growth charts
    final expectedHeight = 45 + (ageInMonths * 2); // Simplified growth curve
    final expectedWeight = 3 + (ageInMonths * 0.5); // Simplified growth curve
    
    final heightDiff = (height - expectedHeight).abs();
    final weightDiff = (weight - expectedWeight).abs();
    
    final heightPercentile = 100 - (heightDiff / expectedHeight * 100);
    final weightPercentile = 100 - (weightDiff / expectedWeight * 100);
    
    return (heightPercentile + weightPercentile) / 2.clamp(0, 100);
  }
}