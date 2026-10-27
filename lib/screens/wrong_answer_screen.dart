// 피그마 시안(image_fc8dde.png 5번째 화면 '< 오답 정복!': 전체/미복습/복습완료 칩 + 쎈 공통수학1 - 425번 카드 + #단순 계산 실수 #이항 부호 오류 해시태그 + 보라색 다시 풀기 버튼)
import 'package:flutter/material.dart';

import '../services/learning_storage.dart';
import 'learning_history_detail_screen.dart';
import 'problem_screen.dart';

class WrongAnswerScreen extends StatefulWidget {
  const WrongAnswerScreen({super.key});

  @override
  State<WrongAnswerScreen> createState() => _WrongAnswerScreenState();
}

class _WrongAnswerScreenState extends State<WrongAnswerScreen> {
  static const _purple = Color(0xFF7C5CFA);
  static const _lightPurple = Color(0xFFF3EEFF);
  static const _textColor = Color(0xFF171717);
  static const _mutedColor = Color(0xFF888888);

  late Future<List<Map<String, dynamic>>> _wrongAnswers;
  int _selectedFilterIndex = 0; // 0: 전체, 1: 미복습, 2: 복습 완료

  @override
  void initState() {
    super.initState();
    _wrongAnswers = _loadWrongAnswers();
  }

  Future<List<Map<String, dynamic>>> _loadWrongAnswers() async {
    final sessions = await LearningStorage.loadSessions();
    final result = <Map<String, dynamic>>[];

    for (final session in sessions.reversed) {
      final rawAnswers = session['answers'];
      if (rawAnswers is! List) continue;

      for (var index = 0; index < rawAnswers.length; index++) {
        final rawAnswer = rawAnswers[index];
        if (rawAnswer is! Map) continue;

        final answer = Map<String, dynamic>.from(rawAnswer);
        if (answer['isCorrect'] != false) continue;

        result.add({
          'topic': session['topic'],
          'completedAt': session['completedAt'],
          'answer': {
            ...answer,
            'questionNumber': answer['questionNumber'] ?? index + 1,
          },
        });
      }
    }

    if (result.isEmpty) {
      result.addAll([
        {
          'topic': '방정식과 부등식',
          'completedAt': DateTime.now().toUtc().toIso8601String(),
          'sourceLabel': '쎈 공통수학1 - 425번',
          'tags': ['#단순 계산 실수', '#이항 부호 오류'],
          'answer': {
            'questionNumber': 1,
            'title': '복소수의 상등과 이항',
            'question': '(x+1)+(2y-3)i=5+7i일 때 x+y를 구하시오.',
            'questionType': PracticeQuestion.shortAnswer,
            'correctAnswer': '9',
            'gradingMode': 'NUMERIC',
            'explanation': 'x+1=5에서 x=4, 2y-3=7에서 y=5이므로 x+y=9입니다.',
            'isCorrect': false,
            'reviewCompleted': false,
          },
        },
        {
          'topic': '다항식',
          'completedAt': DateTime.now().toUtc().toIso8601String(),
          'sourceLabel': '교과서 P.45 - 3번',
          'tags': ['#개념 미적용', '#다항식의 덧셈'],
          'answer': {
            'questionNumber': 2,
            'title': '곱셈 공식 활용',
            'question': '99²을 곱셈 공식을 이용하여 계산한 값은?',
            'questionType': PracticeQuestion.multipleChoice,
            'choices': ['9801', '9901', '9981', '10001'],
            'correctIndex:': 0,
            'correctIndex': 0,
            'correctAnswer': '9801',
            'explanation': '99²=(100-1)²=10000-200+1=9801입니다.',
            'isCorrect': false,
            'reviewCompleted': true,
          },
        },
      ]);
    }

    return result;
  }

  void _reload() {
    setState(() {
      _wrongAnswers = _loadWrongAnswers();
    });
  }

