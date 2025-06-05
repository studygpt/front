import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AnalyticsPage extends StatefulWidget {
  @override
  _AnalyticsPageState createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  int totalReadingHours = 0;
  int totalQuizzesCompleted = 0;
  int totalPromptsUsed = 0;
  Map<String, double> subjectPerformance = {};
  List<WeeklyProgress> weeklyProgress = [];
  List<Recommendation> recommendations = [];
  bool isLoading = true;
  String? errorMessage;
  List<RecentActivity> recentActivities = [];

  @override
  void initState() {
    super.initState();
    fetchAnalyticsData();
  }

  Future<void> fetchAnalyticsData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // Retrieve user ID from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id') ?? 0; // Default to 0 if not found
      if (userId == 0) {
        throw Exception('User ID not found in SharedPreferences');
      }

      final responses = await Future.wait([
        _safeApiCall('http://56.228.80.139/api/analytics/interactions/?user_id=$userId&paginate_by=month'),
        _safeApiCall('http://56.228.80.139/api/analytics/quiz-performance/?user_id=$userId&paginate_by=month'),
        _safeApiCall('http://56.228.80.139/api/analytics/ai-usage/?user_id=$userId&paginate_by=month'),
      ]);

      _processInteractionsData(responses[0]);
      _processQuizData(responses[1]);
      _processAiUsageData(responses[2]);
      _generateRecommendations();
      _generateRecentActivities(responses[0], responses[1], responses[2]);

      setState(() => isLoading = false);
    } catch (e) {
      setState(() {
        errorMessage = 'Error: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  Future<Map<String, dynamic>> _safeApiCall(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw Exception('API request failed with status ${response.statusCode}');
      }
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('API call failed for $url: $e');
      return {};
    }
  }

  void _processInteractionsData(Map<String, dynamic> data) {
    try {
      final currentMonth = '2025-06';
      final monthData = data['month'] is Map ? data['month'][currentMonth] ?? {} : {};
      final byEbook = data['by_ebook'] is Map ? data['by_ebook'] : {};

      // Calculate total reading hours
      final totalMinutes = _parseNumber(monthData['total_time_spent']) ?? 0;
      setState(() => totalReadingHours = totalMinutes ~/ 60);

      // Process daily hours
      final daysOfWeek = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final dailyHours = Map.fromIterable(daysOfWeek, value: (_) => 0);

      final interactions = (monthData['interactions'] is List)
          ? List.from(monthData['interactions'])
          : <dynamic>[];

      for (var interaction in interactions) {
        try {
          if (interaction is Map && interaction['date'] != null) {
            final date = DateTime.tryParse(interaction['date'].toString());
            if (date != null) {
              final dayIndex = date.weekday - 1; // Convert to 0-based index
              if (dayIndex >= 0 && dayIndex < daysOfWeek.length) {
                final day = daysOfWeek[dayIndex];
                final timeSpent = _parseNumber(interaction['time_spent']) ?? 0;
                dailyHours[day] = dailyHours[day]! + (timeSpent ~/ 60);
              }
            }
          }
        } catch (e) {
          debugPrint('Error processing interaction: $e');
        }
      }

      // Process subject performance
      final performance = <String, double>{};
      if (byEbook is Map) {
        byEbook.forEach((id, ebook) {
          try {
            if (ebook is Map && ebook['title'] != null) {
              final title = ebook['title'].toString();
              final timeSpent = _parseNumber(ebook['total_time_spent'])?.toDouble() ?? 0.0;
              performance[title] = timeSpent / 60.0;
            }
          } catch (e) {
            debugPrint('Error processing ebook: $e');
          }
        });
      }

      setState(() {
        subjectPerformance = performance;
        weeklyProgress = daysOfWeek.map((day) => WeeklyProgress(day, dailyHours[day]!)).toList();
      });
    } catch (e) {
      debugPrint('Error in _processInteractionsData: $e');
      setState(() => errorMessage = 'Failed to process reading data');
    }
  }

  void _processQuizData(Map<String, dynamic> data) {
    try {
      final weekData = data['week'] is Map ? data['week']['2025-21'] ?? {} : {};
      setState(() {
        totalQuizzesCompleted = _parseNumber(data['total_quizzes']) ?? 0;
      });
    } catch (e) {
      debugPrint('Error in _processQuizData: $e');
    }
  }

  void _processAiUsageData(Map<String, dynamic> data) {
    try {
      final monthData = data['month'] is Map ? data['month']['2025-05'] ?? {} : {};
      setState(() {
        totalPromptsUsed = _parseNumber(monthData['conversation_count']) ?? 0;
      });
    } catch (e) {
      debugPrint('Error in _processAiUsageData: $e');
    }
  }

  int? _parseNumber(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  void _generateRecommendations() {
    final recs = [
      Recommendation(
          'Consistent Study Pattern',
          'Try to maintain your reading habit from June (9 sessions) rather than May (2 sessions)'
      ),
      Recommendation(
          'Quiz Performance',
          'Your average quiz score is 87.15%. Consider reviewing questions you missed'
      ),
      Recommendation(
          'AI Usage',
          'You used AI prompts mostly for technical topics. Try using it for other subjects too'
      ),
    ];
    setState(() => recommendations = recs);
  }

  void _generateRecentActivities(
      Map<String, dynamic> interactions,
      Map<String, dynamic> quizzes,
      Map<String, dynamic> aiUsage
      ) {
    final activities = <RecentActivity>[];

    try {
      // Add quiz activities
      final quizWeek = quizzes['week'] is Map ? quizzes['week']['2025-21'] ?? {} : {};
      final quizList = quizWeek['quizzes'] is List ? List.from(quizWeek['quizzes']) : [];
      quizList.sort((a, b) => _compareTimestamps(a['completed_at'], b['completed_at']));

      for (var quiz in quizList.take(3)) {
        activities.add(RecentActivity(
          icon: Icons.quiz,
          title: 'Completed ${_safeString(quiz['quiz_title'], 'Quiz')}',
          subtitle: 'Scored ${_safeString(quiz['score'], '?')}%',
          time: _formatDate(quiz['completed_at']),
          color: Colors.green,
        ));
      }

      // Add reading activities
      final interactionMonth = interactions['month'] is Map ? interactions['month']['2025-06'] ?? {} : {};
      final interactionList = interactionMonth['interactions'] is List ? List.from(interactionMonth['interactions']) : [];
      interactionList.sort((a, b) => _compareTimestamps(a['date'], b['date']));

      for (var interaction in interactionList.take(2)) {
        activities.add(RecentActivity(
          icon: Icons.book,
          title: 'Read ${_safeString(interaction['ebook_title'], 'Book')}',
          subtitle: '${_safeString(interaction['pages_read'], '?')} pages',
          time: _formatDate(interaction['date']),
          color: Colors.blue,
        ));
      }

      // Add AI activities
      final aiMonth = aiUsage['month'] is Map ? aiUsage['month']['2025-05'] ?? {} : {};
      final aiList = aiMonth['conversations'] is List ? List.from(aiMonth['conversations']) : [];
      aiList.sort((a, b) => _compareTimestamps(a['created_at'], b['created_at']));

      for (var conv in aiList.take(2)) {
        activities.add(RecentActivity(
          icon: Icons.chat,
          title: 'AI Prompt: ${_safeString(conv['title'], 'Untitled').split('\n').first}',
          subtitle: 'Used ${_safeString(conv['chat_model'], 'unknown model')}',
          time: _formatDate(conv['created_at']),
          color: Colors.orange,
        ));
      }

      // Sort all activities by time
      activities.sort((a, b) => b.time.compareTo(a.time));
      setState(() => recentActivities = activities);
    } catch (e) {
      debugPrint('Error in _generateRecentActivities: $e');
    }
  }

  int _compareTimestamps(dynamic a, dynamic b) {
    final aStr = a?.toString() ?? '';
    final bStr = b?.toString() ?? '';
    return bStr.compareTo(aStr);
  }

  String _safeString(dynamic value, String fallback) {
    return value?.toString() ?? fallback;
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'Unknown';
    final str = date.toString();
    return str.contains(' ') ? str.split(' ')[0] : str;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Learning Analytics',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: fetchAnalyticsData,
          ),
        ],
      ),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (isLoading) return Center(child: CircularProgressIndicator());
    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(errorMessage!),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: fetchAnalyticsData,
              child: Text('Retry'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryCards(),
          SizedBox(height: 24),
          _buildSubjectPerformanceChart(),
          SizedBox(height: 24),
          _buildWeeklyProgressChart(),
          SizedBox(height: 24),
          _buildStudyRecommendations(),
          SizedBox(height: 24),
          _buildRecentActivity(),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _SummaryCard(
          icon: Icons.timer,
          value: '$totalReadingHours hrs',
          label: 'Monthly Reading',
          color: Colors.blue[700]!,
        ),
        _SummaryCard(
          icon: Icons.quiz,
          value: '$totalQuizzesCompleted',
          label: 'Quizzes Completed',
          color: Colors.green[700]!,
        ),
        _SummaryCard(
          icon: Icons.chat_bubble,
          value: '$totalPromptsUsed',
          label: 'AI Prompts Used',
          color: Colors.orange[700]!,
        ),
      ],
    );
  }

  Widget _buildSubjectPerformanceChart() {
    final chartData = subjectPerformance.entries
        .take(10) // Limit to prevent overflow
        .map((e) => ChartData(
      e.key.length > 15 ? '${e.key.substring(0, 15)}...' : e.key,
      e.value,
    ))
        .toList();

    return _AnalyticsCard(
      title: 'Subject Engagement',
      subtitle: 'Time spent per subject (hours)',
      child: Container(
        height: 200,
        child: SfCartesianChart(
          primaryXAxis: CategoryAxis(),
          series: <ChartSeries>[
            BarSeries<ChartData, String>(
              dataSource: chartData,
              xValueMapper: (ChartData data, _) => data.x,
              yValueMapper: (ChartData data, _) => data.y,
              color: Colors.blue[400],
              borderRadius: BorderRadius.circular(4),
              dataLabelSettings: DataLabelSettings(isVisible: true),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyProgressChart() {
    return _AnalyticsCard(
      title: 'Weekly Study Pattern',
      subtitle: 'Daily reading hours (June 2025)',
      child: Container(
        height: 200,
        child: SfCartesianChart(
          primaryXAxis: CategoryAxis(),
          series: <ChartSeries>[
            LineSeries<WeeklyProgress, String>(
              dataSource: weeklyProgress,
              xValueMapper: (WeeklyProgress data, _) => data.day,
              yValueMapper: (WeeklyProgress data, _) => data.hours,
              markerSettings: MarkerSettings(isVisible: true),
              color: Colors.green[400],
              dataLabelSettings: DataLabelSettings(isVisible: true),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudyRecommendations() {
    final sortedSubjects = subjectPerformance.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    final weakestSubject = sortedSubjects.isNotEmpty ? sortedSubjects.first.key : 'No data';
    final strongestSubject = sortedSubjects.isNotEmpty ? sortedSubjects.last.key : 'No data';

    return _AnalyticsCard(
      title: 'Study Recommendations',
      child: Column(
        children: [
          ...recommendations.map((rec) => _RecommendationTile(
            icon: Icons.lightbulb_outline,
            color: Colors.blue,
            title: rec.title,
            content: rec.content,
          )),
          _RecommendationTile(
            icon: Icons.warning_amber,
            color: Colors.orange,
            title: 'Focus Area',
            content: 'Your weakest subject is $weakestSubject. Consider spending more time on this topic.',
          ),
          _RecommendationTile(
            icon: Icons.star,
            color: Colors.green,
            title: 'Strength',
            content: 'You excel in $strongestSubject. Try more advanced materials in this area.',
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    return _AnalyticsCard(
      title: 'Recent Activity',
      child: Column(
        children: [
          for (var activity in recentActivities) ...[
            _ActivityItem(
              icon: activity.icon,
              title: activity.title,
              subtitle: activity.subtitle,
              time: activity.time,
              color: activity.color,
            ),
            if (activity != recentActivities.last) Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _AnalyticsCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const _AnalyticsCard({
    required this.title,
    this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (subtitle != null) ...[
              SizedBox(height: 8),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
            SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _SummaryCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 24, color: color),
              ),
              SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              SizedBox(height: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecommendationTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String content;

  const _RecommendationTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color),
          ),
          title: Text(
            title,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          subtitle: Text(
            content,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Divider(height: 1),
      ],
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String time;
  final Color color;

  const _ActivityItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: color),
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.bodyLarge,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        time,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Colors.grey[600],
        ),
      ),
    );
  }
}

class ChartData {
  final String x;
  final double y;

  ChartData(this.x, this.y);
}

class WeeklyProgress {
  final String day;
  final int hours;

  WeeklyProgress(this.day, this.hours);
}

class Recommendation {
  final String title;
  final String content;

  Recommendation(this.title, this.content);
}

class RecentActivity {
  final IconData icon;
  final String title;
  final String subtitle;
  final String time;
  final Color color;

  RecentActivity({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.color,
  });
}