import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'diaper_tracker_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DiaperEntryPage extends StatefulWidget {
  final int? userID;

  const DiaperEntryPage({super.key, required this.userID});

  @override
  _DiaperEntryPageState createState() => _DiaperEntryPageState();
}

class _DiaperEntryPageState extends State<DiaperEntryPage> {
  String selectedType = 'Poo';
  int selectedPoopColorIndex = 0;
  int selectedTextureIndex = 0;
  bool hasDiaperRash = false;
  final TextEditingController noteController = TextEditingController();

  late DateTime selectedDateTime;
  final DateFormat dateFormatter = DateFormat('dd MMM yyyy');
  final DateFormat timeFormatter = DateFormat('HH:mm');

  @override
  void initState() {
    super.initState();
    selectedDateTime = DateTime.now();
  }

  final List<String> poopColors = [
    'Yellow',
    'Red',
    'Green',
    'Brown',
    'Black',
    'White'
  ];

  final List<Color> poopColorValues = [
    const Color.fromARGB(255, 223, 177, 42),
    const Color.fromARGB(255, 168, 64, 64),
    const Color.fromARGB(255, 99, 128, 42),
    const Color(0xFF8D6E63),
    const Color(0xFF424242),
    const Color(0xFFFFFFFF),
  ];

  final List<String> textures = ['Soft', 'Watery', 'Mucousy', 'Hard', 'Mixed'];

  final Map<String, Color> textureColors = {
    'Soft': Colors.green,
    'Watery': Colors.blue,
    'Mucousy': Colors.orange,
    'Hard': Colors.brown,
    'Mixed': Colors.purple,
  };

  Color _getTypeColor(String type) {
    return const Color(0xFFA91B60);
  }

  Widget _buildTypeButton(String type) {
    final isSelected = selectedType == type;
    final color = _getTypeColor(type);

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => selectedType = type),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? color : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? color : Colors.grey[300]!,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _getTypeIcon(type),
                  size: 18,
                  color: isSelected ? Colors.white : Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Text(
                  type,
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

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'Poo':
        return Icons.eco_rounded;
      case 'Pee':
        return Icons.water_drop_rounded;
      case 'Mixed':
        return Icons.change_circle_rounded;
      default:
        return Icons.error;
    }
  }

  Widget _buildColorOption(Color color, String label, bool isSelected) {
    return Container(
      width: 50, // Reduced from 80 to 60
      margin: const EdgeInsets.symmetric(horizontal: 2), // Reduced from 4 to 2
      child: Column(
        children: [
          Container(
            width: 40, // Reduced from 40 to 32
            height: 40, // Reduced from 40 to 32
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? const Color(0xFFA91B60) : Colors.grey[300]!,
                width: isSelected ? 2 : 1,
              ),
            ),
          ),
          const SizedBox(height: 2), // Reduced from 4 to 2
          Text(
            label,
            style: TextStyle(
              fontSize: 10, // Reduced from 12 to 10
              color: isSelected ? const Color(0xFFA91B60) : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextureOption(String texture, int index) {
  final isSelected = selectedTextureIndex == index;

  return Container(
    width: 60, // Reduced width for compact layout
    margin: const EdgeInsets.symmetric(horizontal: 2), // Reduced margin
    child: GestureDetector(
      onTap: () => setState(() => selectedTextureIndex = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 54, // Adjusted container width
            height: 54, // Adjusted container height
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? const Color(0xFFA91B60) : Colors.grey[300]!,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.image_outlined,
                  color: Colors.grey[400],
                  size: 20, // Adjusted icon size
                ),
                if (isSelected)
                  Positioned(
                    right: 1, // Adjusted position
                    top: 1, // Adjusted position
                    child: Container(
                      padding: const EdgeInsets.all(1), // Adjusted padding
                      decoration: const BoxDecoration(
                        color: Color(0xFFA91B60),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 10, // Adjusted icon size
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 2), // Adjusted spacing

          // Texture label with FittedBox to prevent overflow
          FittedBox(
            child: Text(
              texture,
              style: TextStyle(
                fontSize: 10, // Reduced font size
                color: isSelected ? const Color(0xFFA91B60) : Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}


  Future<void> _selectDateTime(BuildContext context) async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: selectedDateTime,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      final TimeOfDay? time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(selectedDateTime),
      );
      if (time != null) {
        setState(() {
          selectedDateTime = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Add explicit background color
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildTypeButton('Poo'),
                    const SizedBox(width: 8),
                    _buildTypeButton('Pee'),
                    const SizedBox(width: 8),
                    _buildTypeButton('Mixed'),
                  ],
                ),
                const SizedBox(height: 24),

                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey[300]!),
                  ),
                  child: ListTile(
                    onTap: () => _selectDateTime(context),
                    leading: const Icon(Icons.access_time),
                    title: Text(
                      DateFormat('MMM d, yyyy').format(selectedDateTime),
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      DateFormat('h:mm a').format(selectedDateTime),
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                ),
                const SizedBox(height: 16),

                if (selectedType == 'Poo' || selectedType == 'Mixed') ...[
                  const Text(
                    'Color',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                   SizedBox(
                    height: 60, // Reduced from 80 to 60
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: poopColors.length,
                      itemBuilder: (context, index) => _buildColorOption(
                        poopColorValues[index],
                        poopColors[index],
                        selectedPoopColorIndex == index,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Texture',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 70, // Reduced from 90 to 70
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: textures.length,
                        itemBuilder: (context, index) => _buildTextureOption(
                          textures[index],
                          index,
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                ],

                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey[300]!),
                  ),
                  child: ListTile(
                    leading: Icon(
                      Icons.warning_rounded,
                      color: hasDiaperRash ? const Color(0xFFA91B60) : Colors.grey,
                    ),
                    title: const Text('Diaper Rash'),
                    trailing: Switch(
                      value: hasDiaperRash,
                      onChanged: (value) => setState(() => hasDiaperRash = value),
                      activeColor: const Color(0xFFA91B60),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey[300]!),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: noteController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Add notes...',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      // Implement save functionality
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFA91B60),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Save',
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
        ),
      ),
    );
  }
}