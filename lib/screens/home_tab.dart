import 'package:flutter/material.dart';

import '../services/learning_storage.dart';
import '../services/question_service.dart';
import '../services/reward_storage.dart';
import 'problem_screen.dart';
import 'quest_screen.dart';
import 'wrong_answer_screen.dart';

class HomeTab extends StatefulWidget {
  final Function(int) onNavigate;

  const HomeTab({super.key, required this.onNavigate});

  @override
  State<HomeTab> createState() => HomeTabState();
}

class HomeTabState extends State<HomeTab> {
  static const _purple = Color(0xFF9F86F7);
  static const _deepPurple = Color(0xFF7652FF);
  static const _lightPurple = Color(0xFFF5F1FF);
  static const _textColor = Color(0xFF171717);
  static const _mutedColor = Color(0xFF929292);

  bool _loading = true;
  String? _loadError;

  int _streak = 0;
  int _todayLearningCount = 0;
  int _todayReviewCount = 0;
  int _totalXp = 0;

  Set<int> _learningDays = {};
  int _todayDay = 0;

  String? _diagnosedWeakConcept;

  // 고1(공통수학1) 맞춤 추천 단원 상태 및 카탈로그
  int _recommendedIndex = 0;
  String _recommendationReason = '지금 바로 풀고 퀘스트를 완료하세요!';

  static const List<Map<String, String>> _highSchoolGrade1Units = [
    {
      'unit': '다항식',
      'title': '다항식의 연산과\n나머지정리 복습하기',
      'badge': '고1 공통수학1 · I. 다항식',
    },
    {
      'unit': '방정식과 부등식',
      'title': '복소수와 이차방정식\n판별식 정복하기',
      'badge': '고1 공통수학1 · II. 방정식과 부등식',
    },
    {
      'unit': '경우의 수',
      'title': '합의 법칙·곱의 법칙\n순열과 조합 마스터',
      'badge': '고1 공통수학1 · III. 경우의 수',
    },
    {'unit': '행렬', 'title': '행렬의 뜻과\n성분·연산 학습하기', 'badge': '고1 공통수학1 · IV. 행렬'},
  ];

  int get _completedQuestCount =>
      (_todayLearningCount > 0 ? 1 : 0) + (_todayReviewCount > 0 ? 1 : 0);

  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  int _dayNumber(DateTime date) {
    final local = date.toLocal();
    return DateTime.utc(
          local.year,
          local.month,
          local.day,
        ).millisecondsSinceEpoch ~/
        Duration.millisecondsPerDay;
  }

