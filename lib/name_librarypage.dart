import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NameLibraryPage extends StatefulWidget {
  const NameLibraryPage({super.key});

  @override
  _NameLibraryPageState createState() => _NameLibraryPageState();
}

class _NameLibraryPageState extends State<NameLibraryPage> {
  String? selectedLetter;
  String? selectedRace;
  String? selectedGender;

  List<Map<String, dynamic>> names = [];
  bool _isSearchPressed = false; // Boolean to track if search button is pressed

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Name Library',
          style: TextStyle(
            color: Color(0xFFEBE0D0),
            fontSize: 24.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFFA91B60),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFf5e5ed),
              Color(0xFFebccdb),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Visibility(
                visible:
                    !_isSearchPressed, // Dropdowns are only visible when search isn't pressed
                child: Column(
                  children: [
                    _buildCardDropdown(
                      label: 'First Letter',
                      value: selectedLetter,
                      items: _getAlphabet(),
                      onChanged: (value) {
                        setState(() {
                          selectedLetter = value;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    _buildCardDropdown(
                      label: 'Race',
                      value: selectedRace,
                      items: const ['Islamic', 'Chinese', 'Indian', 'Others'],
                      onChanged: (value) {
                        setState(() {
                          selectedRace = value;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    _buildCardDropdown(
                      label: 'Gender',
                      value: selectedGender,
                      items: const ['Boy', 'Girl'],
                      onChanged: (value) {
                        setState(() {
                          selectedGender = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (!_isSearchPressed)
                ElevatedButton(
                  onPressed: () {
                    _fetchNames();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFA91B60),
                    foregroundColor: const Color(0xFFEBE0D0),
                  ),
                  child: const Text('Search Names'),
                ),
              if (_isSearchPressed)
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isSearchPressed = false;
                      names.clear(); // Clear the list to hide the results
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFA91B60),
                    foregroundColor: const Color(0xFFEBE0D0),
                  ),
                  child: const Text('Back to Filter'),
                ),
              const SizedBox(height: 20),
              Expanded(
                child: _buildNameList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Card(
      elevation: 3.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16.0,
              ),
            ),
            const SizedBox(height: 8.0),
            DropdownButton<String>(
              value: value,
              onChanged: onChanged,
              items: items.map((item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(item),
                );
              }).toList(),
              isExpanded: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNameList() {
    if (names.isEmpty && _isSearchPressed) {
      return Center(
        child: Text('No names found.',
            style: TextStyle(fontSize: 18.0, color: Colors.grey[700])),
      );
    } else if (!_isSearchPressed) {
      return Container(); // If no search has been pressed, show an empty container
    }
    return ListView.builder(
      itemCount: names.length,
      itemBuilder: (context, index) {
        final name = names[index];
        return Card(
          elevation: 5.0,
          margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16.0),
            title: Text(
              name['fullName'],
              style: const TextStyle(
                fontSize: 22.0,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
              ),
            ),
            subtitle: Text(
              'Meaning: ${name['meaning']}',
              style: TextStyle(
                fontSize: 16.0,
                color: Colors.grey[600],
              ),
            ),
          ),
        );
      },
    );
  }

  List<String> _getAlphabet() {
    return List<String>.generate(
        26, (index) => String.fromCharCode(index + 65));
  }

  Future<void> _fetchNames() async {
    if (selectedLetter == null ||
        selectedRace == null ||
        selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select a letter, race, and gender.')),
      );
      return;
    }

    setState(() {
      _isSearchPressed = true; // Hide dropdowns and show results
    });

    try {
      final response = await Supabase.instance.client
          .from('nameGenerator')
          .select()
          .ilike('fullName', '$selectedLetter%')
          .eq('race', '$selectedRace')
          .eq('gender', '$selectedGender');

      setState(() {
        names = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching names: $e')),
      );
    }
  }
}
