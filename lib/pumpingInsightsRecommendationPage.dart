import 'package:flutter/material.dart';

class EnhancedPumpingRecommendations extends StatelessWidget {
  final int babyAgeInMonths;
  final double averageVolumePerSession;
  final int pumpingFrequencyPerDay;

  const EnhancedPumpingRecommendations({
    Key? key,
    required this.babyAgeInMonths,
    required this.averageVolumePerSession,
    required this.pumpingFrequencyPerDay,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pumping Recommendations',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildRecommendationCard(),
            const SizedBox(height: 16),
            _buildDangerLineCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationCard() {
    final (minVolume, maxVolume) = _getRecommendedVolumeRange();
    final recommendedFrequency = _getRecommendedFrequency();

    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recommended Pumping for ${babyAgeInMonths} Month Old',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Volume per session: $minVolume - $maxVolume ml'),
            Text('Frequency: $recommendedFrequency times per day'),
            const SizedBox(height: 8),
            Text(
              'Your average: ${averageVolumePerSession.toStringAsFixed(1)} ml, '
              '$pumpingFrequencyPerDay times per day',
              style: TextStyle(
                color: _isWithinRecommendedRange() ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDangerLineCard() {
    final dangerThreshold = _getDangerThreshold();
    final isInDangerZone = averageVolumePerSession < dangerThreshold;

    return Card(
      color: isInDangerZone ? Colors.red[50] : Colors.green[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isInDangerZone ? 'Warning: Low Milk Production' : 'Milk Production Status',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isInDangerZone ? Colors.red : Colors.green,
              ),
            ),
            const SizedBox(height: 8),
            Text('Danger threshold: $dangerThreshold ml per session'),
            Text(
              'Your average: ${averageVolumePerSession.toStringAsFixed(1)} ml per session',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isInDangerZone ? Colors.red : Colors.green,
              ),
            ),
            if (isInDangerZone) ...[
              const SizedBox(height: 8),
              const Text(
                'Consider consulting with a lactation specialist. '
                'Try increasing pumping frequency and ensure proper nutrition and hydration.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
      ),
    );
  }

  (double, double) _getRecommendedVolumeRange() {
    if (babyAgeInMonths < 1) return (30, 90);
    if (babyAgeInMonths < 3) return (90, 120);
    if (babyAgeInMonths < 6) return (120, 180);
    if (babyAgeInMonths < 12) return (120, 240);
    return (120, 180);
  }

  int _getRecommendedFrequency() {
    if (babyAgeInMonths < 1) return 8;
    if (babyAgeInMonths < 6) return 6;
    return 5;
  }

  double _getDangerThreshold() {
    if (babyAgeInMonths < 1) return 30;
    if (babyAgeInMonths < 3) return 60;
    return 90;
  }

  bool _isWithinRecommendedRange() {
    final (minVolume, maxVolume) = _getRecommendedVolumeRange();
    final recommendedFrequency = _getRecommendedFrequency();
    return averageVolumePerSession >= minVolume &&
           averageVolumePerSession <= maxVolume &&
           pumpingFrequencyPerDay >= recommendedFrequency;
  }
}