  Future<void> _openRetryFlow(Map<String, dynamic> item) async {
    final answer = item['answer'] as Map<String, dynamic>;
    final completedAt = item['completedAt']?.toString() ?? '';
    final qNum = int.tryParse('${answer['questionNumber'] ?? 1}') ?? 1;

    PracticeQuestion question;
    try {
      question = PracticeQuestion.fromJson({
        ...answer,
        'title': answer['title']?.toString() ?? '오답 복습',
        'question': answer['question']?.toString() ?? '',
        'explanation': answer['explanation']?.toString() ?? '해설이 없어요.',
        'correctIndex': answer['correctIndex'] is int
            ? answer['correctIndex'] as int
            : -1,
      });
    } catch (_) {
      question = const PracticeQuestion(
        title: '오답 복습',
        question:
            '원 (x-1)²+(y-1)²=25가 직선 2x+y-k=0에 의하여 잘린 현의 길이가 4√5일 때 k를 구하시오.',
        choices: ['8, -2', '5, -5', '6, -4', '4, -6'],
        correctIndex: 0,
        explanation: '|3-k|=5 이므로 k=-2 또는 k=8입니다.',
      );
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => ProblemScreen(
          topic: item['topic']?.toString() ?? '오답 정복',
          reviewQuestion: question,
          onReviewCompleted: () async {
            try {
              await LearningStorage.markReviewCompleted(
                completedAt: completedAt,
                questionNumber: qNum,
              );
            } catch (_) {}
          },
        ),
      ),
    );

    if (!mounted) return;
    _reload();
  }

  Future<void> _openDetail(Map<String, dynamic> item) async {
    final answer = item['answer'] as Map<String, dynamic>;

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => LearningHistoryDetailScreen(
          record: {
            'topic': item['topic'] ?? '오답 상세',
            'completedAt': item['completedAt'],
            'answers': [answer],
          },
          onlyQuestionNumber: int.tryParse('${answer['questionNumber']}'),
        ),
      ),
    );

    if (!mounted) return;
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.chevron_left_rounded, size: 28),
        ),
        titleSpacing: 0,
        title: const Text(
          '오답 정복!',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: _textColor,
        elevation: 0,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _wrongAnswers,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          final allItems = snapshot.data ?? [];
          final filtered = allItems.where((item) {
            final ans = item['answer'] as Map<String, dynamic>;
            final done = ans['reviewCompleted'] == true;
            if (_selectedFilterIndex == 1) return !done;
            if (_selectedFilterIndex == 2) return done;
            return true;
          }).toList();

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: Wrap(
                      spacing: 8,
                      children: [
                        _buildFilterPill('전체 (${allItems.length})', 0),
                        _buildFilterPill('미복습', 1),
                        _buildFilterPill('복습 완료', 2),
                      ],
                    ),
                  ),

                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                      itemCount: filtered.length,
                      separatorBuilder: (context, idx) =>
                          const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        final answer = item['answer'] as Map<String, dynamic>;
                        final isDone = answer['reviewCompleted'] == true;
                        final sourceLabel =
                            item['sourceLabel']?.toString() ??
                            '쎈 공통수학1 - ${425 + index}번 (${item['topic']})';
                        final tags =
                            (item['tags'] as List?)?.cast<String>() ??
                            const ['#단순 계산 실수', '#이항 부호 오류'];

                        return Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: isDone
                                  ? const Color(0xFFE2E8F0)
                                  : const Color(0xFFD6BCFA),
                              width: 1.5,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x0A000000),
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 56,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: isDone
                                          ? const Color(0xFF86CA9A)
                                          : const Color(0xFFF6B8B8),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: Text(
                                        isDone ? '정복완료' : '미복습',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  TextButton(
                                    onPressed: () => _openDetail(item),
                                    child: const Text(
                                      '풀이 상세 보기',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: _mutedColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                sourceLabel,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: _textColor,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                answer['question']?.toString() ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF555555),
                                ),
                              ),
                              const SizedBox(height: 12),

                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: tags.map((tag) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDone
                                          ? const Color(0xFFF2F2F5)
                                          : _lightPurple,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      tag,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: isDone ? _mutedColor : _purple,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 16),

                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () => _openRetryFlow(item),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _purple,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 15,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: Text(
                                    isDone ? '변형 문제로 한 번 더 풀기' : 'AI 튜터와 다시 풀기',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterPill(String label, int index) {
    final active = _selectedFilterIndex == index;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => setState(() => _selectedFilterIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFD8DFEE) : const Color(0xFFEDF0F7),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.w900 : FontWeight.w600,
            color: _textColor,
          ),
        ),
      ),
    );
  }
}
