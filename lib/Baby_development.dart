import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BabyDevelopmentPage extends StatefulWidget {
  const BabyDevelopmentPage({super.key});

  @override
  _BabyDevelopmentPageState createState() => _BabyDevelopmentPageState();
}

class _BabyDevelopmentPageState extends State<BabyDevelopmentPage> {
  // Define variables to store evaluation results for each category
  int _socialScore = 0;
  int _cognitiveScore = 0;
  int _physicalScore = 0;
  int _communicationScore = 0;
  int _motorskillsScore = 0;

  // Lists to store questions fetched from the database
  List<Map<String, dynamic>> _socialQuestions = [];
  List<Map<String, dynamic>> _cognitiveQuestions = [];
  List<Map<String, dynamic>> _physicalQuestions = [];
  List<Map<String, dynamic>> _communicationQuestions = [];
  List<Map<String, dynamic>> _motorskillsQuestions = [];

  // Maps to track user's answers for each question
  Map<int, bool?> _socialAnswers = {};
  Map<int, bool?> _cognitiveAnswers = {};
  Map<int, bool?> _physicalAnswers = {};
  Map<int, bool?> _communicationAnswers = {};
  Map<int, bool?> _motorskillsAnswers = {};

  // Selected age range
  String _selectedAgeRange = '0-1 months';

  @override
  void initState() {
    super.initState();
    _fetchQuestions();
  }

  // Convert age range to displayable string
  String _ageRangeToString(String ageRange) {
    switch (ageRange) {
      case '0-1 months':
        return '0 - 1 month';
      case '1-3 months':
        return '1 - 3 months';
      case '3-6 months':
        return '3 - 6 months';
      case '6-9 months':
        return '6 - 9 months';
      case '9-12 months':
        return '9 - 12 months';
      case '12-18 months':
        return '1 year - 1 year 6 months';
      case '18-24 months':
        return '1 year 6 months - 2 years';
      case '2-3 years':
        return '2 years - 3 years';
      default:
        return '';
    }
  }

