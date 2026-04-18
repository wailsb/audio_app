import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/user_model.dart';
import '../services/stats_service.dart';
import '../services/auth_service.dart';
import 'player_screen.dart';
import 'favorites_screen.dart';
import 'biometric_screen.dart';

class HomeScreen extends StatefulWidget {
  final UserModel user;
  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final StatsService _statsService = StatsService();
  final AuthService _authService = AuthService();

  int _currentIndex = 0;
  bool _loading = true;

  Map<String, double> _dailyMinutes = {};
  Duration _monthlyTotal = Duration.zero;
  List<Map<String, dynamic>> _topTracks = [];
  int _goalHours = 20;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    final uid = widget.user.uid;
    final daily = await _statsService.getMonthlyDailyMinutes(uid);
    final total = await _statsService.getMonthlyTotal(uid);
    final top = await _statsService.getTopTracks(uid);
    final goal = await _statsService.getMonthlyGoalHours();
    setState(() {
      _dailyMinutes = daily;
      _monthlyTotal = total;
      _topTracks = top;
      _goalHours = goal;
      _loading = false;
    });
  }

  Future<void> _logout() async {
    await _authService.logout();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const BiometricScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildStatsPage(),
      PlayerScreen(uid: widget.user.uid),
      FavoritesScreen(uid: widget.user.uid),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D1A),
        title: const Text('AudioSecure',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white54),
            onPressed: _logout,
          ),
        ],
      ),
      body: pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        backgroundColor: const Color(0xFF1A1A2E),
        selectedItemColor: const Color(0xFF6C63FF),
        unselectedItemColor: Colors.white38,
        onTap: (i) => setState(() => _currentIndex = i),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart), label: 'Statistiques'),
          BottomNavigationBarItem(
              icon: Icon(Icons.play_circle_outline), label: 'Lecteur'),
          BottomNavigationBarItem(
              icon: Icon(Icons.favorite_border), label: 'Favoris'),
        ],
      ),
    );
  }

  Widget _buildStatsPage() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF6C63FF)));
    }

    final totalHours = _monthlyTotal.inHours;
    final totalMinutes = _monthlyTotal.inMinutes % 60;
    final progress = (_monthlyTotal.inMinutes / 60) / _goalHours;

    return RefreshIndicator(
      onRefresh: _loadStats,
      color: const Color(0xFF6C63FF),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Message de bienvenue
            RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 20, color: Colors.white70),
                children: [
                  const TextSpan(text: 'Bienvenue, '),
                  TextSpan(
                    text: widget.user.fullName,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const TextSpan(text: ' 👋'),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Total d'écoute
            _card(
              child: Row(
                children: [
                  const Icon(Icons.headphones_rounded,
                      color: Color(0xFF6C63FF), size: 40),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Temps d\'écoute ce mois',
                          style: TextStyle(color: Colors.white54, fontSize: 13)),
                      Text(
                        '${totalHours}h ${totalMinutes}min',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Objectif mensuel
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Objectif mensuel',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                      DropdownButton<int>(
                        value: _goalHours,
                        dropdownColor: const Color(0xFF1A1A2E),
                        style: const TextStyle(color: Color(0xFF6C63FF)),
                        underline: const SizedBox(),
                        items: [10, 15, 20, 30, 40, 50]
                            .map((h) => DropdownMenuItem(
                                value: h,
                                child: Text('$h h',
                                    style: const TextStyle(
                                        color: Color(0xFF6C63FF)))))
                            .toList(),
                        onChanged: (v) async {
                          if (v == null) return;
                          await _statsService.setMonthlyGoalHours(v);
                          setState(() => _goalHours = v);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF6C63FF)),
                      minHeight: 10,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${(totalHours + totalMinutes / 60).toStringAsFixed(1)} / $_goalHours heures (${(progress * 100).clamp(0, 100).toStringAsFixed(0)}%)',
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Histogramme
            const Text('Minutes écoutées par jour',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
            const SizedBox(height: 12),
            _card(child: _buildBarChart()),

            const SizedBox(height: 20),

            // Top morceaux
            if (_topTracks.isNotEmpty) ...[
              const Text('Morceaux les plus écoutés',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
              const SizedBox(height: 12),
              ..._topTracks.map((t) => _topTrackTile(t)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart() {
    if (_dailyMinutes.isEmpty) {
      return const SizedBox(
        height: 140,
        child: Center(
          child: Text('Pas encore de données d\'écoute',
              style: TextStyle(color: Colors.white38)),
        ),
      );
    }

    final now = DateTime.now();
    final daysInMonth = DateUtils.getDaysInMonth(now.year, now.month);
    final bars = <BarChartGroupData>[];

    for (int day = 1; day <= daysInMonth; day++) {
      final key =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
      final minutes = _dailyMinutes[key] ?? 0.0;
      bars.add(BarChartGroupData(
        x: day,
        barRods: [
          BarChartRodData(
            toY: minutes,
            color: const Color(0xFF6C63FF),
            width: 6,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      ));
    }

    return SizedBox(
      height: 160,
      child: BarChart(
        BarChartData(
          barGroups: bars,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 5,
                getTitlesWidget: (val, _) => Text(
                  val.toInt().toString(),
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _topTrackTile(Map<String, dynamic> t) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.music_note, color: Color(0xFF6C63FF)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              t['title'] ?? 'Morceau',
              style: const TextStyle(color: Colors.white, fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${t['playCount'] ?? 0} écoutes',
            style:
                const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}
