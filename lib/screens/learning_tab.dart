// 피그마 시안(image_fc8dde.png 좌측 1·2번째 화면: 학습하기 - 단원/개념 & 기출문제 탭)
// + LearningStorage 실제 풀이 기록 기반 단원별 진행률 동적 연동 + 기출문제 연도/월/주관 필터 실제 동작 보완본
import 'package:flutter/material.dart';

import '../services/learning_storage.dart';
import '../services/question_service.dart';
import 'learning_history_screen.dart';
import 'problem_screen.dart';
import 'skill_tree_tab.dart';

class LearningTab extends StatefulWidget {
  final VoidCallback onExperienceChanged;

  const LearningTab({super.key, required this.onExperienceChanged});

  @override
  State<LearningTab> createState() => _LearningTabState();
}

class _LearningTabState extends State<LearningTab> {
  static const _purple = Color(0xFF7C5CFA);
  static const _lightPurple = Color(0xFFF5F1FF);
  static const _textColor = Color(0xFF171717);
  static const _mutedColor = Color(0xFF888888);

  // 0: 단원/개념 탭, 1: 기출문제 탭 (피그마 시안 4-1, 4-2)
  int _subTabIndex = 0;

  // false: 기본 학습 목록, true: 역추적 스킬트리 뷰
  bool _showSkillTree = false;

  String _selectedGrade = '고등학교 1학년';
  String _selectedSemester = '1학기';
  String _searchQuery = '';

  // 기출문제 필터
  String _examYear = '시행 연도';
  String _examMonth = '시행 월';
  String _examOrg = '주관';

  // 아코디언 열림 상태 (0: 1. 다항식 기본 열림)
  final Set<int> _expandedUnits = {0};

  // 단원별 실제 풀이 완료 문항 수 (LearningStorage 연동)
  final Map<String, int> _solvedCountByTopic = {};

  @override
  void initState() {
    super.initState();
    _loadProgressFromStorage();
  }

  Future<void> _loadProgressFromStorage() async {
    try {
      final sessions = await LearningStorage.loadSessions();
      final counts = <String, int>{};

      for (final s in sessions) {
        final topic = s['topic']?.toString() ?? '다항식';
        final answers = s['answers'];
        final count = answers is List ? answers.length : 1;
        counts[topic] = (counts[topic] ?? 0) + count;
      }

      if (!mounted) return;
      setState(() {
        _solvedCountByTopic
          ..clear()
          ..addAll(counts);
      });
    } catch (_) {}
  }