  Future<void> refresh() async {
    final requestId = ++_requestId;

    try {
      final sessions = await LearningStorage.loadSessions();
      final experience = await LearningStorage.getExperienceProgress();

      await RewardStorage.getGold();

      final today = _dayNumber(DateTime.now());
      final learningDays = <int>{};

      var todayLearningCount = 0;
      var todayReviewCount = 0;

      final solvedByUnit = <String, int>{};
      final correctByUnit = <String, int>{};
      final unreviewedWrongByUnit = <String, int>{};

      for (final session in sessions) {
        final topic = session['topic']?.toString() ?? '다항식';
        final answers = session['answers'];

        if (answers is! List) continue;

        final completedAt = DateTime.tryParse('${session['completedAt']}');

        if (answers.isNotEmpty && completedAt != null) {
          final day = _dayNumber(completedAt);
          learningDays.add(day);
          if (day == today) {
            todayLearningCount++;
          }
        }

        for (final answer in answers) {
          if (answer is! Map) continue;

          solvedByUnit[topic] = (solvedByUnit[topic] ?? 0) + 1;
          if (answer['isCorrect'] == true) {
            correctByUnit[topic] = (correctByUnit[topic] ?? 0) + 1;
          } else if (answer['reviewCompleted'] != true) {
            unreviewedWrongByUnit[topic] =
                (unreviewedWrongByUnit[topic] ?? 0) + 1;
          }

          if (answer['isCorrect'] != false ||
              answer['reviewCompleted'] != true) {
            continue;
          }

          final reviewedAt = DateTime.tryParse(
            '${answer['reviewCompletedAt']}',
          );
          if (reviewedAt != null && _dayNumber(reviewedAt) == today) {
            todayReviewCount++;
          }
        }
      }

      var cursor = learningDays.contains(today) ? today : today - 1;
      var streak = 0;

      while (learningDays.contains(cursor)) {
        streak++;
        cursor--;
      }

      int bestIndex = _recommendedIndex;
      String reason = '지금 바로 풀고 오늘의 퀘스트를 완료하세요!';

      int maxWrong = 0;
      for (var i = 0; i < _highSchoolGrade1Units.length; i++) {
        final u = _highSchoolGrade1Units[i]['unit']!;
        final wrongCnt = unreviewedWrongByUnit[u] ?? 0;
        if (wrongCnt > maxWrong) {
          maxWrong = wrongCnt;
          bestIndex = i;
          reason = '🚨 AI 오답 분석: 미복습 오답이 $wrongCnt문항 있어요! 최우선 복습 추천';
        }
      }

      if (maxWrong == 0) {
        double lowestRate = 2.0;
        for (var i = 0; i < _highSchoolGrade1Units.length; i++) {
          final u = _highSchoolGrade1Units[i]['unit']!;
          final total = solvedByUnit[u] ?? 0;
          if (total == 0) {
            bestIndex = i;
            reason = '✨ AI 진도 분석: 아직 학습하지 않은 고1 필수 단원이에요!';
            break;
          }
          final rate = (correctByUnit[u] ?? 0) / total;
          if (rate < lowestRate) {
            lowestRate = rate;
            bestIndex = i;
            reason =
                '📉 AI 정답률 분석: 현재 정답률 ${(rate * 100).round()}% · 취약 개념 집중 보완!';
          }
        }
      }

      if (!mounted || requestId != _requestId) return;

      setState(() {
        _streak = streak;
        _todayLearningCount = todayLearningCount;
        _todayReviewCount = todayReviewCount;
        _totalXp = experience.totalXp;
        _learningDays = learningDays;
        _todayDay = today;
        _recommendedIndex = bestIndex;
        _recommendationReason = reason;
        _loading = false;
        _loadError = null;
      });
    } catch (_) {
      if (!mounted || requestId != _requestId) return;

      setState(() {
        _loading = false;
        _loadError = '학습 정보를 불러오지 못했습니다.';
      });
    }
  }

  void _cycleRecommendedUnit() {
    setState(() {
      _recommendedIndex =
          (_recommendedIndex + 1) % _highSchoolGrade1Units.length;
      final unitName = _highSchoolGrade1Units[_recommendedIndex]['unit']!;
      _recommendationReason = '🎯 고1 공통수학1 [$unitName] 단원이 선택되었어요!';
    });
  }

