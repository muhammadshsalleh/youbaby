import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:collection/collection.dart';

final Map<String, Color> textureDistribution = {
  'Watery': const Color(0xFF29B6F6),
  'Soft': const Color(0xFFAB47BC),
  'Mixed': const Color(0xFF8BC34A),
  'Hard': const Color(0xFFFFB300),
  'Mucousy': const Color(0xFF009688),
};

final List<Color> poopColorValues = [
  const Color.fromARGB(255, 223, 177, 42), // Yellow
  const Color.fromARGB(255, 168, 64, 64), // Red
  const Color.fromARGB(255, 99, 128, 42), // Green
  const Color(0xFF8D6E63), // Brown
  const Color(0xFF424242), //Black
  const Color(0xFFFFFFFF), // White
];

final Map<String, int> poopColorIndices = {
  'Yellow': 0,
  'Red': 1,
  'Green': 2,
  'Brown': 3,
  'Black': 4,
  'White': 5,
};

class DiaperHistoryPage extends StatefulWidget {
  final int userID;

  DiaperHistoryPage({Key? key, required this.userID}) : super(key: key);

  @override
  _DiaperHistoryPageState createState() => _DiaperHistoryPageState();
}

class _DiaperHistoryPageState extends State<DiaperHistoryPage> {
  List<Map<String, dynamic>> _entries = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';
  DateTime _selectedDate = DateTime.now();
  DateTime _displayedMonth;
  Map<DateTime, List<Map<String, dynamic>>> _eventsList = {};

  _DiaperHistoryPageState() : _displayedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      setState(() => _isLoading = true);

      final data = await Supabase.instance.client
          .from('diaperTracker')
          .select()
          .eq('userID', widget.userID)
          .order('date_time', ascending: false);

