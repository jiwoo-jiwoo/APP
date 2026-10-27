import 'package:flutter/material.dart';

import '../services/learning_storage.dart';
import 'learning_history_detail_screen.dart';
import 'problem_screen.dart';

enum _HistoryView { history, unreviewed, reviewed }

class LearningHistoryScreen extends StatefulWidget {
  const LearningHistoryScreen({super.key});

  @override
  State<LearningHistoryScreen> createState() => _LearningHistoryScreenState();
}

class _LearningHistoryScreenState extends State<LearningHistoryScreen> {
  late Future<List<Map<String, dynamic>>> _records;

  _HistoryView _view = _HistoryView.history;

  // null이면 전체 주제를 보여 줘요.
  String? _selectedTopic;

  bool _openingReview = false;

  @override
  void initState() {
    super.initState();
    _records = LearningStorage.loadSessions();
  }

  void _reload() {
    if (!mounted) return;

    setState(() {
      _records = LearningStorage.loadSessions();
    });
  }

  String _topicOf(Map<String, dynamic> record) {
    final topic = record['topic']?.toString().trim() ?? '';

    return topic.isEmpty ? '주제 없음' : topic;
  }

  List<Map<String, dynamic>> _getAnswers(Map<String, dynamic> record) {
    final rawAnswers = record['answers'];

    if (rawAnswers is! List) {
      return [];
    }

    return rawAnswers
        .whereType<Map>()
        .map((answer) => Map<String, dynamic>.from(answer))
        .toList();
  }

  int _unreviewedCount(Map<String, dynamic> record) {
    return _getAnswers(record).where((answer) {
      return answer['isCorrect'] == false && answer['reviewCompleted'] != true;
    }).length;
  }

  int _reviewedCount(Map<String, dynamic> record) {
    return _getAnswers(record).where((answer) {
      return answer['isCorrect'] == false && answer['reviewCompleted'] == true;
    }).length;
  }

  int _toInt(dynamic value) {
    if (value is num) return value.toInt();

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _formatDate(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');

    if (date == null) return '날짜 정보 없음';

    final local = date.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');

    return '${local.year}.$month.$day $hour:$minute';
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openDetail(Map<String, dynamic> record) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => LearningHistoryDetailScreen(record: record),
      ),
    );

