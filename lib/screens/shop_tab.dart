// 피그마 시안(image_fc8dde.png 4번째 화면 '마이페이지': 내 수학 실력 알아보기 + 나의 학습 기록 10월 잔디 캘린더 + 내 배지 도감 6종)
// + 기존 보상 상점(골드 교환) 전환 통합 탭
import 'package:flutter/material.dart';

import '../services/learning_storage.dart';
import '../services/reward_storage.dart';

class ShopTab extends StatefulWidget {
  const ShopTab({super.key});

  @override
  State<ShopTab> createState() => _ShopTabState();
}

class _ShopTabState extends State<ShopTab> {
  static const _purple = Color(0xFF7C5CFA);
  static const _lightPurple = Color(0xFFF3EEFF);
  static const _textColor = Color(0xFF171717);
  static const _mutedColor = Color(0xFF888888);

  // false: 마이페이지 (피그마 4-4 기본), true: 골드 보상 상점
  bool _showGoldShop = false;

  int _streak = 3;
  int _sessionCount = 0;
  bool _exchanging = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      await RewardStorage.getGold();
      final sessions = await LearningStorage.loadSessions();
      if (!mounted) return;
      setState(() {
        _sessionCount = sessions.length;
        if (sessions.isNotEmpty) {
          _streak = 3;
        }
      });
    } catch (_) {}
  }

  Future<void> _exchangeItem(String itemId) async {
    if (_exchanging) return;
    setState(() => _exchanging = true);
    try {
      final remaining = await RewardStorage.exchangeItem(itemId);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('교환 완료! 남은 골드: $remaining G')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is StateError ? e.message.toString() : '골드가 부족합니다.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _exchanging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF9F9FB),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
            children: [
              Row(
                children: [
                  Text(
                    _showGoldShop ? '보상 상점' : '마이페이지',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: _textColor,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {
                      setState(() => _showGoldShop = !_showGoldShop);
                    },
                    icon: Icon(
                      _showGoldShop
                          ? Icons.person_outline_rounded
                          : Icons.storefront_rounded,
                      size: 18,
                      color: _purple,
                    ),
                    label: Text(
                      _showGoldShop ? '마이페이지로 돌아가기' : '골드 상점 열기',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: _purple,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (_showGoldShop)
                _buildGoldShopSection()
              else ...[
                // 1. 피그마 4-4 상단: 내 수학 실력 알아보기 카드
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 22,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFEEEEEE)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '내 수학 실력 알아보기',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: _textColor,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '빵꾸난 개념을 채울 수 있어요',
                        style: TextStyle(fontSize: 13.5, color: _textColor),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 2. 피그마 4-4 중단: 나의 학습 기록 (10월) + 🔥 3일 연속 잔디 캘린더
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFEEEEEE)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            '나의 학습 기록 (10월)',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: _textColor,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '🔥 $_streak일 연속',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: _purple,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Text(
                            '일',
                            style: TextStyle(fontSize: 11, color: _mutedColor),
                          ),
                          Text(
                            '월',
                            style: TextStyle(fontSize: 11, color: _mutedColor),
                          ),
                          Text(
                            '화',
                            style: TextStyle(fontSize: 11, color: _mutedColor),
                          ),
                          Text(
                            '수',
                            style: TextStyle(fontSize: 11, color: _mutedColor),
                          ),
                          Text(
                            '목',
                            style: TextStyle(fontSize: 11, color: _mutedColor),
                          ),
                          Text(
                            '금',
                            style: TextStyle(fontSize: 11, color: _mutedColor),
                          ),
                          Text(
                            '토',
                            style: TextStyle(fontSize: 11, color: _mutedColor),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      GridView.count(
                        crossAxisCount: 7,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        children: List.generate(14, (idx) {
                          const levels = [
                            0,
                            0,
                            0,
                            1,
                            3,
                            2,
                            0,
                            0,
                            2,
                            3,
                            2,
                            0,
                            0,
                            0,
                          ];
                          final lv = levels[idx];
                          final Color tileColor;
                          if (lv == 3) {
                            tileColor = const Color(0xFF7C5CFA);
                          } else if (lv == 2) {
                            tileColor = const Color(0xFFB794F4);
                          } else if (lv == 1) {
                            tileColor = const Color(0xFFD6BCFA);
                          } else {
                            tileColor = const Color(0xFFF2F2F5);
                          }
                          return Container(
                            decoration: BoxDecoration(
                              color: tileColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 3. 피그마 4-4 하단: 내 배지 도감 🏅 (3x2 그리드)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFEEEEEE)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            '내 배지 도감 🏅',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: _textColor,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '누적 풀이 ${_sessionCount + 3}회',
                            style: const TextStyle(
                              fontSize: 11,
                              color: _mutedColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      GridView.count(
                        crossAxisCount: 3,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.85,
                        children: const [
                          _BadgeGridItem(
                            emoji: '🎯',
                            title: '포기하지 않는\n도전자',
                            unlocked: true,
                          ),
                          _BadgeGridItem(
                            emoji: '➕',
                            title: '부호 마스터',
                            unlocked: true,
                          ),
                          _BadgeGridItem(
                            emoji: '🔥',
                            title: '3일의 기적',
                            unlocked: true,
                          ),
                          _BadgeGridItem(
                            emoji: '👑',
                            title: '수학의 신',
                            unlocked: false,
                          ),
                          _BadgeGridItem(
                            emoji: '⚡',
                            title: '스피드 풀이',
                            unlocked: false,
                          ),
                          _BadgeGridItem(
                            emoji: '❓',
                            title: '???',
                            unlocked: false,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGoldShopSection() {
    return ValueListenableBuilder<int?>(
      valueListenable: RewardStorage.goldNotifier,
      builder: (context, gold, child) {
        final currentGold = gold ?? 0;
        final items = RewardStorage.shopPrices.keys.toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _lightPurple,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.monetization_on_rounded,
                    color: Color(0xFFE5A000),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '보유 골드: $currentGold G',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ...items.map((id) {
              final name = RewardStorage.shopNames[id]!;
              final price = RewardStorage.shopPrices[id]!;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('$price G (테스트 교환)'),
                  trailing: ElevatedButton(
                    onPressed: currentGold >= price && !_exchanging
                        ? () => _exchangeItem(id)
                        : null,
                    child: const Text('교환'),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

class _BadgeGridItem extends StatelessWidget {
  final String emoji;
  final String title;
  final bool unlocked;

  const _BadgeGridItem({
    required this.emoji,
    required this.title,
    required this.unlocked,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: unlocked ? const Color(0xFFF3EEFF) : const Color(0xFFF2F2F5),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Opacity(
              opacity: unlocked ? 1.0 : 0.35,
              child: Text(emoji, style: const TextStyle(fontSize: 26)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: unlocked ? const Color(0xFF171717) : const Color(0xFFAAAAAA),
            height: 1.25,
          ),
        ),
      ],
    );
  }
}
