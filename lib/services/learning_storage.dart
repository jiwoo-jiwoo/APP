import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

class ExperienceProgress {
  final int totalXp;

  const ExperienceProgress(this.totalXp);

  static const xpPerLevel = 100;

  int get level => totalXp ~/ xpPerLevel + 1;

  int get currentLevelXp => totalXp % xpPerLevel;

  int get remainingXp => xpPerLevel - currentLevelXp;

  double get progress => currentLevelXp / xpPerLevel;
}

class LearningStorage {
  static const String _storageKey = 'learning_sessions';

  // 스킬트리 예제의 최초 완료 경험치를 저장합니다.
  static const String _skillStorageKey = 'skill_experience_v1';

  static const int baseXpPerQuestion = 5;
  static const int correctXpPerQuestion = 5;
  static const int reviewXpPerQuestion = 5;

  static final Random _random = Random.secure();

  // 동일 실행 환경에서 저장 작업을 순서대로 처리합니다.
  static Future<void> _pending = Future<void>.value();

  static Future<T> _run<T>(Future<T> Function() action) {
    final result = _pending.then((_) => action());

    _pending = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );

    return result;
  }

  static String createSessionId() {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final random = List.generate(
      16,
      (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();

    return '$timestamp-$random';
  }

  static int _readXp(dynamic value) {
    if (value is int && value >= 0) return value;
    return 0;
  }

  static Future<List<Map<String, dynamic>>> _readSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_storageKey);

    if (saved == null || saved.isEmpty) {
      return [];
    }

    final decoded = jsonDecode(saved);

    if (decoded is! List) {
      throw const FormatException('학습 기록 형식이 올바르지 않습니다.');
    }

    return decoded.map<Map<String, dynamic>>((item) {
      if (item is! Map) {
        throw const FormatException('학습 기록 항목이 올바르지 않습니다.');
      }

      return Map<String, dynamic>.from(item);
    }).toList();
  }

  static Future<void> _writeSessions(List<Map<String, dynamic>> records) async {
    final prefs = await SharedPreferences.getInstance();

    final success = await prefs.setString(_storageKey, jsonEncode(records));

    if (!success) {
      throw StateError('학습 기록을 저장하지 못했습니다.');
    }
  }

  static Future<Map<String, dynamic>> _readSkills() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_skillStorageKey);

    if (saved == null || saved.isEmpty) {
      return {};
    }

    final decoded = jsonDecode(saved);

    if (decoded is! Map) {
      throw const FormatException('스킬 경험치 형식이 올바르지 않습니다.');
    }

    return Map<String, dynamic>.from(decoded);
  }

  // 저장된 학습 기록 불러오기
  static Future<List<Map<String, dynamic>>> loadSessions() {
    return _run(_readSessions);
  }

  // 같은 sessionId는 한 번만 저장합니다.
  // 반환값은 해당 학습 기록에 저장된 경험치입니다.
  static Future<int> saveSession({
    required List<Map<String, dynamic>> answers,
    required int correctCount,
    String topic = '다항식의 연산',
    String? sessionId,
  }) {
    // 비동기 작업 전에 답변의 복사본을 만듭니다.
    final copiedAnswers = (jsonDecode(jsonEncode(answers)) as List)
        .map((answer) => Map<String, dynamic>.from(answer as Map))
        .toList();

    final id = sessionId ?? createSessionId();

    return _run(() async {
      final records = await _readSessions();

      for (final record in records) {
        if (record['sessionId'] == id) {
          return _readXp(record['earnedXp']);
        }
      }

      if (copiedAnswers.isEmpty) {
        throw ArgumentError('답변이 없는 학습은 저장할 수 없습니다.');
      }

      if (copiedAnswers.any((answer) => answer['isCorrect'] is! bool)) {
        throw ArgumentError('답변의 정답 여부가 올바르지 않습니다.');
      }

      final actualCorrectCount = copiedAnswers
          .where((answer) => answer['isCorrect'] == true)
          .length;

      if (correctCount != actualCorrectCount) {
        throw ArgumentError('정답 수와 답변 기록이 일치하지 않습니다.');
      }

      // 새 학습의 답변에 복습 보상이 미리 들어가지 않게 합니다.
      for (final answer in copiedAnswers) {
        answer.remove('reviewCompleted');
        answer.remove('reviewCompletedAt');
        answer.remove('reviewEarnedXp');
      }

      final baseXp = copiedAnswers.length * baseXpPerQuestion;
      final correctXp = actualCorrectCount * correctXpPerQuestion;
      final earnedXp = baseXp + correctXp;

      records.add({
        'sessionId': id,
        'topic': topic,
        'totalCount': copiedAnswers.length,
        'correctCount': actualCorrectCount,
        'completedAt': DateTime.now().toUtc().toIso8601String(),
        'baseXp': baseXp,
        'correctXp': correctXp,
        'earnedXp': earnedXp,
        'answers': copiedAnswers,
      });

      await _writeSessions(records);

      return earnedXp;
    });
  }

  // 기존 오답의 복습 완료 상태와 경험치를 함께 저장합니다.
  static Future<void> markReviewCompleted({
    required String completedAt,
    required int questionNumber,
  }) {
    return _run(() async {
      final records = await _readSessions();

      for (final record in records) {
        if (record['completedAt']?.toString() != completedAt) {
          continue;
        }

        final rawAnswers = record['answers'];

        if (rawAnswers is! List) continue;

        for (var index = 0; index < rawAnswers.length; index++) {
          final rawAnswer = rawAnswers[index];

          if (rawAnswer is! Map) continue;

          final answer = Map<String, dynamic>.from(rawAnswer);
          final savedNumber = int.tryParse(
            '${answer['questionNumber'] ?? index + 1}',
          );

          if (savedNumber != questionNumber || answer['isCorrect'] != false) {
            continue;
          }

          // 이미 완료했으면 날짜와 경험치를 변경하지 않습니다.
          if (answer['reviewCompleted'] == true) {
            return;
          }

          answer['reviewCompleted'] = true;
          answer['reviewCompletedAt'] = DateTime.now()
              .toUtc()
              .toIso8601String();
          answer['reviewEarnedXp'] = reviewXpPerQuestion;

          rawAnswers[index] = answer;

          await _writeSessions(records);
          return;
        }
      }

      throw StateError('복습한 문제의 학습 기록을 찾지 못했습니다.');
    });
  }

  static Future<bool> hasSkillCompleted(String skillId) {
    return _run(() async {
      final skills = await _readSkills();
      return skills.containsKey(skillId);
    });
  }

  // 현재 스킬트리 예제에서만 사용합니다.
  // 보상량은 호출자가 임의로 지정하지 못하게 고정합니다.
  static Future<int> completeSkill(String skillId) {
    return _run(() async {
      if (skillId != 'quadratic_minimum_v1') {
        throw ArgumentError('등록되지 않은 스킬입니다.');
      }

      final skills = await _readSkills();

      if (skills.containsKey(skillId)) {
        return 0;
      }

      const earnedXp = 10;

      skills[skillId] = {
        'earnedXp': earnedXp,
        'completedAt': DateTime.now().toUtc().toIso8601String(),
      };

      final prefs = await SharedPreferences.getInstance();
      final success = await prefs.setString(
        _skillStorageKey,
        jsonEncode(skills),
      );

      if (!success) {
        throw StateError('스킬 완료 상태를 저장하지 못했습니다.');
      }

      return earnedXp;
    });
  }

  static Future<ExperienceProgress> getExperienceProgress() {
    return _run(() async {
      final records = await _readSessions();
      final skills = await _readSkills();

      var totalXp = 0;

      for (final record in records) {
        totalXp += _readXp(record['earnedXp']);

        final answers = record['answers'];
        if (answers is! List) continue;

        for (final answer in answers) {
          if (answer is Map &&
              answer['isCorrect'] == false &&
              answer['reviewCompleted'] == true) {
            totalXp += _readXp(answer['reviewEarnedXp']);
          }
        }
      }

      for (final skill in skills.values) {
        if (skill is Map) {
          totalXp += _readXp(skill['earnedXp']);
        }
      }

      return ExperienceProgress(totalXp);
    });
  }
}
