import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class QuizScreen extends StatefulWidget {
  final String subject;
  final String chapterTitle;
  final int bookId;
  final String chapterNumber;

  const QuizScreen({
    Key? key,
    required this.subject,
    required this.chapterTitle,
    required this.bookId,
    required this.chapterNumber,
  }) : super(key: key);

  @override
  _QuizScreenState createState() => _QuizScreenState();
}
class _QuizScreenState extends State<QuizScreen> {
  List<Map<String, dynamic>> questions = [];
  bool isLoading = true;
  String errorMessage = '';
  int currentQuestionIndex = 0;
  String? selectedAnswerKey;
  bool answerSubmitted = false;
  int score = 0;

  @override
  void initState() {
    super.initState();

    _fetchQuizQuestions();
  }

  Future<void> _fetchQuizQuestions() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = '';
      });

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken');

      final response = await http.post(
        Uri.parse('http://56.228.80.139/api/quiz/generate-quiz/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({

          'title': widget.chapterTitle,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['questions'] != null && data['questions'].isNotEmpty) {
          setState(() {
            questions = List<Map<String, dynamic>>.from(data['questions'].map((q) {
              final answers = Map<String, String>.from(q['answers']);
              final answerList = answers.entries.map((e) => {
                'key': e.key,
                'value': e.value,
              }).toList();

              return {
                'id': q['id'],
                'question_text': q['question_text'],
                'description': q['description'] ?? '',
                'answers': answerList,
                'correct_answer': q['correct_answer'] ?? answerList.first['key'],
                'explanation': q['explanation'] ?? 'No explanation provided',
                'category': q['category'] ?? '',
                'difficulty': q['difficulty'] ?? 'MEDIUM',
                'tags': List<String>.from(q['tags'] ?? []),
              };
            }));
            isLoading = false;
          });
        } else {
          throw Exception('No questions found in response');
        }
      } else {
        throw Exception('Failed to load questions: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error: ${e.toString()}';
        isLoading = false;
      });
    }
  }


  void _submitAnswer() {
    if (selectedAnswerKey == null) return;

    setState(() {
      answerSubmitted = true;
      if (selectedAnswerKey == questions[currentQuestionIndex]['correct_answer']) {
        score++;
      }
    });
  }

  void _nextQuestion() {
    setState(() {
      currentQuestionIndex++;
      selectedAnswerKey = null;
      answerSubmitted = false;
    });
  }

  void _finishQuiz() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.emoji_events,
                size: 60,
                color: Color(0xFFFFD700),
              ),
              const SizedBox(height: 16),
              Text(
                'Quiz Completed!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 16),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'Your score: ',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    TextSpan(
                      text: '$score/${questions.length}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _getScoreColor(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() {
                          currentQuestionIndex = 0;
                          score = 0;
                          selectedAnswerKey = null;
                          answerSubmitted = false;
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(
                          color: const Color(0xFF007BFF),
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        'Restart',
                        style: TextStyle(
                          fontSize: 16,
                          color: const Color(0xFF007BFF),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF007BFF),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Finish',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getScoreColor() {
    double percentage = score / questions.length;
    if (percentage >= 0.8) return Colors.green;
    if (percentage >= 0.5) return Colors.orange;
    return Colors.red;
  }

  Widget _buildOptionCard(Map<String, dynamic> answer) {
    bool isCorrect = answer['key'] == questions[currentQuestionIndex]['correct_answer'];
    bool isSelected = selectedAnswerKey == answer['key'];

    Color backgroundColor = Colors.white;
    Color borderColor = Colors.grey.shade300;

    if (answerSubmitted) {
      if (isCorrect) {
        backgroundColor = Colors.green.withOpacity(0.1);
        borderColor = Colors.green;
      } else if (isSelected && !isCorrect) {
        backgroundColor = Colors.red.withOpacity(0.1);
        borderColor = Colors.red;
      }
    } else if (isSelected) {
      backgroundColor = const Color(0xFF007BFF).withOpacity(0.1);
      borderColor = const Color(0xFF007BFF);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8), // Reduced bottom padding
      child: InkWell(
        onTap: answerSubmitted ? null : () {
          setState(() {
            selectedAnswerKey = answer['key'];
          });
        },
        child: Container(
          constraints: BoxConstraints(minHeight: 60), // Set minimum height
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8), // Adjusted padding
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start, // Align items to top
            children: [
              Container(
                width: 24,
                height: 24,
                margin: const EdgeInsets.only(top: 2), // Add small top margin
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? (answerSubmitted
                      ? (isCorrect
                      ? Colors.green
                      : Colors.red)
                      : const Color(0xFF007BFF))
                      : Colors.transparent,
                  border: Border.all(
                    color: isSelected
                        ? Colors.transparent
                        : Colors.grey.shade400,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12), // Reduced spacing
              Expanded(
                child: Text(
                  '${answer['key']}. ${answer['value']}',
                  style: TextStyle(
                    fontSize: 15, // Slightly reduced font size
                    color: Colors.grey.shade800,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 3, // Allow up to 3 lines
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.subject} Quiz'),
        backgroundColor: const Color(0xFF007BFF),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.grey.shade100, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : errorMessage.isNotEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  errorMessage,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _fetchQuizQuestions,
                  child: const Text('Retry'),
                ),
              ],
            ),
          )
              : questions.isEmpty
              ? const Center(child: Text('No questions available'))
              : Column(
            children: [
              // Progress and question counter at top
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(
                    value: (currentQuestionIndex + 1) / questions.length,
                    backgroundColor: Colors.grey.shade300,
                    color: const Color(0xFF007BFF),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Question ${currentQuestionIndex + 1}/${questions.length}',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),

              // Scrollable content area
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),
                      Text(
                        questions[currentQuestionIndex]['question_text'],
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (questions[currentQuestionIndex]['description']?.isNotEmpty ?? false)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            questions[currentQuestionIndex]['description'],
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),
                      ...questions[currentQuestionIndex]['answers']
                          .map<Widget>((answer) => _buildOptionCard(answer))
                          .toList(),
                      if (answerSubmitted) ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selectedAnswerKey == questions[currentQuestionIndex]['correct_answer']
                                    ? 'Correct!'
                                    : 'Incorrect',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: selectedAnswerKey == questions[currentQuestionIndex]['correct_answer']
                                      ? Colors.green
                                      : Colors.red,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                questions[currentQuestionIndex]['explanation'],
                                style: const TextStyle(fontSize: 16),
                              ),
                              const SizedBox(height: 8),
                              if (questions[currentQuestionIndex]['tags']?.isNotEmpty ?? false)
                                Wrap(
                                  spacing: 8,
                                  children: (questions[currentQuestionIndex]['tags'] as List<dynamic>)
                                      .map((tag) => Chip(
                                    label: Text(tag.toString()),
                                    backgroundColor: Colors.blue.shade50,
                                  ))
                                      .toList(),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Fixed button at bottom
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: answerSubmitted
                      ? currentQuestionIndex < questions.length - 1
                      ? _nextQuestion
                      : _finishQuiz
                      : selectedAnswerKey != null
                      ? _submitAnswer
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007BFF),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    answerSubmitted
                        ? currentQuestionIndex < questions.length - 1
                        ? 'Next Question'
                        : 'Finish Quiz'
                        : 'Submit Answer',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}