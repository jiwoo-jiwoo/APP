import 'package:flutter/material.dart';

import '../services/learning_storage.dart';
import 'problem_screen.dart';

class LearningHistoryDetailScreen extends StatefulWidget {
  final Map<String, dynamic> record;
  final int? onlyQuestionNumber;

  const LearningHistoryDetailScreen({
    super.key,
    required this.record,
    this.onlyQuestionNumber,
  });

  @override
  State<LearningHistoryDetailScreen> createState() =>
      _LearningHistoryDetailScreenState();
}

class _LearningHistoryDetailScreenState
    extends State<LearningHistoryDetailScreen> {
  late Map<String, dynamic> _record;

  bool _openingReview = false;

  @override
  void initState() {
    super.initState();
    _record = Map<String, dynamic>.from(widget.record);
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _showRetryUnavailable() {
    _showMessage(
      '이 기록에는 다시 풀기에 필요한 정보가 없어요. '
      '새로 학습한 문제부터 이용할 수 있어요.',
    );
  }

  Future<void> _reloadRecord() async {
    final records = await LearningStorage.loadSessions();
    final completedAt = _record['completedAt']?.toString();

    Map<String, dynamic>? updatedRecord;

    for (final record in records) {
      if (record['completedAt']?.toString() == completedAt) {
        updatedRecord = record;
        break;
      }
    }

    if (updatedRecord == null) {
      throw StateError('학습 기록을 찾지 못했습니다.');
    }

    if (!mounted) return;

    final latestRecord = updatedRecord;

    setState(() {
      _record = Map<String, dynamic>.from(latestRecord);
    });
  }

  Future<void> _retryQuestion(
    Map<String, dynamic> answer,
    int fallbackQuestionNumber,
  ) async {
    if (_openingReview) return;

    final completedAt = _record['completedAt']?.toString();
    final questionNumber = int.tryParse(
      '${answer['questionNumber'] ?? fallbackQuestionNumber}',
    );

    if (completedAt == null || completedAt.isEmpty || questionNumber == null) {
      _showRetryUnavailable();
      return;
    }

    late final PracticeQuestion question;

    try {
      final rawCorrectIndex = answer['correctIndex'];

      question = PracticeQuestion.fromJson({
        ...answer,
        'title': answer['title']?.toString() ?? '오답 복습',
        'question': answer['question']?.toString() ?? '',
        'explanation': answer['explanation']?.toString() ?? '해설이 없어요.',
        'correctIndex': rawCorrectIndex is int
            ? rawCorrectIndex
            : int.tryParse(rawCorrectIndex?.toString() ?? '') ?? -1,
      });
    } catch (_) {
      _showRetryUnavailable();
      return;
    }

    setState(() {
      _openingReview = true;
    });

    try {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => ProblemScreen(
            topic: _record['topic']?.toString() ?? '오답 복습',
            reviewQuestion: question,
            onReviewCompleted: () {
              return LearningStorage.markReviewCompleted(
                completedAt: completedAt,
                questionNumber: questionNumber,
              );
            },
          ),
        ),
      );

      if (!mounted) return;

      await _reloadRecord();
    } catch (_) {
      _showMessage(
        '복습 화면을 열거나 최신 상태를 불러오지 못했어요. '
        '학습 기록으로 나갔다가 다시 들어와 주세요.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _openingReview = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rawAnswers = _record['answers'];

    final answers = rawAnswers is List
        ? rawAnswers
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
        : <Map<String, dynamic>>[];
    final visibleIndexes = List<int>.generate(answers.length, (index) => index)
        .where((index) {
          final onlyQuestionNumber = widget.onlyQuestionNumber;

          if (onlyQuestionNumber == null) {
            return true;
          }

          final savedNumber = int.tryParse(
            '${answers[index]['questionNumber'] ?? index + 1}',
          );

          return savedNumber == onlyQuestionNumber;
        })
        .toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(_record['topic']?.toString() ?? '학습 상세'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF171717),
      ),

      body: visibleIndexes.isEmpty
          ? Center(
              child: Text(
                answers.isEmpty
                    ? '저장된 문제별 답변이 없어요.'
                    : '모든 오답의 복습이 완료됐어요!\n'
                          '스위치를 끄면 완료한 문제도 볼 수 있어요.',
                textAlign: TextAlign.center,
                style: const TextStyle(height: 1.8),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(24),
              itemCount: visibleIndexes.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, visibleIndex) {
                final index = visibleIndexes[visibleIndex];
                final answer = answers[index];

                final isCorrect = answer['isCorrect'] == true;
                final isWrong = answer['isCorrect'] == false;
                final reviewCompleted = answer['reviewCompleted'] == true;

                final resultColor = isCorrect
                    ? const Color(0xFF278B4B)
                    : const Color(0xFFC94B4B);

                final reviewColor = reviewCompleted
                    ? const Color(0xFF278B4B)
                    : const Color(0xFFC94B4B);

                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F1FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '문제 ${answer['questionNumber'] ?? index + 1}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF7652FF),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            isCorrect ? '첫 풀이: 정답' : '첫 풀이: 오답',
                            style: TextStyle(
                              color: resultColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (isWrong)
                            Text(
                              reviewCompleted ? '복습 완료 ✓' : '미복습',
                              style: TextStyle(
                                color: reviewColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                      if (isWrong && reviewCompleted) ...[
                        const SizedBox(height: 8),
                        const Text(
                          '다시 풀어 정답을 맞힌 문제예요.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF278B4B),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text(
                        answer['title']?.toString() ?? '문제',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        answer['question']?.toString() ?? '',
                        style: const TextStyle(fontSize: 17, height: 1.5),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        '처음 제출한 답: '
                        '${answer['selectedAnswer'] ?? '정보 없음'}',
                        style: TextStyle(
                          fontSize: 16,
                          color: resultColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '정답: ${answer['correctAnswer'] ?? '정보 없음'}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      const Text(
                        '해설',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        answer['explanation']?.toString() ?? '해설이 없어요.',
                        style: const TextStyle(fontSize: 15, height: 1.6),
                      ),
                      if (isWrong) ...[
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _openingReview
                                ? null
                                : () => _retryQuestion(answer, index + 1),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: reviewCompleted
                                  ? const Color(0xFF278B4B)
                                  : const Color(0xFF9F86F7),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              reviewCompleted ? '복습 완료 · 한 번 더 풀기' : '오답 다시 풀기',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
    );
  }
}
