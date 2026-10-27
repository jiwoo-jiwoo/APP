import 'package:flutter/material.dart';

import '../services/learning_storage.dart';
import '../services/reward_storage.dart';

class QuestScreen extends StatefulWidget {
  const QuestScreen({super.key});

  @override
  State<QuestScreen> createState() => _QuestScreenState();
}

class _QuestData {
  final int learningCount;
  final int reviewCount;
  final Set<String> claimedQuestIds;

  const _QuestData({
    required this.learningCount,
    required this.reviewCount,
    required this.claimedQuestIds,
  });
}

class _QuestScreenState extends State<QuestScreen> {
  late Future<_QuestData> _progressFuture;

  String? _claimingQuestId;

  @override
  void initState() {
    super.initState();

    _progressFuture = _loadProgress();
  }

  bool _isToday(dynamic value, DateTime today) {
    if (value == null) return false;

    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return false;

    final local = parsed.toLocal();

    return local.year == today.year &&
        local.month == today.month &&
        local.day == today.day;
  }

  Future<_QuestData> _loadProgress() async {
    final sessions = await LearningStorage.loadSessions();
    final claimed = await RewardStorage.getTodayClaimedQuestIds();

    final today = DateTime.now();

    var learningCount = 0;
    var reviewCount = 0;

    for (final session in sessions) {
      final answers = session['answers'];

      if (answers is List &&
          answers.isNotEmpty &&
          _isToday(session['completedAt'], today)) {
        learningCount++;
      }

      if (answers is! List) continue;

      for (final answer in answers) {
        if (answer is! Map) continue;

        if (answer['isCorrect'] == false &&
            answer['reviewCompleted'] == true &&
            _isToday(answer['reviewCompletedAt'], today)) {
          reviewCount++;
        }
      }
    }

    return _QuestData(
      learningCount: learningCount,
      reviewCount: reviewCount,
      claimedQuestIds: claimed,
    );
  }

  Future<void> _refresh() async {
    if (!mounted) return;

    final future = _loadProgress();

    setState(() {
      _progressFuture = future;
    });

    // 로드 오류는 FutureBuilder에서 안내합니다.
    try {
      await future;
    } catch (_) {}
  }

  Future<void> _claimReward(String questId) async {
    // 다른 보상을 처리하는 동안 추가 요청을 막습니다.
    if (_claimingQuestId != null) return;

    setState(() {
      _claimingQuestId = questId;
    });

    try {
      final earnedGold = await RewardStorage.claimQuestReward(questId);

      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              earnedGold > 0 ? '$earnedGold G를 받았어요!' : '오늘 이미 받은 보상입니다.',
            ),
          ),
        );

      await _refresh();
    } catch (error) {
      if (!mounted) return;

      final message = error is StateError
          ? error.message.toString()
          : '보상을 받지 못했습니다. 다시 시도해 주세요.';

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() {
          _claimingQuestId = null;
        });
      }
    }
  }

  Widget _questCard({
    required String questId,
    required String title,
    required String description,
    required int count,
    required IconData icon,
    required bool claimed,
  }) {
    final completed = count >= 1;
    final claiming = _claimingQuestId == questId;
    final reward = RewardStorage.rewardFor(questId);

    final canClaim = completed && !claimed && _claimingQuestId == null;

    String buttonLabel;

    if (claimed) {
      buttonLabel = '수령 완료';
    } else if (claiming) {
      buttonLabel = '저장 중…';
    } else if (completed) {
      buttonLabel = '$reward G 받기';
    } else {
      buttonLabel = '완료 후 $reward G 받기';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: completed ? Colors.green : Colors.indigo),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (completed)
                  const Icon(Icons.check_circle, color: Colors.green),
              ],
            ),
            const SizedBox(height: 12),
            Text(description),
            const SizedBox(height: 16),
            LinearProgressIndicator(value: completed ? 1.0 : 0.0, minHeight: 8),
            const SizedBox(height: 8),
            Text(
              completed ? '목표 달성 · 1 / 1' : '진행 중 · 0 / 1',
              style: TextStyle(
                color: completed ? Colors.green : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: canClaim ? () => _claimReward(questId) : null,
                child: Text(buttonLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('오늘의 퀘스트'),
        actions: [
          IconButton(
            tooltip: '새로고침',
            onPressed: _claimingQuestId == null ? _refresh : null,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<_QuestData>(
        future: _progressFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('퀘스트 진행도를 불러오지 못했습니다.'),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _refresh,
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            );
          }

          final progress = snapshot.data!;

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  '매일 작은 목표를 달성해 보세요!',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  '기기의 현지 날짜 기준으로\n'
                  '각 보상을 하루에 한 번 받을 수 있어요.',
                ),
                const SizedBox(height: 24),
                _questCard(
                  questId: RewardStorage.learningQuest,
                  title: '오늘 학습 1회',
                  description: '문제 풀이를 끝내고 학습 기록을 저장하세요.',
                  count: progress.learningCount,
                  icon: Icons.menu_book,
                  claimed: progress.claimedQuestIds.contains(
                    RewardStorage.learningQuest,
                  ),
                ),
                _questCard(
                  questId: RewardStorage.reviewQuest,
                  title: '오늘 오답 복습 1회',
                  description: '오답 1문제를 다시 풀어 복습을 완료하세요.',
                  count: progress.reviewCount,
                  icon: Icons.edit_note,
                  claimed: progress.claimedQuestIds.contains(
                    RewardStorage.reviewQuest,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