      setState(() {
        _entries = List<Map<String, dynamic>>.from(data);
        _eventsList = _groupEntriesByDate(_entries);
        _isLoading = false;
      });
    } catch (error) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading history: $error'),
            backgroundColor: Colors.red[400],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Map<DateTime, List<Map<String, dynamic>>> _groupEntriesByDate(
      List<Map<String, dynamic>> entries) {
    Map<DateTime, List<Map<String, dynamic>>> grouped = {};
    for (var entry in entries) {
      final DateTime date = DateTime.parse(entry['date_time']);
      final DateTime dateKey = DateTime(date.year, date.month, date.day);
      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(entry);
    }
    return grouped;
  }

  Widget _buildFilterButton(String label, IconData icon) {
    final isSelected = _selectedFilter == label;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () =>
              setState(() => _selectedFilter = isSelected ? 'All' : label),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFA91B60) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? const Color(0xFFA91B60) : Colors.grey[300]!,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isSelected ? Colors.white : Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCalendar() {
    return Column(
      children: [
        _buildCalendarHeader(),
 
        _buildCalendarGrid(),
      ],
    );
  }

  Widget _buildCalendarHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              setState(() {
                _displayedMonth = DateTime(
                  _displayedMonth.year,
                  _displayedMonth.month - 1,
                );
              });
            },
          ),
          Text(
            DateFormat('MMMM yyyy').format(_displayedMonth),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              if (_displayedMonth.isBefore(DateTime.now())) {
                setState(() {
                  _displayedMonth = DateTime(
                    _displayedMonth.year,
                    _displayedMonth.month + 1,
                  );
                });
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final daysInMonth = DateTime(
      _displayedMonth.year,
      _displayedMonth.month + 1,
      0,
    ).day;
    final firstDayOfMonth =
        DateTime(_displayedMonth.year, _displayedMonth.month, 1);
    final firstWeekday = firstDayOfMonth.weekday;
    final days = List.generate(42, (index) {
      final day = index - (firstWeekday - 1);
      if (day < 1 || day > daysInMonth) return null;
      return DateTime(_displayedMonth.year, _displayedMonth.month, day);
    });

    return Column(
      children: [
        // Weekday headers
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
              .map((day) => SizedBox(
                    width: 40,
                    child: Text(
                      day,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 8),
        // Calendar grid
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 7,
          children: days.map((date) {
            if (date == null) return const SizedBox.shrink();

            final isSelected = _selectedDate.year == date.year &&
                _selectedDate.month == date.month &&
                _selectedDate.day == date.day;

            final isToday = DateTime.now().year == date.year &&
                DateTime.now().month == date.month &&
                DateTime.now().day == date.day;

            final events = _eventsList[date] ?? [];
            final hasPee = events.any((e) => e['type'] == 'Pee');
            final hasPoo = events.any((e) => e['type'] == 'Poo');
            final hasMixed = events.any((e) => e['type'] == 'Mixed');

            return InkWell(
              onTap: () {
                setState(() => _selectedDate = date);
              },
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFA91B60)
                      : isToday
                          ? const Color(0xFFA91B60).withOpacity(0.1)
                          : null,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFFA91B60)
                        : isToday
                            ? const Color(0xFFA91B60)
                            : Colors.transparent,
                  ),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Text(
                        '${date.day}',
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : isToday
                                  ? const Color(0xFFA91B60)
                                  : null,
                          fontWeight:
                              isSelected || isToday ? FontWeight.bold : null,
                        ),
                      ),
                    ),
                    if (events.isNotEmpty)
                      Positioned(
                        bottom: 2,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (hasPee)
                              Icon(
                                Icons.water_drop_rounded,
                                size: 8,
                                color: isSelected
                                    ? Colors.white
                                    : Colors.blue[400],
                              ),
                            if (hasPoo)
                              Icon(
                                Icons.eco_rounded,
                                size: 8,
                                color: isSelected
                                    ? Colors.white
                                    : Colors.brown[400],
                              ),
                            if (hasMixed)
                              Icon(
                                Icons.change_circle_rounded,
                                size: 8,
                                color: isSelected
                                    ? Colors.white
                                    : Colors.purple[400],
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDayEntries() {
    final dayEntries = _eventsList[DateTime(
            _selectedDate.year, _selectedDate.month, _selectedDate.day)] ??
        [];
    final filteredEntries = _selectedFilter == 'All'
        ? dayEntries
        : dayEntries
            .where((entry) => entry['type'] == _selectedFilter)
            .toList();

    if (filteredEntries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'No diaper changes recorded for this day',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filteredEntries.length,
      itemBuilder: (context, index) =>
          _buildHistoryCard(filteredEntries[index]),
    );
  }

 Widget _buildHistoryCard(Map<String, dynamic> entry) {
    final DateTime dateTime = DateTime.parse(entry['date_time']);
    final String formattedTime = DateFormat('h:mm a').format(dateTime);
    final type = entry['type'];
    final hasRash = entry['diaper_rash'] == true;
    final hasNotes = entry['note']?.isNotEmpty ?? false;
    final texture = entry['poo_texture'] ?? '';
    final color = entry['poo_color'] ?? '';

    Color getPooColor(String colorName) {
      final index = poopColorIndices[colorName];
      return index != null ? poopColorValues[index] : Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _getTypeColor(type).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showEntryDetails(entry),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTypeIndicator(type),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              type,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          formattedTime,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        if (type == 'Poo' || type == 'Mixed') ...[
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              if (texture.isNotEmpty)
                                _buildInfoPill(
                                  texture,
                                  textureDistribution[texture] ?? Colors.grey,
                                ),
                              if (color.isNotEmpty)
                                _buildInfoPill(
                                  color,
                                  getPooColor(color),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (hasRash) _buildRashIndicator(),
                ],
              ),
              if (hasNotes) ...[
                const SizedBox(height: 8),
                _buildNotePreview(entry['note']),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoPill(String text, Color color, {Color? borderColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor ?? color),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildTypeIndicator(String type) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _getTypeColor(type).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        _getTypeIcon(type),
        color: _getTypeColor(type),
        size: 24,
      ),
    );
  }

  Widget _buildRashIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[100]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_rounded, color: Colors.red[400], size: 16),
          const SizedBox(width: 4),
          Text(
            'Rash',
            style: TextStyle(
              color: Colors.red[400],
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotePreview(String note) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.note, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              note,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 14,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _showEntryDetails(Map<String, dynamic> entry) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DiaperEntryDetailsSheet(entry: entry),
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'Poo':
        return Icons.eco_rounded;
      case 'Pee':
        return Icons.water_drop_rounded;
      case 'Mixed':
        return Icons.change_circle_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'Poo':
        return Colors.brown[400]!;
      case 'Pee':
        return Colors.blue[400]!;
      case 'Mixed':
        return Colors.purple[400]!;
      default:
        return Colors.grey[400]!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                _buildFilterButton('Pee', Icons.water_drop_rounded),
                const SizedBox(width: 8),
                _buildFilterButton('Poo', Icons.eco_rounded),
                const SizedBox(width: 8),
                _buildFilterButton('Mixed', Icons.change_circle_rounded),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildCalendar(),

                        // "History Logs" title
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Text(
                            'History Logs',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),

                        _buildDayEntries(),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// Details bottom sheet implementation
class DiaperEntryDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> entry;

  const DiaperEntryDetailsSheet({Key? key, required this.entry})
      : super(key: key);

  Color getPooColor(String colorName) {
    final index = poopColorIndices[colorName];
    return index != null ? poopColorValues[index] : Colors.grey;
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'Poo':
        return Colors.brown[400]!;
      case 'Pee':
        return Colors.blue[400]!;
      case 'Mixed':
        return Colors.purple[400]!;
      default:
        return Colors.grey[400]!;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'Poo':
        return Icons.eco_rounded;
      case 'Pee':
        return Icons.water_drop_rounded;
      case 'Mixed':
        return Icons.change_circle_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

   Widget _buildInfoPill(String text, Color color, {Color? borderColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor ?? color),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final DateTime dateTime = DateTime.parse(entry['date_time']);
    final String formattedDate = DateFormat('EEEE, MMMM d, y').format(dateTime);
    final String formattedTime = DateFormat('h:mm a').format(dateTime);
    final type = entry['type'];
    final hasRash = entry['diaper_rash'] == true;
    final note = entry['note'] ?? '';
    final texture = entry['poo_texture'] ?? ''; // Updated field name
    final color = entry['poo_color'] ?? '';     // Updated field name


    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with type and time
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _getTypeColor(type).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getTypeIcon(type),
                        color: _getTypeColor(type),
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            type,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formattedDate,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            formattedTime,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                 if ((type == 'Poo' || type == 'Mixed') && (texture.isNotEmpty || color.isNotEmpty)) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (texture.isNotEmpty)
                        _buildInfoPill(
                          texture,
                          textureDistribution[texture] ?? Colors.grey,
                        ),
                      if (color.isNotEmpty)
                        _buildInfoPill(
                          color,
                          getPooColor(color),
                        ),
                    ],
                  ),
                ],

                const SizedBox(height: 24),

                // Diaper rash indicator
                if (hasRash) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red[100]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_rounded, color: Colors.red[400]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Diaper Rash Detected',
                                style: TextStyle(
                                  color: Colors.red[700],
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Consider using diaper rash cream and changing diapers more frequently',
                                style: TextStyle(
                                  color: Colors.red[700],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Notes section
                if (note.isNotEmpty) ...[
                  const Text(
                    'Notes',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Text(
                      note,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Close button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Close',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Add extra padding for bottom safe area
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}
