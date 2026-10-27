import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'learning_storage.dart';

class RewardStorage {
  static const String _storageKey = 'quest_rewards_v1';

  static const int initialGold = 0;
  static const int learningReward = 100;
  static const int reviewReward = 50;

  static const String learningQuest = 'daily_learning';
  static const String reviewQuest = 'daily_review';

  // null이면 아직 골드를 읽지 않은 상태입니다.
  static final ValueNotifier<int?> goldNotifier = ValueNotifier<int?>(null);

  static Future<void> _pending = Future<void>.value();

  static Future<T> _run<T>(Future<T> Function() action) {
    final result = _pending.then((_) => action());

    _pending = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );

    return result;
  }

  static String _dateKey(DateTime date) {
    final local = date.toLocal();

    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  static bool _isToday(dynamic value, DateTime today) {
    if (value == null) return false;

    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return false;

    return _dateKey(parsed) == _dateKey(today);
  }

  static int rewardFor(String questId) {
    switch (questId) {
      case learningQuest:
        return learningReward;
      case reviewQuest:
        return reviewReward;
      default:
        throw ArgumentError('등록되지 않은 퀘스트입니다.');
    }
  }

  static Future<Map<String, dynamic>> _readState() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_storageKey);

    if (saved == null) {
      return {'gold': initialGold, 'claims': <String, dynamic>{}};
    }

    final decoded = jsonDecode(saved);

    if (decoded is! Map) {
      throw const FormatException('골드 저장 형식이 올바르지 않습니다.');
    }

    final gold = decoded['gold'];
    final claims = decoded['claims'];

    if (gold is! int ||
        gold < 0 ||
        claims is! Map ||
        claims.keys.any((key) => key is! String) ||
        claims.values.any((value) => value != true)) {
      throw const FormatException('골드 저장 데이터가 올바르지 않습니다.');
    }
    final purchases = decoded['purchases'] ?? <dynamic>[];

    if (purchases is! List || purchases.any((item) => item is! Map)) {
      throw const FormatException('교환 기록 형식이 올바르지 않습니다.');
    }

    return {
      'gold': gold,
      'claims': Map<String, dynamic>.from(claims),
      'purchases': purchases
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList(),
    };
  }

  static Future<void> _writeState(Map<String, dynamic> state) async {
    final prefs = await SharedPreferences.getInstance();

    final success = await prefs.setString(_storageKey, jsonEncode(state));

    if (!success) {
      throw StateError('골드를 저장하지 못했습니다.');
    }
  }

  static Future<int> getGold() {
    return _run(() async {
      final state = await _readState();
      final gold = state['gold'] as int;

      goldNotifier.value = gold;

      return gold;
    });
  }

  static Future<Set<String>> getTodayClaimedQuestIds() {
    return _run(() async {
      final state = await _readState();
      final claims = state['claims'] as Map<String, dynamic>;
      final date = _dateKey(DateTime.now());

      return <String>{
        if (claims['$date:$learningQuest'] == true) learningQuest,
        if (claims['$date:$reviewQuest'] == true) reviewQuest,
      };
    });
  }

  static bool _isQuestCompleted(
    String questId,
    List<Map<String, dynamic>> sessions,
    DateTime today,
  ) {
    for (final session in sessions) {
      final answers = session['answers'];

      if (answers is! List) continue;

      if (questId == learningQuest &&
          answers.isNotEmpty &&
          _isToday(session['completedAt'], today)) {
        return true;
      }

      if (questId == reviewQuest) {
        for (final answer in answers) {
          if (answer is Map &&
              answer['isCorrect'] == false &&
              answer['reviewCompleted'] == true &&
              _isToday(answer['reviewCompletedAt'], today)) {
            return true;
          }
        }
      }
    }

    return false;
  }

  // 반환값:
  // 지급 성공 -> 지급한 골드
  // 이미 수령 -> 0
  static Future<int> claimQuestReward(String questId) {
    final reward = rewardFor(questId);

    return _run(() async {
      // 버튼 상태만 믿지 않고 실제 학습 기록을 확인합니다.
      final sessions = await LearningStorage.loadSessions();
      final state = await _readState();

      final today = DateTime.now();
      final claimKey = '${_dateKey(today)}:$questId';
      final claims = state['claims'] as Map<String, dynamic>;

      if (claims[claimKey] == true) {
        goldNotifier.value = state['gold'] as int;
        return 0;
      }

      if (!_isQuestCompleted(questId, sessions, today)) {
        throw StateError('오늘의 퀘스트를 먼저 완료해 주세요.');
      }

      final newGold = (state['gold'] as int) + reward;

      state['gold'] = newGold;
      claims[claimKey] = true;

      // 골드와 수령 여부를 함께 저장합니다.
      await _writeState(state);

      // 저장에 성공한 뒤 화면에 반영합니다.
      goldNotifier.value = newGold;

      return reward;
    });
  }

  // 가격은 저장소에서 관리합니다.
  // 화면에서 임의의 가격을 전달하지 않습니다.
  static const Map<String, int> shopPrices = {
    'banana_milk': 1000,
    'cup_noodle': 1200,
    'gift_card': 5000,
  };

  static const Map<String, String> shopNames = {
    'banana_milk': '바나나맛 우유',
    'cup_noodle': '육개장 사발면',
    'gift_card': '문화상품권 5천원',
  };

  static Future<int> exchangeItem(String itemId) {
    return _run(() async {
      final price = shopPrices[itemId];
      final name = shopNames[itemId];

      if (price == null || name == null) {
        throw ArgumentError('등록되지 않은 상품입니다.');
      }

      final state = await _readState();
      final currentGold = state['gold'] as int;

      if (currentGold < price) {
        throw StateError('골드가 부족합니다.');
      }

      final purchases = List<Map<String, dynamic>>.from(
        state['purchases'] ?? <Map<String, dynamic>>[],
      );

      final remainingGold = currentGold - price;

      purchases.add({
        'itemId': itemId,
        'name': name,
        'price': price,
        'exchangedAt': DateTime.now().toUtc().toIso8601String(),
        'type': 'local_test',
      });

      state['gold'] = remainingGold;
      state['purchases'] = purchases;

      // 잔액과 교환 기록을 함께 저장합니다.
      await _writeState(state);

      // 저장 성공 후에만 화면에 반영합니다.
      goldNotifier.value = remainingGold;

      return remainingGold;
    });
  }

  static Future<List<Map<String, dynamic>>> loadPurchaseHistory() {
    return _run(() async {
      final state = await _readState();

      final purchases = List<Map<String, dynamic>>.from(
        state['purchases'] ?? <Map<String, dynamic>>[],
      );

      // 최근 교환부터 표시합니다.
      return purchases.reversed.toList();
    });
  }
}