    _reload();
  }

  /// 객관식과 주관식(SHORT_ANSWER) 모두 다시 풀기가 가능하도록 PracticeQuestion.fromJson으로 통일
  Future<void> _retryQuestion(
    Map<String, dynamic> record,
    Map<String, dynamic> answer,
    int fallbackQuestionNumber,
  ) async {
    if (_openingReview) return;

    final completedAt = record['completedAt']?.toString();
    final questionNumber = int.tryParse(
      '${answer['questionNumber'] ?? fallbackQuestionNumber}',
    );

    if (completedAt == null || completedAt.isEmpty || questionNumber == null) {
      _showMessage(
        '이 기록에는 다시 풀기에 필요한 정보가 없어요. '
        '새로 학습한 문제부터 이용할 수 있어요.',
      );
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
      _showMessage(
        '이 기록에는 다시 풀기에 필요한 정보가 없어요. '
        '새로 학습한 문제부터 이용할 수 있어요.',
      );
      return;
    }

    setState(() {
      _openingReview = true;
    });

    try {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => ProblemScreen(
            topic: _topicOf(record),
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
    } catch (_) {
      _showMessage('복습 화면을 열거나 저장하지 못했어요. 다시 시도해 주세요.');
    } finally {
      if (mounted) {
        setState(() {
          _openingReview = false;
          _records = LearningStorage.loadSessions();
        });
      }
    }
  }

  Widget _buildFilter(String label, _HistoryView view) {
    return ChoiceChip(
      label: Text(label),
      selected: _view == view,
      onSelected: (_) {
        setState(() {
          _view = view;
        });
      },
      selectedColor: const Color(0xFFE8DFFF),
      labelStyle: TextStyle(
        color: _view == view
            ? const Color(0xFF7652FF)
            : const Color(0xFF555555),
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildTopicFilter(List<String> topics, String? activeTopic) {
    final selectedIndex = activeTopic == null
        ? 0
        : topics.indexOf(activeTopic) + 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F1FF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE8DFFF)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.filter_list_rounded,
              color: Color(0xFF7652FF),
              size: 22,
            ),
            const SizedBox(width: 10),
            const Text(
              '주제',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF7652FF),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: selectedIndex,
                  isExpanded: true,
                  dropdownColor: Colors.white,
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Color(0xFF7652FF),
                  ),
                  items: [
                    const DropdownMenuItem<int>(value: 0, child: Text('전체 주제')),
                    for (var index = 0; index < topics.length; index++)
                      DropdownMenuItem<int>(
                        value: index + 1,
                        child: Text(
                          topics[index],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;

                    setState(() {
                      _selectedTopic = value == 0 ? null : topics[value - 1];
                    });
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> record) {
    final total = _toInt(record['totalCount']);
    final correct = _toInt(record['correctCount']);

    final rate = total > 0 ? (correct / total * 100).round() : 0;

    final unreviewed = _unreviewedCount(record);
    final reviewed = _reviewedCount(record);

    return Material(
      color: const Color(0xFFF5F1FF),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openDetail(record),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _topicOf(record),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF7652FF),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _formatDate(record['completedAt']),
                style: const TextStyle(color: Color(0xFF777777)),
              ),
              const SizedBox(height: 12),
              Text(
                '풀이 결과: $total문제 중 $correct문제 해결'
                ' · 성취율 $rate%',
                style: const TextStyle(
                  color: Color(0xFF7652FF),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              if (unreviewed + reviewed == 0)
                const Text(
                  '복습할 오답 없음',
                  style: TextStyle(
                    color: Color(0xFF278B4B),
                    fontWeight: FontWeight.bold,
                  ),
                )
              else ...[
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    Text(
                      '미복습 $unreviewed개',
                      style: const TextStyle(
                        color: Color(0xFFC94B4B),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '복습 완료 $reviewed개',
                      style: const TextStyle(
                        color: Color(0xFF278B4B),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (unreviewed == 0) ...[
                  const SizedBox(height: 8),
                  const Text(
                    '모든 오답 복습 완료!',
                    style: TextStyle(
                      color: Color(0xFF278B4B),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 12),
              const Text(
                '눌러서 단계별 오류 분석 기록과 해설 보기',
                style: TextStyle(fontSize: 13, color: Color(0xFF777777)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWrongAnswerCard(Map<String, dynamic> entry) {
    final record = entry['record'] as Map<String, dynamic>;
    final answer = entry['answer'] as Map<String, dynamic>;
    final originalIndex = entry['originalIndex'] as int;

    final completed = answer['reviewCompleted'] == true;
    final questionNumber = answer['questionNumber'] ?? originalIndex + 1;
    final misconceptionCode = answer['misconceptionCode']?.toString();
    final firstErrorStep = answer['firstErrorStep'];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F1FF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_topicOf(record)} · 문제 $questionNumber',
                  style: const TextStyle(
                    color: Color(0xFF7652FF),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                completed ? '복습 완료 ✓' : '미복습',
                style: TextStyle(
                  color: completed
                      ? const Color(0xFF278B4B)
                      : const Color(0xFFC94B4B),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _formatDate(record['completedAt']),
            style: const TextStyle(fontSize: 12, color: Color(0xFF777777)),
          ),
          if (misconceptionCode != null || firstErrorStep != null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (firstErrorStep != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF5F5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '최초 오류: Step $firstErrorStep',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE53E3E),
                      ),
                    ),
                  ),
                if (misconceptionCode != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      misconceptionCode,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF7652FF),
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Text(
            answer['title']?.toString() ?? '문제',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            answer['question']?.toString() ?? '',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16, height: 1.5),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _openingReview
                  ? null
                  : () => _retryQuestion(record, answer, originalIndex + 1),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7652FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(completed ? '변형 문제로 한 번 더 풀기' : 'AI 튜터와 오답 다시 풀기'),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => _openDetail(record),
              child: const Text('이 학습의 기록·해설 보기'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView(String? activeTopic) {
    final String message;

    switch (_view) {
      case _HistoryView.history:
        message = '선택한 주제의 학습 기록이 없어요.';
        break;

      case _HistoryView.unreviewed:
        message = activeTopic == null
            ? '미복습 오답이 없어요!\n'
                  '완료한 문제는 ‘복습 완료’에서 볼 수 있어요.'
            : '이 주제에는 미복습 오답이 없어요!\n'
                  '다른 주제나 ‘복습 완료’를 확인해 보세요.';
        break;

      case _HistoryView.reviewed:
        message = activeTopic == null
            ? '아직 복습을 완료한 오답이 없어요.'
            : '이 주제에는 복습을 완료한 오답이 없어요.';
        break;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(height: 1.8),
            ),
            if (activeTopic != null) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedTopic = null;
                  });
                },
                child: const Text('전체 주제로 보기'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    List<Map<String, dynamic>> records,
    String? activeTopic,
  ) {
    if (_view == _HistoryView.history) {
      if (records.isEmpty) {
        return _buildEmptyView(activeTopic);
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Text(
              '학습 기록 ${records.length}개',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF7652FF),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: records.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) =>
                  _buildHistoryCard(records[index]),
            ),
          ),
        ],
      );
    }

    final entries = <Map<String, dynamic>>[];

    for (final record in records) {
      final answers = _getAnswers(record);

      for (var index = 0; index < answers.length; index++) {
        final answer = answers[index];

        if (answer['isCorrect'] != false) continue;

        final completed = answer['reviewCompleted'] == true;

        final shouldShow = _view == _HistoryView.unreviewed
            ? !completed
            : completed;

        if (!shouldShow) continue;

        entries.add({
          'record': record,
          'answer': answer,
          'originalIndex': index,
        });
      }
    }

    if (entries.isEmpty) {
      return _buildEmptyView(activeTopic);
    }

    final label = _view == _HistoryView.unreviewed ? '미복습 오답' : '복습 완료';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Text(
            '$label ${entries.length}개',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF7652FF),
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: entries.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) =>
                _buildWrongAnswerCard(entries[index]),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('학습 기록 · 오답노트'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF171717),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildFilter('학습 기록', _HistoryView.history),
                  _buildFilter('미복습 오답', _HistoryView.unreviewed),
                  _buildFilter('복습 완료', _HistoryView.reviewed),
                ],
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _records,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('학습 기록을 불러오지 못했어요.'),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _reload,
                          child: const Text('다시 시도'),
                        ),
                      ],
                    ),
                  );
                }

                final records = (snapshot.data ?? []).reversed.toList();

                if (records.isEmpty) {
                  return const Center(
                    child: Text(
                      '아직 저장된 학습 기록이 없어요.\n'
                      '문제를 끝까지 풀어 보세요!',
                      textAlign: TextAlign.center,
                      style: TextStyle(height: 1.8),
                    ),
                  );
                }

                final topics = records.map(_topicOf).toSet().toList()..sort();

                final activeTopic = topics.contains(_selectedTopic)
                    ? _selectedTopic
                    : null;

                final filteredRecords = activeTopic == null
                    ? records
                    : records.where((record) {
                        return _topicOf(record) == activeTopic;
                      }).toList();

                return Column(
                  children: [
                    _buildTopicFilter(topics, activeTopic),
                    const Divider(height: 1),
                    Expanded(
                      child: _buildContent(filteredRecords, activeTopic),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
