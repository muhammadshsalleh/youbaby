import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:youbaby/growthTrackerNavigation.dart';

class GrowthHistoryPage extends StatefulWidget {
  final int userId;
  const GrowthHistoryPage({super.key, required this.userId});

  @override
  State<GrowthHistoryPage> createState() => _GrowthHistoryPageState();
}

class _GrowthHistoryPageState extends State<GrowthHistoryPage> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  List<Map<String, dynamic>> growthHistory = [];
  String selectedPeriod = 'All Time'; 

  // Controllers for updating entries
  final TextEditingController heightController = TextEditingController();
  final TextEditingController weightController = TextEditingController();
  final TextEditingController noteController = TextEditingController();


  final List<String> timePeriods = [
    'All Time',
    'Today',
    'Yesterday',
    '7 Days',
    '14 Days',
  ];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    heightController.dispose();
    weightController.dispose();
    noteController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _filterEntriesByPeriod() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (selectedPeriod) {
      case 'Today':
        return growthHistory.where((entry) {
          final entryDate = DateTime.parse(entry['created_at']).toLocal();
          return DateTime(entryDate.year, entryDate.month, entryDate.day).isAtSameMomentAs(today);
        }).toList();
      
      case 'Yesterday':
        final yesterday = today.subtract(const Duration(days: 1));
        return growthHistory.where((entry) {
          final entryDate = DateTime.parse(entry['created_at']).toLocal();
          return DateTime(entryDate.year, entryDate.month, entryDate.day).isAtSameMomentAs(yesterday);
        }).toList();
      
      case '7 Days':
        final sevenDaysAgo = today.subtract(const Duration(days: 7));
        return growthHistory.where((entry) {
          final entryDate = DateTime.parse(entry['created_at']).toLocal();
          return entryDate.isAfter(sevenDaysAgo) || entryDate.isAtSameMomentAs(sevenDaysAgo);
        }).toList();
      
      case '14 Days':
        final fourteenDaysAgo = today.subtract(const Duration(days: 14));
        return growthHistory.where((entry) {
          final entryDate = DateTime.parse(entry['created_at']).toLocal();
          return entryDate.isAfter(fourteenDaysAgo) || entryDate.isAtSameMomentAs(fourteenDaysAgo);
        }).toList();
      
      default: // 'All Time'
        return growthHistory;
    }
  }

  Future<void> _loadHistory() async {
    try {
      final response = await supabase
          .from('growthTracker')
          .select()
          .eq('userID', widget.userId)
          .order('created_at', ascending: false);

      setState(() {
        growthHistory = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading history: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> _deleteEntry(int entryId) async {
    try {
      await supabase
          .from('growthTracker')
          .delete()
          .eq('id', entryId);
      
      await _loadHistory();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Entry deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting entry: $e')),
        );
      }
    }
  }

  Future<void> _updateEntry(Map<String, dynamic> entry) async {
    heightController.text = entry['height'].toString();
    weightController.text = entry['weight'].toString();
    noteController.text = entry['note'] ?? '';

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Growth Record'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: heightController,
                decoration: const InputDecoration(labelText: 'Height (cm)'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: weightController,
                decoration: const InputDecoration(labelText: 'Weight (kg)'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(labelText: 'Note'),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                await supabase
                    .from('growthTracker')
                    .update({
                      'height': double.parse(heightController.text),
                      'weight': double.parse(weightController.text),
                      'note': noteController.text,
                    })
                    .eq('id', entry['id']);
                
                if (mounted) {
                  Navigator.pop(context);
                  await _loadHistory();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Entry updated successfully')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error updating entry: $e')),
                  );
                }
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.child_care,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No growth records yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimePeriodSelector() {
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: timePeriods.length,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemBuilder: (context, index) {
          final period = timePeriods[index];
          final isSelected = selectedPeriod == period;
          
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(period),
              selected: isSelected,
              selectedColor: Colors.pink[100],
              backgroundColor: Colors.grey[200],
              onSelected: (selected) {
                if (selected) {
                  setState(() => selectedPeriod = period);
                }
              },
            ),
          );
        },
      ),
    );
  }

 Widget _buildHistoryCard(Map<String, dynamic> entry) {
    final date = DateTime.parse(entry['created_at']);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showDetailsDialog(entry),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDateRow(date),
                  const SizedBox(height: 16),
                  _buildMetricsRow(entry),
                  if (entry['note']?.isNotEmpty ?? false) ...[
                    const SizedBox(height: 16),
                    _buildNoteSection(entry['note']),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateRow(DateTime date) {
    return Row(
      children: [
        Icon(
          Icons.calendar_today,
          size: 20,
          color: Colors.pink[300],
        ),
        const SizedBox(width: 8),
        Text(
          DateFormat('d MMMM, yyyy').format(date),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  void _showDetailsDialog(Map<String, dynamic> entry) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Growth Record Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Date', DateFormat('d MMMM, yyyy HH:mm').format(
                DateTime.parse(entry['created_at']).toLocal()
              )),
              const SizedBox(height: 16),
              _buildDetailRow('Height', '${entry['height']} cm'),
              const SizedBox(height: 8),
              _buildDetailRow('Weight', '${entry['weight']} kg'),
              if (entry['note']?.isNotEmpty ?? false) ...[
                const SizedBox(height: 16),
                const Text(
                  'Notes:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Text(entry['note']),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: Text(value),
        ),
      ],
    );
  }

  Widget _buildHistoryList() {
    final filteredEntries = _filterEntriesByPeriod();
    
    if (filteredEntries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No records found for this period',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredEntries.length,
      itemBuilder: (context, index) => _buildDismissibleCard(filteredEntries[index]),
    );
  }

  Widget _buildDismissibleCard(Map<String, dynamic> entry) {
    return Dismissible(
      key: Key(entry['id'].toString()),
      background: _buildDismissBackground(
        icon: Icons.edit,
        label: 'Edit',
        color: Colors.blue,
        alignment: Alignment.centerLeft,
      ),
      secondaryBackground: _buildDismissBackground(
        icon: Icons.delete,
        label: 'Delete',
        color: Colors.red,
        alignment: Alignment.centerRight,
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Update action
          await _updateEntry(entry);
          return false;
        } else {
          // Delete action
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Delete Entry'),
              content: const Text('Are you sure you want to delete this entry?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Delete'),
                ),
              ],
            ),
          );
          if (confirmed == true) {
            await _deleteEntry(entry['id']);
          }
          return confirmed ?? false;
        }
      },
      child: _buildHistoryCard(entry),
    );
  }

  Widget _buildDismissBackground({
    required IconData icon,
    required String label,
    required Color color,
    required Alignment alignment,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: alignment == Alignment.centerLeft 
            ? MainAxisAlignment.start 
            : MainAxisAlignment.end,
        children: [
          if (alignment == Alignment.centerLeft) _buildDismissAction(icon, label),
          const Spacer(),
          if (alignment == Alignment.centerRight) _buildDismissAction(icon, label),
        ],
      ),
    );
  }

  Widget _buildDismissAction(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsRow(Map<String, dynamic> entry) {
    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            icon: Icons.height,
            label: 'Height',
            value: '${entry['height']}',
            unit: 'cm',
            color: Colors.blue[100]!,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildMetricCard(
            icon: Icons.monitor_weight,
            label: 'Weight',
            value: '${entry['weight']}',
            unit: 'kg',
            color: Colors.green[100]!,
          ),
        ),
      ],
    );
  }

  Widget _buildNoteSection(String note) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.note,
            size: 20,
            color: Colors.grey[600],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              note,
              style: TextStyle(
                color: Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required String label,
    required String value,
    required String unit,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color.withRed(color.red - 40)),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

   @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : growthHistory.isEmpty
              ? _buildEmptyState()
              : Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.pink[50]!,
                        Colors.white,
                      ],
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildTimePeriodSelector(),
                      Expanded(
                        child: _buildHistoryList(),
                      ),
                    ],
                  ),
                ),
    );
  }
}