  Future<void> _openProblemScreen({String unit = '다항식'}) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => ProblemScreen(
          topic: unit,
          questionService: MockQuestionService(unit: unit),
          startWithCamera: false,
        ),
      ),
    );

    if (!mounted) return;
    await _loadProgressFromStorage();
    widget.onExperienceChanged();
  }

  /// 기본 시연 진행률 + 내가 실제로 더 푼 문항 수를 합산하여 실시간 진행률 계산
  (double, String) _calcProgress(String unitKey, double baseProgress) {
    final solved = _solvedCountByTopic[unitKey] ?? 0;
    final dynamicProgress = (baseProgress + (solved * 0.25)).clamp(0.0, 1.0);
    final percent = (dynamicProgress * 100).round();
    if (percent == 0) {
      return (0.0, '시작 전');
    } else if (percent >= 100) {
      return (1.0, '100% 완료 🎉');
    }
    return (dynamicProgress, '$percent% 완료 (누적 $solved문항 풀이)');
  }

  @override
  Widget build(BuildContext context) {
    if (_showSkillTree) {
      return ColoredBox(
        color: Colors.white,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: () => setState(() => _showSkillTree = false),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('단원/개념 목록으로'),
                  ),
                  const Spacer(),
                  const Text(
                    '역추적 스킬맵 · 리포트',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SkillTreeTab(
                onExperienceChanged: widget.onExperienceChanged,
              ),
            ),
          ],
        ),
      );
    }

    return ColoredBox(
      color: Colors.white,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 상단 학년/학기 드롭다운 칩 + 우측 역추적 스킬맵/기록 버튼
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                child: Row(
                  children: [
                    _buildDropdownPill(
                      label: _selectedGrade,
                      items: const [
                        '고등학교 1학년',
                        '중학교 3학년',
                        '중학교 2학년',
                        '중학교 1학년',
                      ],
                      onChanged: (v) => setState(() => _selectedGrade = v),
                    ),
                    const SizedBox(width: 8),
                    _buildDropdownPill(
                      label: _selectedSemester,
                      items: const ['1학기', '2학기'],
                      onChanged: (v) => setState(() => _selectedSemester = v),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: '역추적 스킬맵 보기',
                      onPressed: () => setState(() => _showSkillTree = true),
                      icon: const Icon(
                        Icons.account_tree_outlined,
                        color: _purple,
                      ),
                    ),
                    IconButton(
                      tooltip: '학습 기록 · 오답노트',
                      onPressed: () async {
                        await Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (context) => const LearningHistoryScreen(),
                          ),
                        );
                        if (!mounted) return;
                        await _loadProgressFromStorage();
                        widget.onExperienceChanged();
                      },
                      icon: const Icon(
                        Icons.history_rounded,
                        color: _textColor,
                      ),
                    ),
                  ],
                ),
              ),

              // 피그마 4-1 & 4-2: [단원/개념] | [기출문제] 언더라인 탭바
              Row(
                children: [
                  Expanded(
                    child: _buildUnderlineTab(
                      title: '단원/개념',
                      active: _subTabIndex == 0,
                      onTap: () => setState(() => _subTabIndex = 0),
                    ),
                  ),
                  Expanded(
                    child: _buildUnderlineTab(
                      title: '기출문제',
                      active: _subTabIndex == 1,
                      onTap: () => setState(() => _subTabIndex = 1),
                    ),
                  ),
                ],
              ),
              const Divider(height: 1, color: Color(0xFFEEEEEE)),

              Expanded(
                child: _subTabIndex == 0
                    ? _buildUnitConceptTab()
                    : _buildPastExamsTab(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownPill({
    required String label,
    required List<String> items,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: label,
          isDense: true,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: _textColor,
          ),
          icon: const Icon(Icons.arrow_drop_down_rounded, size: 18),
          items: items
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }

  Widget _buildUnderlineTab({
    required String title,
    required bool active,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? _textColor : Colors.transparent,
              width: 2.2,
            ),
          ),
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: active ? FontWeight.w900 : FontWeight.w500,
            color: active ? _textColor : _mutedColor,
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // 피그마 4-1: [단원/개념] 탭 (개념 검색창 + 공통수학1 아코디언 + 실시간 진행률 바)
  // =========================================================================
  Widget _buildUnitConceptTab() {
    final units = [
      (
        title: '1. 다항식',
        subItems: [
          (label: '[개념] 다항식의 연산 · 곱셈 공식', unitKey: '다항식', baseProgress: 0.50),
          (label: '[유형] 나머지정리와 인수정리', unitKey: '다항식', baseProgress: 0.0),
        ],
      ),
      (
        title: '2. 방정식과 부등식',
        subItems: [
          (
            label: '[개념] 복소수와 이차방정식 (판별식)',
            unitKey: '방정식과 부등식',
            baseProgress: 0.35,
          ),
          (
            label: '[유형] 이차방정식과 이차함수의 최대·최소',
            unitKey: '방정식과 부등식',
            baseProgress: 0.15,
          ),
        ],
      ),
      (
        title: '3. 경우의 수 · 행렬',
        subItems: [
          (
            label: '[개념] 합의 법칙과 곱의 법칙 · 순열과 조합',
            unitKey: '경우의 수',
            baseProgress: 0.25,
          ),
          (label: '[개념] 행렬과 그 연산 (성분과 상등)', unitKey: '행렬', baseProgress: 0.0),
        ],
      ),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
      children: [
        // 검색 바: "🔍 학습하고 싶은 개념을 검색해보세요"
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F7F9),
            borderRadius: BorderRadius.circular(14),
          ),
          child: TextField(
            onChanged: (v) => setState(() => _searchQuery = v.trim()),
            decoration: const InputDecoration(
              icon: Icon(Icons.search_rounded, color: _mutedColor, size: 20),
              hintText: '학습하고 싶은 개념을 검색해보세요',
              hintStyle: TextStyle(fontSize: 13, color: _mutedColor),
              border: InputBorder.none,
            ),
          ),
        ),
        const SizedBox(height: 20),

        Row(
          children: [
            Text(
              '$_selectedGrade · $_selectedSemester (공통수학 1)',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: _purple,
              ),
            ),
            const Spacer(),
            const Text(
              '문제를 풀면 진행률이 실시간 반영됩니다',
              style: TextStyle(fontSize: 11, color: _mutedColor),
            ),
          ],
        ),
        const SizedBox(height: 10),

        ...List.generate(units.length, (idx) {
          final u = units[idx];
          if (_searchQuery.isNotEmpty &&
              !u.title.contains(_searchQuery) &&
              !u.subItems.any((s) => s.label.contains(_searchQuery))) {
            return const SizedBox.shrink();
          }

          final expanded = _expandedUnits.contains(idx);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  setState(() {
                    if (expanded) {
                      _expandedUnits.remove(idx);
                    } else {
                      _expandedUnits.add(idx);
                    }
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Icon(
                        expanded
                            ? Icons.arrow_drop_down_rounded
                            : Icons.arrow_right_rounded,
                        color: _textColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        u.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: _textColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (expanded)
                ...u.subItems.map((sub) {
                  final progressInfo = _calcProgress(
                    sub.unitKey,
                    sub.baseProgress,
                  );

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFEEEEEE)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x08000000),
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _openProblemScreen(unit: sub.unitKey),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    sub.label,
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                      color: _textColor,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  size: 18,
                                  color: _mutedColor,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: progressInfo.$1,
                                minHeight: 6,
                                backgroundColor: const Color(0xFFEEEEEE),
                                color: _purple,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                progressInfo.$2,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: _mutedColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
            ],
          );
        }),
      ],
    );
  }

  // =========================================================================
  // 피그마 4-2: [기출문제] 탭 (연도/월/주관 필터 실제 동작 + 학력평가 기출 카드 리스트)
  // =========================================================================
  Widget _buildPastExamsTab() {
    final allExams = [
      (
        badge: '기출',
        isDone: false,
        year: '2026학년도',
        month: '9월',
        org: '교육청',
        title: '2026학년도 9월 고1 전국연합학력평가',
        status: '진행 중',
        progressText: '${8 + (_solvedCountByTopic['다항식'] ?? 0)} / 30',
        progressVal: ((8 + (_solvedCountByTopic['다항식'] ?? 0)) / 30).clamp(
          0.0,
          1.0,
        ),
        unit: '다항식',
      ),
      (
        badge: '기출',
        isDone: false,
        year: '2026학년도',
        month: '6월',
        org: '교육청',
        title: '2026학년도 6월 고1 전국연합학력평가',
        status: (_solvedCountByTopic['방정식과 부등식'] ?? 0) > 0 ? '진행 중' : '시작 전',
        progressText: '${_solvedCountByTopic['방정식과 부등식'] ?? 0} / 30',
        progressVal: ((_solvedCountByTopic['방정식과 부등식'] ?? 0) / 30).clamp(
          0.0,
          1.0,
        ),
        unit: '방정식과 부등식',
      ),
      (
        badge: '완료',
        isDone: true,
        year: '2025학년도',
        month: '11월',
        org: '교육청',
        title: '2025학년도 11월 고1 전국연합학력평가',
        status: '학습 완료!',
        progressText: '30 / 30',
        progressVal: 1.0,
        unit: '경우의 수',
      ),
      (
        badge: '기출',
        isDone: false,
        year: '2025학년도',
        month: '3월',
        org: '평가원',
        title: '2025학년도 3월 고1 진단 모의평가 (행렬·연산)',
        status: (_solvedCountByTopic['행렬'] ?? 0) > 0 ? '진행 중' : '시작 전',
        progressText: '${_solvedCountByTopic['행렬'] ?? 0} / 30',
        progressVal: ((_solvedCountByTopic['행렬'] ?? 0) / 30).clamp(0.0, 1.0),
        unit: '행렬',
      ),
    ];

    final filteredExams = allExams.where((e) {
      if (_examYear != '시행 연도' && e.year != _examYear) return false;
      if (_examMonth != '시행 월' && e.month != _examMonth) return false;
      if (_examOrg != '주관' && e.org != _examOrg) return false;
      return true;
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildDropdownPill(
                label: _examYear,
                items: const ['시행 연도', '2026학년도', '2025학년도'],
                onChanged: (v) => setState(() => _examYear = v),
              ),
              const SizedBox(width: 8),
              _buildDropdownPill(
                label: _examMonth,
                items: const ['시행 월', '3월', '6월', '9월', '11월'],
                onChanged: (v) => setState(() => _examMonth = v),
              ),
              const SizedBox(width: 8),
              _buildDropdownPill(
                label: _examOrg,
                items: const ['주관', '교육청', '평가원'],
                onChanged: (v) => setState(() => _examOrg = v),
              ),
              if (_examYear != '시행 연도' ||
                  _examMonth != '시행 월' ||
                  _examOrg != '주관') ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _examYear = '시행 연도';
                      _examMonth = '시행 월';
                      _examOrg = '주관';
                    });
                  },
                  child: const Text('필터 초기화', style: TextStyle(fontSize: 12)),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Text(
              '📚 ${filteredExams.length}개의 기출 시험지',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            const Text(
              '최신 시행순 ▼',
              style: TextStyle(fontSize: 11, color: _mutedColor),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (filteredExams.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                '선택한 조건에 맞는 기출문제가 없습니다.',
                style: TextStyle(color: _mutedColor),
              ),
            ),
          ),

        ...filteredExams.map((exam) {
          final barColor = exam.isDone ? const Color(0xFF278B4B) : _purple;

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFEEEEEE)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x08000000),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => _openProblemScreen(unit: exam.unit),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: exam.isDone
                                ? const Color(0xFFEDF8F0)
                                : _lightPurple,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${exam.badge} · ${exam.org}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: barColor,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '연계 단원: ${exam.unit}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: _mutedColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      exam.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _textColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: exam.progressVal,
                        minHeight: 6,
                        backgroundColor: const Color(0xFFEEEEEE),
                        color: barColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          exam.status,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: exam.isDone ? barColor : _mutedColor,
                          ),
                        ),
                        Text(
                          exam.progressText,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: barColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