  // Fetch questions from Supabase based on selected age range
  Future<void> _fetchQuestions() async {
    final supabase = Supabase.instance.client;

    try {
      // Fetch social questions
      final socialResponse = await supabase
          .from('evaluation_questions')
          .select()
          .eq('category', 'social')
          .eq('babyAge', _selectedAgeRange);

      // Fetch cognitive questions
      final cognitiveResponse = await supabase
          .from('evaluation_questions')
          .select()
          .eq('category', 'cognitive')
          .eq('babyAge', _selectedAgeRange);

      // Fetch physical questions
      final physicalResponse = await supabase
          .from('evaluation_questions')
          .select()
          .eq('category', 'physical')
          .eq('babyAge', _selectedAgeRange);

      // Fetch communication questions
      final communicationResponse = await supabase
          .from('evaluation_questions')
          .select()
          .eq('category', 'communication')
          .eq('babyAge', _selectedAgeRange);

      // Fetch motor skills questions
      final motorskillsResponse = await supabase
          .from('evaluation_questions')
          .select()
          .eq('category', 'motorskills')
          .eq('babyAge', _selectedAgeRange);

      // If successful, set the state
      setState(() {
        _socialQuestions = List<Map<String, dynamic>>.from(socialResponse);
        _cognitiveQuestions =
            List<Map<String, dynamic>>.from(cognitiveResponse);
        _physicalQuestions =
            List<Map<String, dynamic>>.from(physicalResponse);
        _communicationQuestions =
            List<Map<String, dynamic>>.from(communicationResponse);
        _motorskillsQuestions =
            List<Map<String, dynamic>>.from(motorskillsResponse);

        // Initialize answer maps with null (no answer)
        _socialAnswers = Map<int, bool?>.fromIterables(
            List.generate(_socialQuestions.length, (index) => index),
            List.generate(_socialQuestions.length, (index) => null));
        _cognitiveAnswers = Map<int, bool?>.fromIterables(
            List.generate(_cognitiveQuestions.length, (index) => index),
            List.generate(_cognitiveQuestions.length, (index) => null));
        _physicalAnswers = Map<int, bool?>.fromIterables(
            List.generate(_physicalQuestions.length, (index) => index),
            List.generate(_physicalQuestions.length, (index) => null));
        _communicationAnswers = Map<int, bool?>.fromIterables(
            List.generate(_communicationQuestions.length, (index) => index),
            List.generate(_communicationQuestions.length, (index) => null));
        _motorskillsAnswers = Map<int, bool?>.fromIterables(
            List.generate(_motorskillsQuestions.length, (index) => index),
            List.generate(_motorskillsQuestions.length, (index) => null));
      });
    } catch (error) {
      print('Unexpected error occurred: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Baby Development Evaluation',
          style: TextStyle(
            color: Color(0xFFEBE0D0),
            fontSize: 24.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFFA91B60),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Age Range',
              style: TextStyle(
                fontSize: 24.0,
                fontWeight: FontWeight.bold,
                color: Color(0xFFA91B60),
              ),
            ),
            const SizedBox(height: 16.0),

            // Horizontal Scroll for Age Range Selection
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _ageRangeButton('0-1 months'),
                  _ageRangeButton('1-3 months'),
                  _ageRangeButton('3-6 months'),
                  _ageRangeButton('6-9 months'),
                  _ageRangeButton('9-12 months'),
                  _ageRangeButton('12-18 months'),
                  _ageRangeButton('18-24 months'),
                  _ageRangeButton('2-3 years'),
                ],
              ),
            ),

            const SizedBox(height: 16.0),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Social Development Section
                    _buildCategoryCard(
                        'Social Development', _socialQuestions, _socialAnswers,
                        (bool value, int index) {
                      setState(() {
                        _updateScore(value, index, _socialAnswers, (newScore) {
                          _socialScore = newScore;
                        });
                      });
                    }),

                    const SizedBox(height: 10.0),

                    // Cognitive Development Section
                    _buildCategoryCard(
                        'Cognitive Development',
                        _cognitiveQuestions,
                        _cognitiveAnswers, (bool value, int index) {
                      setState(() {
                        _updateScore(value, index, _cognitiveAnswers,
                            (newScore) {
                          _cognitiveScore = newScore;
                        });
                      });
                    }),

                    const SizedBox(height: 10.0),

                    // Physical Development Section
                    _buildCategoryCard(
                        'Physical Development',
                        _physicalQuestions,
                        _physicalAnswers, (bool value, int index) {
                      setState(() {
                        _updateScore(value, index, _physicalAnswers,
                            (newScore) {
                          _physicalScore = newScore;
                        });
                      });
                    }),

                    const SizedBox(height: 16.0),

                    // Communication Development Section
                    _buildCategoryCard(
                        'Communication Development',
                        _communicationQuestions,
                        _communicationAnswers, (bool value, int index) {
                      setState(() {
                        _updateScore(value, index, _communicationAnswers,
                            (newScore) {
                          _communicationScore = newScore;
                        });
                      });
                    }),

                    const SizedBox(height: 16.0),

                    // Motor Skills Development Section
                    _buildCategoryCard(
                        'Motor Skills Development',
                        _motorskillsQuestions,
                        _motorskillsAnswers, (bool value, int index) {
                      setState(() {
                        _updateScore(value, index, _motorskillsAnswers,
                            (newScore) {
                          _motorskillsScore = newScore;
                        });
                      });
                    }),

                    const SizedBox(height: 16.0),

                    // Display evaluation results
                    const Text(
                      'Evaluation Results',
                      style: TextStyle(
                        fontSize: 20.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(),
                    Text(
                        'Social Development: ${_calculatePercentage(_socialScore, _socialQuestions.length)}%',
                        style: const TextStyle(fontSize: 16.0)),
                    Text(
                        'Cognitive Development: ${_calculatePercentage(_cognitiveScore, _cognitiveQuestions.length)}%',
                        style: const TextStyle(fontSize: 16.0)),
                    Text(
                        'Physical Development: ${_calculatePercentage(_physicalScore, _physicalQuestions.length)}%',
                        style: const TextStyle(fontSize: 16.0)),
                    Text(
                        'Communication Development: ${_calculatePercentage(_communicationScore, _communicationQuestions.length)}%',
                        style: const TextStyle(fontSize: 16.0)),
                    Text(
                        'Motor Skills Development: ${_calculatePercentage(_motorskillsScore, _motorskillsQuestions.length)}%',
                        style: const TextStyle(fontSize: 16.0)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper function to create age range selection buttons
  Widget _ageRangeButton(String ageRange) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: _selectedAgeRange == ageRange
              ? Colors.pinkAccent
              : const Color(0xFFEBE0D0),
          foregroundColor: _selectedAgeRange == ageRange ? Colors.white : Colors.black,
        ),
        onPressed: () {
          setState(() {
            _selectedAgeRange = ageRange;
            _fetchQuestions(); // Fetch questions based on the selected age range
          });
        },
        child: Text(_ageRangeToString(ageRange)),
      ),
    );
  }

  // Helper function to update the score based on the user's answer
  void _updateScore(bool value, int index, Map<int, bool?> answersMap,
      Function(int) updateScore) {
    // Retrieve the current score
    int currentScore = answersMap.values.where((answer) => answer == true).length;

    // Check if the answer is changing
    if (answersMap[index] == null || answersMap[index] != value) {
      if (value) {
        currentScore += 1; // Increment score
      } else if (answersMap[index] == true) {
        currentScore -= 1; // Decrement score only if previously "Yes"
      }
      ////////////////////////////////////////////
      answersMap[index] = value;
    }

    // Update the score using the provided callback
    updateScore(currentScore);
  }

  // Helper function to calculate percentage
  String _calculatePercentage(int score, int totalQuestions) {
    if (totalQuestions == 0) return '0';
    return ((score / totalQuestions) * 100).toStringAsFixed(1);
  }

  // Helper function to build a category card with progress indicator
  Widget _buildCategoryCard(String title, List<Map<String, dynamic>> questions,
      Map<int, bool?> answersMap, Function(bool, int) onAnswer) {
    // Calculate the percentage score for the category
    final int score =
        answersMap.values.where((answer) => answer == true).length;
    final double percentage =
        questions.isNotEmpty ? (score / questions.length) * 100 : 0;

    return Card(
      color: const Color(0xFFEBE0D0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title of the category
            Text(
              title,
              style: const TextStyle(
                fontSize: 20.0,
                fontWeight: FontWeight.bold,
                color: Color(0xFFA91B60),
              ),
            ),
            const SizedBox(height: 10.0),

            // List of questions
            ...List.generate(questions.length, (index) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(questions[index]['question_text']),
                  const SizedBox(height: 10.0),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () => onAnswer(true, index),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: answersMap[index] == true
                              ? const Color.fromARGB(255, 0, 255, 13)
                              : const Color.fromARGB(255, 200, 255, 202),
                        ),
                        child: const Text('Yes'),
                      ),
                      ElevatedButton(
                        onPressed: () => onAnswer(false, index),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: answersMap[index] == false
                              ? const Color.fromARGB(255, 255, 0, 0)
                              : const Color.fromARGB(255, 255, 201, 201),
                        ),
                        child: const Text('No'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10.0),
                ],
              );
            }),
            // Progress Indicator
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: percentage / 100,
                    strokeWidth: 1.0,
                    backgroundColor: Colors.grey[300],
                    color: const Color(0xFFA91B60),
                  ),
                  Text(
                    '${percentage.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontSize: 32.0,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFA91B60),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10.0),
          ],
        ),
      ),
    );
  }
}