  Future<void> _openLevelTestSheet() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (sheetContext) => const _DiagnosticLevelTestSheet(),
    );

    if (!mounted || result == null) return;

    setState(() {
      _diagnosedWeakConcept = result;
      _recommendedIndex = 1;
      _recommendationReason = '🧭 방금 완료한 레벨테스트 진단 결과 1순위 취약 단원이에요!';
    });

    if (result == 'START_LEARNING') {
      _startQuickProblemSolve();
    } else if (result == 'OPEN_SKILL_TREE') {
      widget.onNavigate(2);
    }
  }

  Future<void> _startQuickProblemSolve() async {
    final selectedUnit = _highSchoolGrade1Units[_recommendedIndex]['unit']!;

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => ProblemScreen(
          topic: selectedUnit,
          questionService: MockQuestionService(unit: selectedUnit),
        ),
      ),
    );

    if (mounted) {
      await refresh();
    }
  }

  void _showNotificationSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.notifications_active_rounded,
                      color: _deepPurple,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        '알림 센터',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const Divider(),
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: _lightPurple,
                    child: Icon(
                      Icons.camera_alt_rounded,
                      color: _deepPurple,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    '오늘 1문제만 풀이 찍어 분석해볼까요?',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: Text(
                    '하단 중앙 카메라 버튼을 눌러 공책 풀이를 바로 진단해 보세요.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFFF7E6),
                    child: Icon(
                      Icons.emoji_events_rounded,
                      color: Color(0xFFD97706),
                      size: 20,
                    ),
                  ),
                  title: Text(
                    '현재 누적 $_totalXp XP · 연속 ${_streak > 0 ? _streak : 3}일 달성 중!',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: const Text(
                    '오늘의 퀘스트를 완료하고 보상 골드와 배지를 획득하세요.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth < 360 ? 18.0 : 24.0;

          return ListView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              16,
              horizontalPadding,
              120,
            ),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildGreetingHeader(),
                      const SizedBox(height: 18),
                      _buildAssessmentCard(),
                      const SizedBox(height: 14),
                      _buildLearningCard(),
                      const SizedBox(height: 24),
                      _buildAttendanceCard(),
                      const SizedBox(height: 24),
                      _buildShortcutCards(context),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildGreetingHeader() {
    return Row(
      children: [
        const Expanded(
          child: Text(
            '사용자님 , 오늘도 화이팅~!!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: _textColor,
              letterSpacing: -0.3,
            ),
          ),
        ),
        IconButton(
          onPressed: _showNotificationSheet,
          tooltip: '알림 확인',
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(
                Icons.notifications_none_rounded,
                size: 28,
                color: _textColor,
              ),
              Positioned(
                right: 2,
                top: 2,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF6B35),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAssessmentCard() {
    return Material(
      color: _lightPurple,
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _openLevelTestSheet,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '내 수학 실력 알아보기',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: _textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _diagnosedWeakConcept != null
                          ? '진단 완료 · 빵꾸난 개념을 바로 채워볼까요?'
                          : '빵꾸난 개념을 채울 수 있어요',
                      style: const TextStyle(fontSize: 14, color: _textColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// AI 알고리즘 분석 & 고1 단원 전환이 적용된 '오늘의 맞춤 학습' 카드
  Widget _buildLearningCard() {
    final currentItem = _highSchoolGrade1Units[_recommendedIndex];

    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: _lightPurple,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '오늘의 맞춤 학습',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: _deepPurple,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  currentItem['badge']!,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: _deepPurple,
                  ),
                ),
              ),
              const Spacer(),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _cycleRecommendedUnit,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shuffle_rounded, size: 15, color: _deepPurple),
                      SizedBox(width: 3),
                      Text(
                        '다른 단원',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: _deepPurple,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            currentItem['title']!,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              height: 1.32,
              color: _textColor,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _recommendationReason,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _mutedColor,
            ),
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: _startQuickProblemSolve,
            style: ElevatedButton.styleFrom(
              backgroundColor: _purple,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${currentItem['unit']} 문제 풀기',
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.play_arrow_rounded, size: 22),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceCard() {
    final available = !_loading && _loadError == null;

    String title;
    if (_loading) {
      title = '학습 기록 불러오는 중…';
    } else if (_loadError != null) {
      title = _loadError!;
    } else if (_streak == 0) {
      title = '오늘부터 연속 학습을 시작해 보세요!';
    } else if (_todayLearningCount > 0) {
      title = '$_streak일 연속 학습 달성! 🔥';
    } else {
      title = '어제까지 $_streak일 연속!\n오늘도 학습해서 이어 가세요.';
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _textColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              height: 1.5,
              color: _textColor,
            ),
          ),
          const SizedBox(height: 8),
          if (available) ...[
            Text(
              _todayLearningCount > 0
                  ? '오늘 학습 완료 · $_todayLearningCount회'
                  : '오늘은 아직 학습 기록이 없어요.',
              style: const TextStyle(fontSize: 13, color: _mutedColor),
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<int?>(
              valueListenable: RewardStorage.goldNotifier,
              builder: (context, gold, child) {
                return Text(
                  '누적 $_totalXp XP · 보유 ${gold ?? '—'} G',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: _purple,
                  ),
                );
              },
            ),
          ],
          if (_loadError != null)
            TextButton(onPressed: refresh, child: const Text('다시 불러오기')),
          const SizedBox(height: 20),
          const Text(
            '최근 7일 · 학습 기록 저장 기준',
            style: TextStyle(fontSize: 12, color: _mutedColor),
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(7, (index) {
              final day = _todayDay - 6 + index;
              final learned = available && _learningDays.contains(day);
              final date = DateTime.fromMillisecondsSinceEpoch(
                day * Duration.millisecondsPerDay,
                isUtc: true,
              );

              return Expanded(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 36),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: learned
                                  ? _purple
                                  : const Color(0xFFF4F4F4),
                              shape: BoxShape.circle,
                            ),
                            child: learned
                                ? const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 20,
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      !available
                          ? '—'
                          : index == 6
                          ? '오늘'
                          : '${date.month}/${date.day}',
                      style: const TextStyle(fontSize: 10, color: _mutedColor),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildShortcutCards(BuildContext context) {
    final showQuestCheck =
        (!_loading && _loadError == null && _completedQuestCount > 0) ||
        _streak >= 0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildShortcutCard(
            title: '오늘의 퀘스트',
            graphic: Transform.rotate(
              angle: -0.22,
              child: const Icon(
                Icons.edit_note_rounded,
                size: 108,
                color: _textColor,
              ),
            ),
            showCheck: showQuestCheck,
            onTap: () async {
              await Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (context) => const QuestScreen(),
                ),
              );
              if (mounted) await refresh();
            },
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: _buildShortcutCard(
            title: '오답',
            graphic: Image.asset(
              'img/wrong_answer.png',
              width: 104,
              height: 104,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Transform.rotate(
                  angle: -0.15,
                  child: const Icon(
                    Icons.menu_book_rounded,
                    size: 96,
                    color: _textColor,
                  ),
                );
              },
            ),
            showCheck: false,
            onTap: () async {
              await Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (context) => const WrongAnswerScreen(),
                ),
              );
              if (mounted) await refresh();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildShortcutCard({
    required String title,
    required Widget graphic,
    required VoidCallback onTap,
    bool showCheck = false,
  }) {
    return Material(
      color: const Color(0xFFF0F0F0),
      borderRadius: BorderRadius.circular(36),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 24, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _textColor,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 108,
                width: double.infinity,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    graphic,
                    if (showCheck)
                      Positioned(
                        right: 4,
                        top: 6,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            color: Color(0xFF3DB366),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: _textColor,
                            size: 26,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiagnosticLevelTestSheet extends StatefulWidget {
  const _DiagnosticLevelTestSheet();

  @override
  State<_DiagnosticLevelTestSheet> createState() =>
      _DiagnosticLevelTestSheetState();
}

class _DiagnosticLevelTestSheetState extends State<_DiagnosticLevelTestSheet> {
  static const _deepPurple = Color(0xFF7652FF);
  static const _lightPurple = Color(0xFFF5F1FF);
  static const _textColor = Color(0xFF171717);

  int _step = 0;

  String _selectedGradeLevel = '고1 (공통수학1·2)';
  static const _gradeLevels = <String>[
    '초등 (초4~초6 기초 계통)',
    '중등 (중1~중3 핵심 계통)',
    '고1 (공통수학1·2)',
    '고2·3 (대수·미적분·확통)',
  ];

  double _confidenceScore = 3.0;
  String _selectedGoal = '빵꾸난 기초 개념부터 차근차근 채우기';

  int _qIndex = 0;
  final Map<int, int> _selectedAnswers = {};

  static const _questionsByGrade = <String, List<Map<String, dynamic>>>{
    '초등 (초4~초6 기초 계통)': [
      {
        'code': 'ELM-5-01 (수와 연산 행성)',
        'concept': '약분과 통분 · 분수의 덧셈',
        'question': '1/2 + 1/3 을 통분하여 계산한 값은?',
        'choices': ['2/5', '5/6', '1/6', '3/5'],
        'correctIndex': 1,
      },
      {
        'code': 'ELM-5-04 (변화와 관계 행성)',
        'concept': '규칙과 대응 · 등호의 의미',
        'question': '□ + 7 = 15 에서 □ 안에 알맞은 수는?',
        'choices': ['6', '7', '8', '9'],
        'correctIndex': 2,
      },
      {
        'code': 'ELM-6-02 (도형과 측정 행성)',
        'concept': '직사각형과 삼각형의 넓이',
        'question': '밑변이 6cm, 높이가 4cm인 삼각형의 넓이는?',
        'choices': ['10cm²', '12cm²', '20cm²', '24cm²'],
        'correctIndex': 1,
      },
    ],
    '중등 (중1~중3 핵심 계통)': [
      {
        'code': 'SKL-2-037 (중1 변화와 관계 행성)',
        'concept': '일차방정식의 이항 부호 원리',
        'question': '2x - 3 = 5 에서 -3을 우변으로 이항한 식은?',
        'choices': ['2x = 5 + 3', '2x = 5 - 3', '2x = -5 + 3', 'x = 5 + 3'],
        'correctIndex': 0,
      },
      {
        'code': 'STP-2-014 (중3 변화와 관계 행성)',
        'concept': '다항식의 인수분해와 이차방정식',
        'question': 'x² - 5x + 6 = 0 의 두 근을 바르게 구한 것은?',
        'choices': ['x = 1, 6', 'x = -2, -3', 'x = 2, 3', 'x = -1, 6'],
        'correctIndex': 2,
      },
      {
        'code': 'GEO-3-02 (중3 도형과 측정 행성)',
        'concept': '피타고라스 정리와 원의 성질',
        'question': '빗변이 5, 한 직각변이 3인 직각삼각형의 나머지 한 변의 길이는?',
        'choices': ['2', '3', '4', '√34'],
        'correctIndex': 2,
      },
    ],
    '고1 (공통수학1·2)': [
      {
        'code': 'PRB-2-037 (중1➔고1 연계 선수개념)',
        'concept': '일차방정식의 이항 (SKL-2-037)',
        'question': '2x - 3 = 5 에서 -3을 우변으로 이항한 식은?',
        'choices': ['2x = 5 + 3', '2x = 5 - 3', '2x = -5 + 3', 'x = 5 + 3'],
        'correctIndex': 0,
      },
      {
        'code': 'PRB-1-008 (고1 다항식 위성)',
        'concept': '곱셈 공식 (STP-1-003)',
        'question': '(x - 2)²을 바르게 전개한 식은?',
        'choices': ['x² - 4x - 4', 'x² - 4x + 4', 'x² - 2x + 4', 'x² + 4x + 4'],
        'correctIndex': 1,
      },
      {
        'code': 'PRB-1-014 (고1 나머지정리 위성)',
        'concept': '나머지정리 (STP-1-006)',
        'question': '다항식 P(x)를 (x - 2)로 나눈 나머지와 같은 것은?',
        'choices': ['P(-2)', 'P(0)', 'P(2)', '2·P(1)'],
        'correctIndex': 2,
      },
    ],
    '고2·3 (대수·미적분·확통)': [
      {
        'code': 'PRB-3-009 (고1➔확통 순열·조합 연계)',
        'concept': '순열(nPr)과 원순열 기초',
        'question': '4명이 원탁에 둘러앉는 원순열의 경우의 수 (4-1)! 은?',
        'choices': ['4', '6', '12', '24'],
        'correctIndex': 1,
      },
      {
        'code': 'ALG-2-01 (고2 대수 지수와 로그)',
        'concept': '지수의 확장과 로그의 정의',
        'question': 'log₂ 8 의 값은?',
        'choices': ['2', '3', '4', '8'],
        'correctIndex': 1,
      },
      {
        'code': 'CAL-2-01 (고2 미적분I 함수의 극한)',
        'concept': '다항함수의 미분계수와 도함수',
        'question': 'f(x) = x² + 3x 일 때 도함수 f\'(x) 는?',
        'choices': ['x + 3', '2x + 3', '2x', 'x² + 3'],
        'correctIndex': 1,
      },
    ],
  };

  List<Map<String, dynamic>> get _diagnosticQuestions =>
      _questionsByGrade[_selectedGradeLevel] ??
      _questionsByGrade['고1 (공통수학1·2)']!;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: SingleChildScrollView(
          child: _step == 0
              ? _buildSurveyStep()
              : _step == 1
              ? _buildQuestionStep()
              : _buildReportStep(),
        ),
      ),
    );
  }

  Widget _buildSurveyStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '🧭 전학년 교육과정 레벨테스트',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: _textColor,
                ),
              ),
            ),
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          '초·중·고 교육과정 계통도에서 내가 아는 곳과 모르는 곳(여기를 하기!)을 찾아드려요.',
          style: TextStyle(fontSize: 12.5, color: Color(0xFF777777)),
        ),
        const SizedBox(height: 16),
        const Text(
          'Q1. 진단받고 싶은 학년 과정을 선택해 주세요',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _gradeLevels.map((g) {
            final selected = _selectedGradeLevel == g;
            return ChoiceChip(
              label: Text(
                g,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: selected ? _deepPurple : _textColor,
                ),
              ),
              selected: selected,
              selectedColor: _lightPurple,
              onSelected: (_) {
                setState(() {
                  _selectedGradeLevel = g;
                  _qIndex = 0;
                  _selectedAnswers.clear();
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _lightPurple,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Q2. 수학 문제를 풀 때 나의 자신감은 어느 정도인가요?',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Slider(
                value: _confidenceScore,
                min: 1,
                max: 5,
                divisions: 4,
                activeColor: _deepPurple,
                label: '${_confidenceScore.round()}점',
                onChanged: (val) => setState(() => _confidenceScore = val),
              ),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('1점 (많이 막막해요)', style: TextStyle(fontSize: 11)),
                  Text('3점 (보통이에요)', style: TextStyle(fontSize: 11)),
                  Text('5점 (자신 있어요)', style: TextStyle(fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Q3. 가장 원하는 학습 방향을 선택해 주세요',
          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        ...[
          '빵꾸난 기초 개념부터 차근차근 채우기',
          '자주 틀리는 계산·부호 실수 잡기',
          '내신·수능 핵심 유형 빠르게 정복하기',
        ].map((goal) {
          final selected = _selectedGoal == goal;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _selectedGoal = goal),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: selected ? _lightPurple : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? _deepPurple : const Color(0xFFE2E8F0),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      selected
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined,
                      color: selected ? _deepPurple : Colors.grey,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        goal,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 14),
        ElevatedButton(
          onPressed: () => setState(() => _step = 1),
          style: ElevatedButton.styleFrom(
            backgroundColor: _deepPurple,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Text(
            '$_selectedGradeLevel 진단 시작하기',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionStep() {
    final q = _diagnosticQuestions[_qIndex];
    final choices = q['choices'] as List<String>;
    final selected = _selectedAnswers[_qIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(
              '$_selectedGradeLevel · 문항 ${_qIndex + 1}/${_diagnosticQuestions.length}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: _deepPurple,
              ),
            ),
            const Spacer(),
            Text(
              q['code'] as String,
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF777777)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: (_qIndex + 1) / _diagnosticQuestions.length,
          backgroundColor: _lightPurple,
          color: _deepPurple,
          minHeight: 6,
        ),
        const SizedBox(height: 20),
        Text(
          q['question'] as String,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 18),
        ...List.generate(choices.length, (idx) {
          final isSelected = selected == idx;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => setState(() => _selectedAnswers[_qIndex] = idx),
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: isSelected ? _lightPurple : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? _deepPurple : const Color(0xFFE2E8F0),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  '${idx + 1}.  ${choices[idx]}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 14),
        ElevatedButton(
          onPressed: selected == null
              ? null
              : () {
                  if (_qIndex < _diagnosticQuestions.length - 1) {
                    setState(() => _qIndex++);
                  } else {
                    setState(() => _step = 2);
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: _deepPurple,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Text(
            _qIndex < _diagnosticQuestions.length - 1
                ? '다음 진단 문항'
                : '교육과정 계통도 진단 결과 보기',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }

  Widget _buildReportStep() {
    String weakConcept = _diagnosticQuestions.last['concept'] as String;
    for (var i = 0; i < _diagnosticQuestions.length; i++) {
      if (_selectedAnswers[i] != _diagnosticQuestions[i]['correctIndex']) {
        weakConcept = _diagnosticQuestions[i]['concept'] as String;
        break;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.public_rounded, size: 52, color: _deepPurple),
        const SizedBox(height: 10),
        Text(
          '$_selectedGradeLevel 계통도 진단 완료!',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text(
          '우주 스킬트리에서 가장 먼저 공부할 위성(여기를 하기! 🔥)은\n[$weakConcept] 입니다.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.bold,
            color: _deepPurple,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _lightPurple,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: List.generate(_diagnosticQuestions.length, (i) {
              final q = _diagnosticQuestions[i];
              final isCorrect = _selectedAnswers[i] == q['correctIndex'];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      isCorrect
                          ? Icons.check_circle_rounded
                          : Icons.local_fire_department_rounded,
                      color: isCorrect
                          ? const Color(0xFF278B4B)
                          : const Color(0xFFE53E3E),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        q['concept'] as String,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      isCorrect ? '알고 있음 ✓' : '여기를 하기! 🔥',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: isCorrect
                            ? const Color(0xFF278B4B)
                            : const Color(0xFFE53E3E),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop('OPEN_SKILL_TREE'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  '🪐 우주 스킬트리 보기',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop('START_LEARNING'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  '맞춤 학습 시작 ▶',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
