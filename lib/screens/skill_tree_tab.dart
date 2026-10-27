import 'package:flutter/material.dart';

import '../services/learning_storage.dart';
import '../services/question_service.dart';
import 'problem_screen.dart';
import 'space_cartoon_painters.dart';

class _SubUnitDetail {
  final String code;
  final String title;
  final String status; // 'MASTERED', 'NEED_STUDY', 'LOCKED'
  final String prerequisitePath;
  final List<String> coreConcepts;
  final List<String> problemTypes;
  final String videoTitle;
  final String videoInstructor;
  final String videoDuration;
  final String targetQuestionUnit;

  const _SubUnitDetail({
    required this.code,
    required this.title,
    required this.status,
    required this.prerequisitePath,
    required this.coreConcepts,
    required this.problemTypes,
    required this.videoTitle,
    required this.videoInstructor,
    required this.videoDuration,
    required this.targetQuestionUnit,
  });
}

class _MiddleUnitData {
  final String title;
  final List<_SubUnitDetail> subUnits;

  const _MiddleUnitData({required this.title, required this.subUnits});
}

class _SatelliteUnitData {
  final String id;
  final String gradeLabel; // '초등', '중1', '중2', '중3', '고1', '고2·고3'
  final String name;
  final String majorUnitTitle;
  final String status;
  final int masteryPercent;
  final double orbitPosition;
  final List<_MiddleUnitData> middleUnits;

  const _SatelliteUnitData({
    required this.id,
    required this.gradeLabel,
    required this.name,
    required this.majorUnitTitle,
    required this.status,
    required this.masteryPercent,
    required this.orbitPosition,
    required this.middleUnits,
  });
}

class _CurriculumPlanetData {
  final String id;
  final String name;
  final String subtitle;
  final Color primaryColor;
  final Color secondaryColor;
  final List<_SatelliteUnitData> satellites;

  const _CurriculumPlanetData({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.primaryColor,
    required this.secondaryColor,
    required this.satellites,
  });
}

class SkillTreeTab extends StatefulWidget {
  final VoidCallback onExperienceChanged;

  const SkillTreeTab({super.key, required this.onExperienceChanged});

  @override
  State<SkillTreeTab> createState() => _SkillTreeTabState();
}

class _SkillTreeTabState extends State<SkillTreeTab>
    with SingleTickerProviderStateMixin {
  static const _purple = Color(0xFF7C5CFA);
  static const _lightPurple = Color(0xFFF3EEFF);
  static const _textColor = Color(0xFF171717);
  static const _mutedColor = Color(0xFF777777);
  static const _outlineDark = Color(0xFF1A0F2E);
  static const _skillId = 'quadratic_minimum_v1';

  late final AnimationController _twinkleController;

  int _topModeIndex = 0;
  String _selectedGradeZone = '전학년 계통도';
  static const _gradeZones = <String>[
    '전학년 계통도',
    '중1',
    '중2',
    '중3',
    '고1',
    '고2·고3',
    '초등구역 (초1~초6)',
    '중등구역 (중1~중3)',
    '고등구역 (고1~고3)',
  ];

  int? _selectedPlanetIndex;
  int _selectedSatelliteIndex = 0;
  int _expandedMiddleUnitIndex = 0;
  int _cascadeKeySeed = 0;

  final List<Map<String, dynamic>> _friends = [
    {
      'name': '김민준 (고1)',
      'streak': 7,
      'xp': 540,
      'badge': '🔥 연속학습 왕',
      'cheered': false,
    },
    {
      'name': '이서연 (고1)',
      'streak': 4,
      'xp': 420,
      'badge': '🪐 변화와 관계 정복중',
      'cheered': false,
    },
    {
      'name': '박지훈 (중3)',
      'streak': 2,
      'xp': 310,
      'badge': '🎬 개념영상 마스터',
      'cheered': false,
    },
  ];

  bool _isUnlocked = false;
  bool _savingSkill = false;
  int _totalSolvedCount = 0;
  int _totalCorrectCount = 0;
  int _myTotalXp = 465;
  final Map<String, int> _topicSolved = {};

  @override
  void initState() {
    super.initState();
    _twinkleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _loadReportState();
  }

  @override
  void dispose() {
    _twinkleController.dispose();
    super.dispose();
  }

  Future<void> _loadReportState() async {
    try {
      final completed = await LearningStorage.hasSkillCompleted(_skillId);
      final sessions = await LearningStorage.loadSessions();
      final exp = await LearningStorage.getExperienceProgress();

      var solved = 0;
      var correct = 0;
      final byTopic = <String, int>{};

      for (final s in sessions) {
        final topic = s['topic']?.toString() ?? '다항식';
        final answers = s['answers'];
        if (answers is List) {
          for (final a in answers) {
            if (a is Map) {
              solved++;
              byTopic[topic] = (byTopic[topic] ?? 0) + 1;
              if (a['isCorrect'] == true) correct++;
            }
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _isUnlocked = completed;
        _totalSolvedCount = solved;
        _totalCorrectCount = correct;
        _myTotalXp = exp.totalXp > 0 ? exp.totalXp : 465;
        _topicSolved
          ..clear()
          ..addAll(byTopic);
      });
    } catch (_) {}
  }

  bool _matchesSelectedGrade(String itemGrade) {
    if (_selectedGradeZone == '전학년 계통도') return true;
    if (_selectedGradeZone.startsWith('초등')) return itemGrade == '초등';
    if (_selectedGradeZone.startsWith('중등')) {
      return itemGrade == '중1' || itemGrade == '중2' || itemGrade == '중3';
    }
    if (_selectedGradeZone.startsWith('고등')) {
      return itemGrade == '고1' || itemGrade == '고2·고3';
    }
    return itemGrade == _selectedGradeZone;
  }

  List<_SatelliteUnitData> _getFilteredSatellites(
    _CurriculumPlanetData planet,
  ) {
    return planet.satellites
        .where((s) => _matchesSelectedGrade(s.gradeLabel))
        .toList();
  }

  void _enterPlanetOrbit(
    int planetIndex, {
    int satIndex = 0,
    int midIndex = 0,
  }) {
    setState(() {
      _selectedPlanetIndex = planetIndex;
      _selectedSatelliteIndex = satIndex;
      _expandedMiddleUnitIndex = midIndex;
      _cascadeKeySeed++;
    });
  }

  List<_CurriculumPlanetData> _buildPlanetsData() {
    return [
      // 1. 변화와 관계
      _CurriculumPlanetData(
        id: 'change_and_relations',
        name: '변화와 관계',
        subtitle: '문자와 식 · 방정식 · 다항식 · 함수',
        primaryColor: const Color(0xFF9B7EFA),
        secondaryColor: const Color(0xFFD6BCFA),
        satellites: [
          _SatelliteUnitData(
            id: 'sat_m1_eq',
            gradeLabel: '중1',
            name: '일차방정식·좌표',
            majorUnitTitle: '[중1 변화와 관계] 문자와 식 · 일차방정식 · 좌표평면과 그래프',
            status: _isUnlocked ? 'MASTERED' : 'NEED_STUDY',
            masteryPercent: _isUnlocked ? 92 : 45,
            orbitPosition: 0.15,
            middleUnits: const [
              _MiddleUnitData(
                title: '중단원 1. 문자와 식 · 일차방정식 이항 (중1)',
                subUnits: [
                  _SubUnitDetail(
                    code: 'SKL-2-037',
                    title: '소단원 01. 등식의 성질과 이항 부호 법칙',
                    status: 'NEED_STUDY',
                    prerequisitePath: '초5 규칙과 대응 ➔ 중1 일차방정식 ➔ 고1 방정식과 부등식',
                    coreConcepts: [
                      '등식의 양변에 같은 수를 더하거나 빼는 원리',
                      '이항 시 부호 반전(-a ➔ +a) 규칙',
                    ],
                    problemTypes: [
                      '[유형 01] 괄호가 있는 일차방정식의 풀이',
                      '[유형 02] 계수가 소수·분수인 방정식의 이항',
                    ],
                    videoTitle: '[5분 개념클립] 이항할 때 부호가 왜 바뀔까? 한 번에 이해하기',
                    videoInstructor: 'EBSi · STEPi AI 튜터 추천',
                    videoDuration: '05:12',
                    targetQuestionUnit: '방정식과 부등식',
                  ),
                ],
              ),
              _MiddleUnitData(
                title: '중단원 2. 좌표평면과 정비례·반비례 그래프 (중1)',
                subUnits: [
                  _SubUnitDetail(
                    code: 'MID-1-04',
                    title: '소단원 01. 순서쌍과 사분면 · 정비례(y=ax)와 반비례(y=a/x)',
                    status: 'MASTERED',
                    prerequisitePath: '초6 비와 비율 ➔ 중1 정비례·반비례 ➔ 중2 일차함수',
                    coreConcepts: [
                      '제1~4사분면 위의 점의 부호 (+, -)',
                      '원점을 지나는 직선 y=ax 와 쌍곡선 y=a/x',
                    ],
                    problemTypes: [
                      '[유형 01] 사분면의 조건이 주어질 때 점의 위치 찾기',
                      '[유형 02] 정비례·반비례 그래프 위의 점의 좌표 구하기',
                    ],
                    videoTitle: '[중1 필수] 함수의 첫걸음! 정비례와 반비례 그래프 완벽 정리',
                    videoInstructor: 'EBSi 중학 수학 클립',
                    videoDuration: '05:40',
                    targetQuestionUnit: '방정식과 부등식',
                  ),
                ],
              ),
            ],
          ),
          const _SatelliteUnitData(
            id: 'sat_m2_func',
            gradeLabel: '중2',
            name: '부등식·일차함수',
            majorUnitTitle: '[중2 변화와 관계] 식의 계산 · 일차부등식 · 연립방정식 · 일차함수',
            status: 'NEED_STUDY',
            masteryPercent: 58,
            orbitPosition: 0.35,
            middleUnits: [
              _MiddleUnitData(
                title: '중단원 1. 일차부등식과 일차함수의 그래프 (중2)',
                subUnits: [
                  _SubUnitDetail(
                    code: 'MID-2-02',
                    title: '소단원 01. 음수를 곱할 때 부등호 반전 & 일차함수 기울기',
                    status: 'NEED_STUDY',
                    prerequisitePath: '중1 일차방정식 ➔ 중2 부등식·일차함수 ➔ 고1 직선의 방정식',
                    coreConcepts: [
                      '양변에 음수를 곱하거나 나누면 부등호 방향이 바뀜',
                      '기울기 a = (y증가량) / (x증가량)',
                    ],
                    problemTypes: [
                      '[유형 01] 부등식의 해의 범위 구하기',
                      '[유형 02] 두 점을 지나는 일차함수의 식 구하기',
                    ],
                    videoTitle: '[여기를 하기! 🔥] 부등식 음수 나눗셈 & 일차함수 기울기 마스터',
                    videoInstructor: 'STEPi 오개념 클립',
                    videoDuration: '04:35',
                    targetQuestionUnit: '방정식과 부등식',
                  ),
                ],
              ),
            ],
          ),
          const _SatelliteUnitData(
            id: 'sat_m3_quad',
            gradeLabel: '중3',
            name: '인수분해·이차함수',
            majorUnitTitle: '[중3 변화와 관계] 다항식의 곱셈과 인수분해 · 이차방정식 · 이차함수',
            status: 'NEED_STUDY',
            masteryPercent: 62,
            orbitPosition: 0.55,
            middleUnits: [
              _MiddleUnitData(
                title: '중단원 1. 인수분해와 이차함수의 꼭짓점 (중3)',
                subUnits: [
                  _SubUnitDetail(
                    code: 'STP-2-014',
                    title: '소단원 01. 완전제곱식과 이차함수 y = a(x-p)² + q',
                    status: 'NEED_STUDY',
                    prerequisitePath: '중2 식의 계산 ➔ 중3 인수분해·이차함수 ➔ 고1 다항식·이차함수',
                    coreConcepts: [
                      '완전제곱식 (a±b)² = a² ± 2ab + b²',
                      '완전제곱식 변형을 통한 꼭짓점 (p, q) 구하기',
                    ],
                    problemTypes: [
                      '[유형 01] 공통인수를 이용한 인수분해',
                      '[유형 02] 이차함수 표준형으로 최솟값 구하기',
                    ],
                    videoTitle: '[여기를 하기! 🔥] 3분 숏폼: 완전제곱식 묶기와 꼭짓점 부호 마스터',
                    videoInstructor: 'STEPi 교육과정 로드맵 강의',
                    videoDuration: '06:40',
                    targetQuestionUnit: '다항식',
                  ),
                ],
              ),
            ],
          ),
          const _SatelliteUnitData(
            id: 'sat_poly',
            gradeLabel: '고1',
            name: '다항식',
            majorUnitTitle: '[고1 공통수학1] I. 다항식 (곱셈공식 · 나머지정리)',
            status: 'NEED_STUDY',
            masteryPercent: 65,
            orbitPosition: 0.75,
            middleUnits: [
              _MiddleUnitData(
                title: '중단원 1. 다항식의 연산과 나머지정리 (고1)',
                subUnits: [
                  _SubUnitDetail(
                    code: 'PRB-1-014',
                    title: '소단원 01. 곱셈 공식 변형과 항등식·나머지정리',
                    status: 'NEED_STUDY',
                    prerequisitePath: '중1 항등식 ➔ 중3 인수분해 ➔ 고1 나머지정리 (현재 취약!)',
                    coreConcepts: [
                      '나머지정리: P(x)를 (x-α)로 나눈 나머지는 R = P(α)',
                      '인수정리: P(α) = 0 ⇔ (x-α)를 인수로 가짐',
                    ],
                    problemTypes: [
                      '[유형 01] 일차식 (x-2)로 나눈 나머지 구하기',
                      '[유형 02] 인수정리를 이용한 미정계수 구하기',
                    ],
                    videoTitle: '[여기를 하기! 🔥] 나머지정리 P(α) 대입할 때 부호 헷갈리지 않는 법',
                    videoInstructor: 'STEPi 오개념 처방 영상',
                    videoDuration: '04:50',
                    targetQuestionUnit: '다항식',
                  ),
                ],
              ),
            ],
          ),
          const _SatelliteUnitData(
            id: 'sat_eq_ineq',
            gradeLabel: '고1',
            name: '방정식과 부등식',
            majorUnitTitle: '[고1 공통수학1] II. 방정식과 부등식',
            status: 'NEED_STUDY',
            masteryPercent: 52,
            orbitPosition: 0.92,
            middleUnits: [
              _MiddleUnitData(
                title: '중단원 1. 복소수와 이차방정식 (고1)',
                subUnits: [
                  _SubUnitDetail(
                    code: 'PRB-2-004',
                    title: '소단원 01. 허수단위 i와 복소수의 상등 · 판별식 D',
                    status: 'NEED_STUDY',
                    prerequisitePath:
                        '중1 일차방정식 이항(SKL-2-037) ➔ 중3 제곱근 ➔ 고1 복소수',
                    coreConcepts: [
                      '허수단위 i² = -1, i⁴ = 1 주기성',
                      '복소수 상등 조건과 판별식 D = b² - 4ac',
                    ],
                    problemTypes: [
                      '[유형 01] 복소수의 상등을 이용한 실수 x, y 구하기',
                      '[유형 02] 이차방정식의 판별식 D 계산하기',
                    ],
                    videoTitle: '[여기를 하기! 🔥] 복소수 실수부·허수부 이항할 때 부호 실수 잡기',
                    videoInstructor: 'EBSi 공통수학1 맞춤 클립',
                    videoDuration: '06:05',
                    targetQuestionUnit: '방정식과 부등식',
                  ),
                ],
              ),
            ],
          ),
        ],
      ),

      // 2. 수와 연산
      const _CurriculumPlanetData(
        id: 'numbers_and_operations',
        name: '수와 연산',
        subtitle: '자연수 · 정수 · 유리수 · 실수 · 행렬',
        primaryColor: Color(0xFF26C6DA),
        secondaryColor: Color(0xFF80DEEA),
        satellites: [
          _SatelliteUnitData(
            id: 'sat_elem_frac',
            gradeLabel: '초등',
            name: '약수·분수 연산',
            majorUnitTitle: '[초5~초6 기초] 약수와 배수 · 분수의 사칙연산',
            status: 'MASTERED',
            masteryPercent: 100,
            orbitPosition: 0.15,
            middleUnits: [
              _MiddleUnitData(
                title: '중단원 1. 약분과 통분 · 분수의 나눗셈',
                subUnits: [
                  _SubUnitDetail(
                    code: 'ELM-5-01',
                    title: '소단원 01. 최소공배수를 이용한 통분과 분수 계산',
                    status: 'MASTERED',
                    prerequisitePath: '초3 분수와 소수 ➔ 초5 약분과 통분 ➔ 중1 유리수의 계산',
                    coreConcepts: ['최대공약수와 최소공배수', '역수를 곱하는 분수 나눗셈'],
                    problemTypes: ['[유형 01] 이분모 분수의 덧셈과 뺄셈'],
                    videoTitle: '[기초 탄탄] 분수 계산 실수를 0으로 만드는 통분 꿀팁',
                    videoInstructor: 'STEPi 기초 수학 클립',
                    videoDuration: '04:10',
                    targetQuestionUnit: '다항식',
                  ),
                ],
              ),
            ],
          ),
          _SatelliteUnitData(
            id: 'sat_m1_int',
            gradeLabel: '중1',
            name: '소인수분해·정수',
            majorUnitTitle: '[중1 수와 연산] 소인수분해 · 정수와 유리수의 사칙연산',
            status: 'NEED_STUDY',
            masteryPercent: 68,
            orbitPosition: 0.35,
            middleUnits: [
              _MiddleUnitData(
                title: '중단원 1. 소인수분해와 정수와 유리수의 사칙연산 (중1)',
                subUnits: [
                  _SubUnitDetail(
                    code: 'MID-1-02',
                    title: '소단원 01. 거듭제곱·약수의 개수 및 음수의 부호 연산 규칙',
                    status: 'NEED_STUDY',
                    prerequisitePath: '초6 분수의 연산 ➔ 중1 소인수분해·정수와 유리수 ➔ 전학년 방정식',
                    coreConcepts: [
                      '소인수분해를 이용한 약수의 개수 공식',
                      '절댓값 정의와 음수의 거듭제곱 부호 결정',
                    ],
                    problemTypes: ['[유형 01] 거듭제곱과 사칙연산이 섞인 유리수의 혼합 계산'],
                    videoTitle: '[여기를 하기! 🔥] 마이너스(-) 부호가 겹칠 때 헷갈리지 않는 법',
                    videoInstructor: 'STEPi 기초 클리닉',
                    videoDuration: '05:15',
                    targetQuestionUnit: '방정식과 부등식',
                  ),
                ],
              ),
            ],
          ),
          _SatelliteUnitData(
            id: 'sat_m2_dec',
            gradeLabel: '중2',
            name: '유리수와 순환소수',
            majorUnitTitle: '[중2 수와 연산] 유리수와 순환소수',
            status: 'MASTERED',
            masteryPercent: 90,
            orbitPosition: 0.55,
            middleUnits: [
              _MiddleUnitData(
                title: '중단원 1. 유한소수와 순환소수의 분수 표현 (중2)',
                subUnits: [
                  _SubUnitDetail(
                    code: 'MID-2-01',
                    title: '소단원 01. 분모의 소인수가 2나 5뿐인 유한소수 판별',
                    status: 'MASTERED',
                    prerequisitePath: '중1 소인수분해 ➔ 중2 유리수와 순환소수 ➔ 중3 실수 체계',
                    coreConcepts: ['기약분수의 분모 소인수 확인', '순환소수를 분수로 고치는 원리'],
                    problemTypes: ['[유형 01] 유한소수가 되도록 하는 미지수 x의 값 구하기'],
                    videoTitle: '[중2 필수] 순환소수를 분수로 빠르게 바꾸는 공식 원리',
                    videoInstructor: 'EBSi 중학 수학 클립',
                    videoDuration: '04:50',
                    targetQuestionUnit: '다항식',
                  ),
                ],
              ),
            ],
          ),
          _SatelliteUnitData(
            id: 'sat_mid_real',
            gradeLabel: '중3',
            name: '제곱근과 실수',
            majorUnitTitle: '[중3 수와 연산] 제곱근과 실수 · 근호를 포함한 식의 계산',
            status: 'MASTERED',
            masteryPercent: 88,
            orbitPosition: 0.75,
            middleUnits: [
              _MiddleUnitData(
                title: '중단원 1. 제곱근의 성질과 무리수 (중3)',
                subUnits: [
                  _SubUnitDetail(
                    code: 'MID-3-01',
                    title: '소단원 01. 절댓값 기호 |a|와 √(a²) = |a| 성질',
                    status: 'MASTERED',
                    prerequisitePath: '중1 정수와 유리수 ➔ 중3 제곱근과 실수 ➔ 고1 복소수·절댓값',
                    coreConcepts: ['절댓값은 원점으로부터의 거리(항상 0 이상)', '분모의 유리화'],
                    problemTypes: ['[유형 01] 근호를 포함한 식의 사칙연산'],
                    videoTitle: '[개념연계] 절댓값과 제곱근 부호 벗기기 완벽 정리',
                    videoInstructor: 'EBSi 중학 수학 클립',
                    videoDuration: '05:30',
                    targetQuestionUnit: '방정식과 부등식',
                  ),
                ],
              ),
            ],
          ),
          _SatelliteUnitData(
            id: 'sat_matrix',
            gradeLabel: '고1',
            name: '행렬과 집합',
            majorUnitTitle: '[고1 공통수학1·2] 행렬과 그 연산 · 집합과 명제',
            status: 'NEED_STUDY',
            masteryPercent: 40,
            orbitPosition: 0.92,
            middleUnits: [
              _MiddleUnitData(
                title: '중단원 1. 행렬의 뜻과 연산',
                subUnits: [
                  _SubUnitDetail(
                    code: 'PRB-4-001',
                    title: '소단원 01. 행렬의 (i, j) 성분과 서로 같은 행렬',
                    status: 'NEED_STUDY',
                    prerequisitePath: '중2 연립일차방정식 ➔ 고1 행렬과 그 연산 (여기를 하기! 🔥)',
                    coreConcepts: ['제i행 제j열의 성분 a_ij 표기법', '두 행렬이 서로 같을 조건'],
                    problemTypes: [
                      '[유형 01] 주어진 행렬에서 a₁₂, a₂₃ 성분 찾기',
                      '[유형 02] 행렬의 상등을 이용한 미지수 구하기',
                    ],
                    videoTitle:
                        '[여기를 하기! 🔥] 2022 개정 교육과정 신설! 행렬의 성분과 연산 5분 정복',
                    videoInstructor: 'EBSi 공통수학1 핵심 강의',
                    videoDuration: '05:45',
                    targetQuestionUnit: '행렬',
                  ),
                ],
              ),
            ],
          ),
        ],
      ),

      // 3. 자료와 가능성
      const _CurriculumPlanetData(
        id: 'data_and_probability',
        name: '자료와 가능성',
        subtitle: '경우의 수 · 순열과 조합 · 원순열 · 확률',
        primaryColor: Color(0xFFFF6090),
        secondaryColor: Color(0xFFFFC1E3),
        satellites: [
          _SatelliteUnitData(
            id: 'sat_m1_stat',
            gradeLabel: '중1',
            name: '자료의 정리와 해석',
            majorUnitTitle: '[중1 자료와 가능성] 대푯값 · 줄기와 잎 그림 · 도수분포표 · 상대도수',
            status: 'MASTERED',
            masteryPercent: 94,
            orbitPosition: 0.15,
            middleUnits: [
              _MiddleUnitData(
                title: '중단원 1. 도수분포표와 히스토그램·상대도수 (중1)',
                subUnits: [
                  _SubUnitDetail(
                    code: 'STA-1-01',
                    title: '소단원 01. 계급의 크기와 도수 · 상대도수의 총합은 항상 1',
                    status: 'MASTERED',
                    prerequisitePath: '초5~6 평균과 그래프 ➔ 중1 도수분포표·상대도수 ➔ 중3 산포도',
                    coreConcepts: [
                      '상대도수 = (계급의 도수) / (도수의 총합)',
                      '히스토그램 넓이의 합 = (계급 크기) × (총도수)',
                    ],
                    problemTypes: ['[유형 01] 일부가 찢어진 상대도수 분포표에서 도수 구하기'],
                    videoTitle: '[중1 통계] 히스토그램과 도수분포다각형 핵심 개념 4분 정리',
                    videoInstructor: 'EBSi 중학 수학 클립',
                    videoDuration: '04:15',
                    targetQuestionUnit: '경우의 수',
                  ),
                ],
              ),
            ],
          ),
          _SatelliteUnitData(
            id: 'sat_mid_prob',
            gradeLabel: '중2',
            name: '경우의 수와 확률',
            majorUnitTitle: '[중2 자료와 가능성] 사건과 경우의 수 · 확률의 뜻과 성질',
            status: 'MASTERED',
            masteryPercent: 95,
            orbitPosition: 0.38,
            middleUnits: [
              _MiddleUnitData(
                title: '중단원 1. 사건과 경우의 수 (중2)',
                subUnits: [
                  _SubUnitDetail(
                    code: 'MID-2-08',
                    title: '소단원 01. 동시에 일어나는 사건과 순서쌍',
                    status: 'MASTERED',
                    prerequisitePath: '초5 가능성 ➔ 중2 경우의 수 ➔ 고1 순열과 조합',
                    coreConcepts: ['수형도 그리기', '주사위와 동전 던지기 경우의 수'],
                    problemTypes: ['[유형 01] 두 사건이 동시에 일어날 때의 경우의 수'],
                    videoTitle: '[기초 완성] 헷갈리는 합의 법칙 vs 곱의 법칙 구별법',
                    videoInstructor: 'STEPi 개념 클립',
                    videoDuration: '04:20',
                    targetQuestionUnit: '경우의 수',
                  ),
                ],
              ),
            ],
          ),
          _SatelliteUnitData(
            id: 'sat_m3_disp',
            gradeLabel: '중3',
            name: '산포도와 상관관계',
            majorUnitTitle: '[중3 자료와 가능성] 분산과 표준편차 · 산점도와 상관관계',
            status: 'MASTERED',
            masteryPercent: 85,
            orbitPosition: 0.60,
            middleUnits: [
              _MiddleUnitData(
                title: '중단원 1. 편차의 합(0)과 분산·표준편차 (중3)',
                subUnits: [
                  _SubUnitDetail(
                    code: 'STA-3-01',
                    title: '소단원 01. 편차 = (변량 - 평균) · 분산과 표준편차 구하기',
                    status: 'MASTERED',
                    prerequisitePath: '중1 대푯값과 도수분포표 ➔ 중3 산포도 ➔ 고2 확률과 통계',
                    coreConcepts: ['편차의 총합은 항상 0', '분산 = (편차²의 총합) / (변량의 개수)'],
                    problemTypes: ['[유형 01] 편차가 주어질 때 미지수 x와 표준편차 구하기'],
                    videoTitle: '[중3 통계] 편차·분산·표준편차 계산 실수 줄이는 표 작성법',
                    videoInstructor: 'EBSi 중학 수학 클립',
                    videoDuration: '05:05',
                    targetQuestionUnit: '경우의 수',
                  ),
                ],
              ),
            ],
          ),
          _SatelliteUnitData(
            id: 'sat_perm_comb',
            gradeLabel: '고1',
            name: '순열과 조합',
            majorUnitTitle: '[고1 공통수학1] III. 경우의 수 (순열 nPr · 조합 nCr)',
            status: 'NEED_STUDY',
            masteryPercent: 60,
            orbitPosition: 0.78,
            middleUnits: [
              _MiddleUnitData(
                title: '중단원 1. 합의 법칙과 곱의 법칙 · 순열과 조합',
                subUnits: [
                  _SubUnitDetail(
                    code: 'PRB-3-009',
                    title: '소단원 01. 순열(nPr)과 조합(nCr)의 계산과 차이',
                    status: 'NEED_STUDY',
                    prerequisitePath:
                        '중2 경우의 수 ➔ 고1 순열과 조합 (여기를 하기! 🔥) ➔ 고2 원순열',
                    coreConcepts: ['순열 nPr (순서 O)', '조합 nCr = nPr / r! (순서 X)'],
                    problemTypes: [
                      '[유형 01] 셔츠와 바지를 고르는 곱의 법칙',
                      '[유형 02] 6P2와 6C2 빠르게 계산하기',
                    ],
                    videoTitle: '[여기를 하기! 🔥] 뽑아서 나열(nPr) vs 그냥 뽑기(nCr) 실전 구분법',
                    videoInstructor: 'EBSi 공통수학1 핵심 강의',
                    videoDuration: '05:50',
                    targetQuestionUnit: '경우의 수',
                  ),
                ],
              ),
            ],
          ),
          _SatelliteUnitData(
            id: 'sat_circular_perm',
            gradeLabel: '고2·고3',
            name: '원순열 🔒',
            majorUnitTitle: '[고2~고3 확률과 통계] 여러 가지 순열 · 원순열',
            status: 'LOCKED',
            masteryPercent: 0,
            orbitPosition: 0.94,
            middleUnits: [
              _MiddleUnitData(
                title: '중단원 1. 원순열과 중복순열 (선수단원 완료 후 해금)',
                subUnits: [
                  _SubUnitDetail(
                    code: 'PRB-H2-01',
                    title: '소단원 01. 원탁에 둘러앉는 원순열의 수 (n-1)!',
                    status: 'LOCKED',
                    prerequisitePath:
                        '🔒 [고1 순열과 조합(nPr, nCr)]을 먼저 마스터하면 원순열 위성이 열려요!',
                    coreConcepts: ['회전하여 일치하는 배열은 같은 것으로 봄: n! / n = (n-1)!'],
                    problemTypes: ['[유형 01] 원탁에 n명이 둘러앉는 경우의 수'],
                    videoTitle: '[확률과 통계 예고] 왜 원순열은 n!을 n으로 나눌까?',
                    videoInstructor: 'EBSi 확률과 통계 클립',
                    videoDuration: '06:20',
                    targetQuestionUnit: '경우의 수',
                  ),
                ],
              ),
            ],
          ),
        ],
      ),

      // 4. 도형과 측정
      const _CurriculumPlanetData(
        id: 'geometry_and_measurement',
        name: '도형과 측정',
        subtitle: '평면도형 · 피타고라스 · 원과 직선의 방정식',
        primaryColor: Color(0xFFFFB300),
        secondaryColor: Color(0xFFFFE082),
        satellites: [
          _SatelliteUnitData(
            id: 'sat_m1_geo',
            gradeLabel: '중1',
            name: '기본도형·합동·입체',
            majorUnitTitle: '[중1 도형과 측정] 기본 도형 · 작도와 합동 · 평면·입체도형의 측정',
            status: 'NEED_STUDY',
            masteryPercent: 60,
            orbitPosition: 0.20,
            middleUnits: [
              _MiddleUnitData(
                title: '중단원 1. 삼각형의 합동(SSS, SAS, ASA)과 부채꼴·입체도형 (중1)',
                subUnits: [
                  _SubUnitDetail(
                    code: 'GEO-1-02',
                    title: '소단원 01. 평행선 동위각·엇각, 삼각형 합동, 부채꼴 호와 넓이(1/2 rl)',
                    status: 'NEED_STUDY',
                    prerequisitePath: '초6 원의 넓이 ➔ 중1 작도와 합동·부채꼴 ➔ 중2 도형의 성질·닮음',
                    coreConcepts: [
                      '삼각형의 합동 조건 (SSS, SAS, ASA)',
                      '부채꼴 넓이 S = πr² × (x/360) = 1/2 rl',
                    ],
                    problemTypes: [
                      '[유형 01] 평행선에서 각의 크기 구하기',
                      '[유형 02] 원기둥·원뿔·구의 겉넓이와 부피 구하기',
                    ],
                    videoTitle: '[여기를 하기! 🔥] 중1 삼각형 합동 조건 & 부채꼴 공식 암기 꿀팁',
                    videoInstructor: 'STEPi 도형 클리닉',
                    videoDuration: '04:40',
                    targetQuestionUnit: '방정식과 부등식',
                  ),
                ],
              ),
            ],
          ),
          _SatelliteUnitData(
            id: 'sat_m2_sim',
            gradeLabel: '중2',
            name: '외심·닮음·피타고라스',
            majorUnitTitle: '[중2 도형과 측정] 삼각형·사각형의 성질 · 도형의 닮음 · 피타고라스 정리',
            status: 'NEED_STUDY',
            masteryPercent: 54,
            orbitPosition: 0.45,
            middleUnits: [
              _MiddleUnitData(
                title: '중단원 1. 삼각형의 외심·내심과 피타고라스 정리 (중2)',
                subUnits: [
                  _SubUnitDetail(
                    code: 'GEO-2-02',
                    title: '소단원 01. 직각삼각형의 피타고라스 정리 (a² + b² = c²)',
                    status: 'NEED_STUDY',
                    prerequisitePath:
                        '중1 삼각형의 합동 ➔ 중2 피타고라스 정리 ➔ 고1 두 점 사이의 거리',
                    coreConcepts: [
                      '외심과 내심의 성질',
                      '직각삼각형 빗변의 제곱은 나머지 두 변의 제곱의 합과 같음',
                    ],
                    problemTypes: ['[유형 01] 피타고라스 정리를 이용한 직각삼각형 변의 길이 구하기'],
                    videoTitle: '[여기를 하기! 🔥] 고1 좌표평면 공식의 뿌리! 피타고라스 정리 4분 완성',
                    videoInstructor: 'STEPi 역추적 도형 클립',
                    videoDuration: '04:15',
                    targetQuestionUnit: '방정식과 부등식',
                  ),
                ],
              ),
            ],
          ),
          _SatelliteUnitData(
            id: 'sat_pythagoras',
            gradeLabel: '중3',
            name: '삼각비·원의 성질',
            majorUnitTitle: '[중3 도형과 측정] 삼각비(sin, cos, tan) · 원과 현·접선의 성질',
            status: 'NEED_STUDY',
            masteryPercent: 55,
            orbitPosition: 0.70,
            middleUnits: [
              _MiddleUnitData(
                title: '중단원 1. 원의 중심과 현의 수직이등분선 (중3)',
                subUnits: [
                  _SubUnitDetail(
                    code: 'GEO-3-02',
                    title: '소단원 01. 원의 현의 길이와 피타고라스 정리',
                    status: 'NEED_STUDY',
                    prerequisitePath:
                        '중2 피타고라스 정리 ➔ 중3 원과 직선 ➔ 고1 원의 방정식 (여기를 하기!)',
                    coreConcepts: [
                      '원의 중심에서 현에 내린 수선은 그 현을 이등분함',
                      'r² = d² + (l/2)²',
                    ],
                    problemTypes: ['[유형 01] 원이 직선에 의해 잘린 현의 길이 4√5 활용하기'],
                    videoTitle:
                        '[여기를 하기! 🔥] 고1 원의 방정식 전에 꼭 봐야 할 중3 원과 현 3분 요약',
                    videoInstructor: 'STEPi 역추적 도형 클립',
                    videoDuration: '03:55',
                    targetQuestionUnit: '방정식과 부등식',
                  ),
                ],
              ),
            ],
          ),
          _SatelliteUnitData(
            id: 'sat_circle_eq',
            gradeLabel: '고1',
            name: '원의 방정식 🔒',
            majorUnitTitle: '[고1 공통수학2] 도형의 방정식 · 원과 직선',
            status: 'LOCKED',
            masteryPercent: 20,
            orbitPosition: 0.90,
            middleUnits: [
              _MiddleUnitData(
                title: '중단원 1. 원과 직선의 위치 관계',
                subUnits: [
                  _SubUnitDetail(
                    code: 'STP-3-01',
                    title: '소단원 01. 점과 직선 사이의 거리 공식과 현의 길이',
                    status: 'LOCKED',
                    prerequisitePath:
                        '🔒 [선수단원] 중3 원과 현의 성질 + 중1 일차방정식 이항 완료 시 해금!',
                    coreConcepts: [
                      '점과 직선 사이의 거리 d = |ax₁+by₁+c|/√(a²+b²)',
                      '절댓값 기호 누락 방지',
                    ],
                    problemTypes: [
                      '[유형 01] 원 (x-1)²+(y-1)²=25와 직선이 만드는 현의 길이로 k 구하기',
                    ],
                    videoTitle: '[심화 예고] 원과 직선의 위치 관계 · 판별식보다 빠른 중심거리 d 공식',
                    videoInstructor: 'EBSi 공통수학2 대표 강의',
                    videoDuration: '08:10',
                    targetQuestionUnit: '방정식과 부등식',
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ];
  }

  Future<void> _startPrescribedTraining({String unit = '방정식과 부등식'}) async {
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
    await _loadReportState();
    widget.onExperienceChanged();
  }

  void _openVideoLectureSheet(_SubUnitDetail subUnit) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEFEF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '🎬 맞춤 개념 영상 추천',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFE53E3E),
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  subUnit.videoTitle,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: _textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${subUnit.videoInstructor} · 재생시간 ${subUnit.videoDuration}',
                  style: const TextStyle(fontSize: 12, color: _mutedColor),
                ),
                const SizedBox(height: 16),
                Container(
                  height: 180,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1A1B2F), Color(0xFF2E236C)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: const BoxDecoration(
                            color: _purple,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            size: 36,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            subUnit.coreConcepts.first,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _lightPurple,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '🔗 계통도 연결: ${subUnit.prerequisitePath}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _purple,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          try {
                            await LearningStorage.completeSkill(_skillId);
                          } catch (_) {}
                          if (!mounted) return;
                          if (sheetContext.mounted) {
                            Navigator.of(sheetContext).pop();
                          }
                          await _loadReportState();
                          widget.onExperienceChanged();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: _purple,
                              content: Text(
                                '🎬 개념 영상 학습 완료! 선수개념 상태가 업데이트되었어요.',
                              ),
                            ),
                          );
                        },
                        child: const Text(
                          '영상 시청 완료 체크 ✓',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          _startPrescribedTraining(
                            unit: subUnit.targetQuestionUnit,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _purple,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text(
                          '관련 유형 문제 풀기 ▶',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openPrerequisiteQuizSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
                    const Expanded(
                      child: Text(
                        '💡 선수개념 역추적 보완 (SKL-2-037)',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: _purple,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const Text(
                  '중1·중2 일차방정식에서 이항하기 ➔ 고1 방정식과 부등식',
                  style: TextStyle(fontSize: 12, color: _mutedColor),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _lightPurple,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'Q. 2x - 5 = 3 에서 -5를 우변으로 이항했을 때 올바른 식은? (완료 보상 +10 XP)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('이항할 때는 양변에 +5를 더하므로 부호가 +로 바뀌어요!'),
                            ),
                          );
                        },
                        child: const Text('2x = 3 - 5'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _savingSkill
                            ? null
                            : () async {
                                setState(() => _savingSkill = true);
                                try {
                                  await LearningStorage.completeSkill(_skillId);
                                } catch (_) {}
                                if (!mounted) return;
                                if (sheetContext.mounted) {
                                  Navigator.of(sheetContext).pop();
                                }
                                setState(() {
                                  _isUnlocked = true;
                                  _savingSkill = false;
                                });
                                await _loadReportState();
                                widget.onExperienceChanged();
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    backgroundColor: _purple,
                                    content: Text(
                                      '🎉 이항 부호 선수개념 충전 완료! +10 XP 획득!',
                                    ),
                                  ),
                                );
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _purple,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('2x = 3 + 5'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openAddFriendDialog() {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            '👥 친구 코드 연결하기',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: '친구 닉네임 또는 초대코드',
              hintText: '예: 최유진 (고1)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () {
                final name = controller.text.trim();
                Navigator.of(dialogContext).pop();
                if (name.isNotEmpty) {
                  setState(() {
                    _friends.add({
                      'name': name,
                      'streak': 1,
                      'xp': 250,
                      'badge': '🌱 오늘 함께 시작!',
                      'cheered': false,
                    });
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: _purple,
                      content: Text('$name 님과 학습 라이벌로 연결되었어요! 🔥'),
                    ),
                  );
                }
              },
              style: FilledButton.styleFrom(backgroundColor: _purple),
              child: const Text('연결하기'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final planets = _buildPlanetsData();

    return ColoredBox(
      color: const Color(0xFFF9F9FB),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECEAF5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildTopSegmentButton(
                          title: '🪐 우주 계통도 스킬트리',
                          active: _topModeIndex == 0,
                          onTap: () => setState(() => _topModeIndex = 0),
                        ),
                      ),
                      Expanded(
                        child: _buildTopSegmentButton(
                          title: '📊 리포트·전국순위·친구',
                          active: _topModeIndex == 1,
                          onTap: () => setState(() => _topModeIndex = 1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: _topModeIndex == 0
                    ? AnimatedSwitcher(
                        duration: const Duration(milliseconds: 450),
                        switchInCurve: Curves.easeOutBack,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) {
                          final scale = Tween<double>(
                            begin: 0.84,
                            end: 1.0,
                          ).animate(animation);
                          return FadeTransition(
                            opacity: animation,
                            child: ScaleTransition(scale: scale, child: child),
                          );
                        },
                        child: _selectedPlanetIndex == null
                            ? _buildGalaxyOverviewList(planets)
                            : _buildPlanetOrbitDetailList(planets),
                      )
                    : _buildReportAndCompetitionView(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopSegmentButton({
    required String title,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: active
              ? const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w900,
            color: active ? _purple : _mutedColor,
          ),
        ),
      ),
    );
  }

  Widget _buildGalaxyOverviewList(List<_CurriculumPlanetData> planets) {
    return ListView(
      key: const ValueKey<String>('galaxy_overview'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '한국 교육과정 우주 계통도',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: _textColor,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '행성을 누르면 줌인되면서 단원 위성과 개념이 촤라락 펼쳐져요!',
                    style: TextStyle(fontSize: 11.5, color: _mutedColor),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF231754),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _outlineDark, width: 2.5),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedGradeZone,
                  isDense: true,
                  dropdownColor: const Color(0xFF231754),
                  icon: const Icon(
                    Icons.arrow_drop_down_rounded,
                    color: Color(0xFFFFD54F),
                  ),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFFFD54F),
                  ),
                  items: _gradeZones
                      .map((z) => DropdownMenuItem(value: z, child: Text(z)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        _selectedGradeZone = v;
                        _selectedSatelliteIndex = 0;
                        _expandedMiddleUnitIndex = 0;
                      });
                    }
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['전학년 계통도', '중1', '중2', '중3', '고1', '고2·고3'].map((g) {
              final active = _selectedGradeZone == g;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(
                    g == '전학년 계통도' ? '🌌 전학년' : '🎯 $g만 보기',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      color: active ? Colors.white : _textColor,
                    ),
                  ),
                  selected: active,
                  selectedColor: _purple,
                  backgroundColor: Colors.white,
                  onSelected: (_) {
                    setState(() {
                      _selectedGradeZone = g;
                      _selectedSatelliteIndex = 0;
                      _expandedMiddleUnitIndex = 0;
                    });
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 10),
        InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _enterPlanetOrbit(0, satIndex: 0, midIndex: 0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF39227A), Color(0xFF21134D)],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _outlineDark, width: 3.0),
            ),
            child: const Row(
              children: [
                CrewmateMascotBadge(suitColor: Color(0xFFFFEE58), size: 40),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '크루원 긴급 미션: 지금 여기를 먼저 수리해요!',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFFFEE58),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '[변화와 관계 행성] 중1 이항 부호 ➔ 고1 나머지정리·복소수 즉시 출동 ▶',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // 2x2 Grid 구조 어몽어스/카툰 성운 맵 (겹침 0% 보장)
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: _outlineDark, width: 3.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x331A0F2E),
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _twinkleController,
                  builder: (context, _) => CustomPaint(
                    painter: CartoonSpaceBackgroundPainter(
                      twinkleValue: _twinkleController.value,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xDD1A0F2E),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFFB388FF),
                            width: 1.8,
                          ),
                        ),
                        child: Text(
                          '🛸 $_selectedGradeZone · 행성을 터치해 궤도로 줌인하세요!',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildCartoonPlanetTile(
                            index: 0,
                            planet: planets[0],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildCartoonPlanetTile(
                            index: 1,
                            planet: planets[1],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildCartoonPlanetTile(
                            index: 2,
                            planet: planets[2],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildCartoonPlanetTile(
                            index: 3,
                            planet: planets[3],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xEE140C29),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFF7C5CFA),
                          width: 2.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          const CrewmateMascotBadge(
                            suitColor: Color(0xFF4DD0E1),
                            size: 28,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '우주 탐사 브리핑: "현재 [$_selectedGradeZone] 단원만 표시 중! 행성을 누르면 세부 단원이 촤라락 펼쳐집니다."',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          '교육과정 4대 영역별 내 마스터 현황 ($_selectedGradeZone)',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: _textColor,
          ),
        ),
        const SizedBox(height: 10),
        ...List.generate(planets.length, (idx) {
          final p = planets[idx];
          final filteredSats = _getFilteredSatellites(p);
          final needStudySats = filteredSats
              .where((s) => s.status == 'NEED_STUDY')
              .map((s) => '${s.gradeLabel} ${s.name}')
              .join(', ');
          final satNames = filteredSats
              .map((s) => s.name.replaceAll(' 🔒', ''))
              .join(' · ');

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFEEEEEE)),
            ),
            child: ListTile(
              onTap: () => _enterPlanetOrbit(idx),
              leading: CircleAvatar(
                backgroundColor: p.primaryColor.withAlpha(40),
                child: Icon(Icons.public_rounded, color: p.primaryColor),
              ),
              title: Text(
                '${p.name} 행성 (${satNames.isNotEmpty ? satNames : p.subtitle})',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: Text(
                needStudySats.isNotEmpty
                    ? '🔥 지금 공부할 위성: $needStudySats'
                    : '✅ 선택 학년 기초 위성 학습 완료',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: needStudySats.isNotEmpty
                      ? const Color(0xFFE53E3E)
                      : const Color(0xFF278B4B),
                ),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildCartoonPlanetTile({
    required int index,
    required _CurriculumPlanetData planet,
  }) {
    final filteredSats = _getFilteredSatellites(planet);
    final needStudyCount = filteredSats
        .where((s) => s.status == 'NEED_STUDY')
        .length;
    final unitSummaryText = filteredSats.isEmpty
        ? '해당 학년 단원 없음'
        : filteredSats.map((s) => s.name.replaceAll(' 🔒', '')).join(' · ');

    return GestureDetector(
      onTap: () => _enterPlanetOrbit(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0x88180E38),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: planet.primaryColor.withAlpha(160),
            width: 2.0,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: needStudyCount > 0
                    ? const Color(0xFFFF4B4B)
                    : const Color(0xFF00C853),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _outlineDark, width: 2.0),
              ),
              child: Text(
                needStudyCount > 0 ? '여기를 하기! ($needStudyCount) 🔥' : '탐사 완료 ✓',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Stack(
              alignment: Alignment.center,
              children: [
                CartoonPlanetOrb(
                  planetId: planet.id,
                  primaryColor: planet.primaryColor,
                  secondaryColor: planet.secondaryColor,
                  size: 80,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _outlineDark.withAlpha(200),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    planet.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xEE120A2A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _outlineDark, width: 2.0),
              ),
              child: Text(
                unitSummaryText,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFEDE7F6),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanetOrbitDetailList(List<_CurriculumPlanetData> planets) {
    final planet = planets[_selectedPlanetIndex!];
    final filteredSatellites = _getFilteredSatellites(planet);
    final activeSatellites = filteredSatellites.isNotEmpty
        ? filteredSatellites
        : planet.satellites;
    final safeSatIndex = _selectedSatelliteIndex.clamp(
      0,
      activeSatellites.length - 1,
    );
    final selectedSatellite = activeSatellites[safeSatIndex];

    return ListView(
      key: ValueKey<String>(
        'orbit_${planet.id}_${_selectedGradeZone}_$_cascadeKeySeed',
      ),
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 120),
      children: [
        Row(
          children: [
            TextButton.icon(
              onPressed: () => setState(() => _selectedPlanetIndex = null),
              icon: const Icon(Icons.zoom_out_map_rounded, size: 18),
              label: const Text(
                '우주 전체 맵으로 줌아웃',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF231754),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _outlineDark, width: 2),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedGradeZone,
                  isDense: true,
                  dropdownColor: const Color(0xFF231754),
                  icon: const Icon(
                    Icons.arrow_drop_down_rounded,
                    color: Color(0xFFFFD54F),
                  ),
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFFFD54F),
                  ),
                  items: _gradeZones
                      .map((z) => DropdownMenuItem(value: z, child: Text(z)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        _selectedGradeZone = v;
                        _selectedSatelliteIndex = 0;
                        _expandedMiddleUnitIndex = 0;
                        _cascadeKeySeed++;
                      });
                    }
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 265,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: _outlineDark, width: 3.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                painter: CartoonSpaceBackgroundPainter(
                  twinkleValue: _twinkleController.value,
                ),
              ),
              CustomPaint(
                painter: CartoonOrbitArcPainter(
                  orbitColor: planet.primaryColor,
                  secondaryColor: planet.secondaryColor,
                ),
              ),
              Positioned(
                top: 12,
                left: 16,
                right: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🪐 ${planet.name} 궤도 ($_selectedGradeZone · ${activeSatellites.length}개 단원 위성)',
                      style: const TextStyle(
                        color: Color(0xFFFFEE58),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      '위성을 터치하면 아래에 중단원·소단원·개념 영상이 촤라락 펼쳐집니다!',
                      style: TextStyle(color: Colors.white70, fontSize: 10.5),
                    ),
                  ],
                ),
              ),
              ...List.generate(activeSatellites.length, (sIdx) {
                final sat = activeSatellites[sIdx];
                final isSelected = sIdx == safeSatIndex;
                final t = activeSatellites.length == 1
                    ? 0.5
                    : sIdx / (activeSatellites.length - 1);
                final alignX = -0.74 + (t * 1.48);
                final alignY = 0.58 - (t * 0.78);

                final Color badgeColor = sat.status == 'MASTERED'
                    ? const Color(0xFF00E676)
                    : (sat.status == 'NEED_STUDY'
                          ? const Color(0xFFFF4B4B)
                          : const Color(0xFF90A4AE));
                final String statusBadge = sat.status == 'MASTERED'
                    ? '완료 ✓'
                    : (sat.status == 'NEED_STUDY' ? '여기를 하기! 🔥' : '잠김 🔒');

                return Align(
                  alignment: Alignment(alignX, alignY),
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey<String>(
                      'sat_${sat.id}_${_selectedGradeZone}_$_cascadeKeySeed',
                    ),
                    tween: Tween<double>(begin: 0.0, end: 1.0),
                    duration: Duration(milliseconds: 350 + (sIdx * 110)),
                    curve: Curves.easeOutBack,
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: Opacity(
                          opacity: value.clamp(0.0, 1.0),
                          child: child,
                        ),
                      );
                    },
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedSatelliteIndex = sIdx;
                          _expandedMiddleUnitIndex = 0;
                          _cascadeKeySeed++;
                        });
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: badgeColor,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _outlineDark,
                                width: 2.0,
                              ),
                            ),
                            child: Text(
                              '${sat.gradeLabel} · $statusBadge',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            width: isSelected ? 80 : 66,
                            height: isSelected ? 80 : 66,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: sat.status == 'LOCKED'
                                  ? const Color(0xFF37474F)
                                  : Colors.white,
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFFFFEE58)
                                    : _outlineDark,
                                width: isSelected ? 4.0 : 3.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: badgeColor.withAlpha(150),
                                  blurRadius: isSelected ? 16 : 6,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(5),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (sat.status == 'LOCKED')
                                      const Icon(
                                        Icons.lock_rounded,
                                        size: 14,
                                        color: Colors.white70,
                                      ),
                                    Text(
                                      sat.name.replaceAll(' 🔒', ''),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w900,
                                        color: sat.status == 'LOCKED'
                                            ? Colors.white70
                                            : _textColor,
                                        height: 1.15,
                                      ),
                                    ),
                                    if (sat.status != 'LOCKED')
                                      Text(
                                        '${sat.masteryPercent}%',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w900,
                                          color: badgeColor,
                                        ),
                                      ),
                                  ],
                                ),
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
          ),
        ),
        const SizedBox(height: 16),
        _buildCascadingRevealItem(
          index: 0,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _outlineDark, width: 2.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _lightPurple,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '대단원 위성 · ${selectedSatellite.gradeLabel} 과정',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: _purple,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '숙련도 ${selectedSatellite.masteryPercent}%',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: _purple,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  selectedSatellite.majorUnitTitle,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: _textColor,
                  ),
                ),
                const SizedBox(height: 14),
                ...List.generate(selectedSatellite.middleUnits.length, (mIdx) {
                  final mid = selectedSatellite.middleUnits[mIdx];
                  final isExpanded = _expandedMiddleUnitIndex == mIdx;

                  return _buildCascadingRevealItem(
                    index: mIdx + 1,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9F9FC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isExpanded ? _purple : const Color(0xFFE2E8F0),
                          width: isExpanded ? 2.0 : 1.2,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => setState(
                              () => _expandedMiddleUnitIndex = isExpanded
                                  ? -1
                                  : mIdx,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isExpanded
                                        ? Icons.folder_open_rounded
                                        : Icons.folder_rounded,
                                    color: _purple,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      mid.title,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: _textColor,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    isExpanded
                                        ? Icons.keyboard_arrow_up_rounded
                                        : Icons.keyboard_arrow_down_rounded,
                                    color: _mutedColor,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                            child: !isExpanded
                                ? const SizedBox.shrink()
                                : Column(
                                    children: mid.subUnits
                                        .map(_buildSubUnitCard)
                                        .toList(),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCascadingRevealItem({
    required int index,
    required Widget child,
  }) {
    return TweenAnimationBuilder<double>(
      key: ValueKey<String>('cascade_${_cascadeKeySeed}_$index'),
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 360 + (index * 90)),
      curve: Curves.easeOutCubic,
      builder: (context, val, inner) {
        return Opacity(
          opacity: val.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1.0 - val) * 28),
            child: inner,
          ),
        );
      },
      child: child,
    );
  }

  Widget _buildSubUnitCard(_SubUnitDetail sub) {
    final isNeedStudy = sub.status == 'NEED_STUDY';
    final isLocked = sub.status == 'LOCKED';

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isNeedStudy
              ? const Color(0xFFFF6B6B)
              : const Color(0xFFE2E8F0),
          width: isNeedStudy ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  sub.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: _textColor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isNeedStudy
                      ? const Color(0xFFFFEFEF)
                      : (isLocked
                            ? const Color(0xFFEEEEEE)
                            : const Color(0xFFEDF8F0)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isNeedStudy ? '여기를 하기! 🔥' : (isLocked ? '잠김 🔒' : '알고 있음 ✓'),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    color: isNeedStudy
                        ? const Color(0xFFE53E3E)
                        : (isLocked ? _mutedColor : const Color(0xFF278B4B)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _lightPurple,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '🧭 계통도 연결: ${sub.prerequisitePath}',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: _purple,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '📘 배워야 할 필수 개념',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: _textColor,
            ),
          ),
          const SizedBox(height: 6),
          ...sub.coreConcepts.map(
            (c) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '• $c',
                style: const TextStyle(fontSize: 12, color: Color(0xFF4A5568)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '🧩 자주 나오는 대표 유형',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: _textColor,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: sub.problemTypes
                .map(
                  (t) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      t,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 14),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _openVideoLectureSheet(sub),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8F8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFED7D7)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE53E3E),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.ondemand_video_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sub.videoTitle,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: _textColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${sub.videoInstructor} (${sub.videoDuration}) · 터치해서 강의 보기',
                          style: const TextStyle(
                            fontSize: 11,
                            color: _mutedColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openVideoLectureSheet(sub),
                  icon: const Icon(Icons.play_circle_outline_rounded, size: 18),
                  label: const Text(
                    '개념 영상 보기',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (sub.code == 'SKL-2-037') {
                      _openPrerequisiteQuizSheet();
                    } else {
                      _startPrescribedTraining(unit: sub.targetQuestionUnit);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _purple,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.edit_note_rounded, size: 18),
                  label: const Text(
                    '유형 문제 풀기 ▶',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReportAndCompetitionView() {
    final accuracyPercent = _totalSolvedCount > 0
        ? ((_totalCorrectCount / _totalSolvedCount) * 100).round()
        : 78;
    final radarValues = <double>[
      (0.75 + (_topicSolved['다항식'] ?? 0) * 0.05).clamp(0.2, 1.0),
      (0.62 + (_topicSolved['방정식과 부등식'] ?? 0) * 0.06).clamp(0.2, 1.0),
      (_isUnlocked ? 0.82 : 0.55),
      (0.65 + (_topicSolved['경우의 수'] ?? 0) * 0.06).clamp(0.2, 1.0),
      (0.70 + (_topicSolved['행렬'] ?? 0) * 0.06).clamp(0.2, 1.0),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _lightPurple,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '학부모 · 선생님 WEB 실시간 연동 지표',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: _purple,
                      ),
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.workspace_premium_rounded,
                    color: Color(0xFFD97706),
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSummaryStat(label: '전국 학년 순위', value: '상위 14.2%'),
                  Container(
                    width: 1,
                    height: 28,
                    color: const Color(0xFFEEEEEE),
                  ),
                  _buildSummaryStat(
                    label: '평균 정답률',
                    value: '$accuracyPercent%',
                  ),
                  Container(
                    width: 1,
                    height: 28,
                    color: const Color(0xFFEEEEEE),
                  ),
                  _buildSummaryStat(
                    label: '누적 풀이',
                    value:
                        '${_totalSolvedCount > 0 ? _totalSolvedCount : 12}문항',
                  ),
                ],
              ),
              const Divider(height: 24),
              const Text(
                '📋 학부모·선생님께 제시되는 추천 학습 로드맵',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: _textColor,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '• [현재 진단] 고1 다항식 연산(상위 10%)은 우수하나, 방정식 이항 부호(중1 연계)와 나머지정리 대입에서 오답 발생\n'
                '• [처방 로드맵] 1단계: 중1 일차방정식 이항 5분 영상 & 클리닉 ➔ 2단계: 고1 나머지정리·복소수 상등 집중 풀이 ➔ 목표: 전국 상위 8% 진입',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF4A5568),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    '🔥 친구와 함께 꾸준한 학습 경쟁',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: _textColor,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _openAddFriendDialog,
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                    label: const Text(
                      '친구 연결',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const Text(
                '친구와 연속학습 불꽃(🔥)과 주간 경험치(XP)를 겨루며 매일 꾸준히 공부해요!',
                style: TextStyle(fontSize: 11.5, color: _mutedColor),
              ),
              const SizedBox(height: 12),
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _lightPurple,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _purple),
                ),
                child: Row(
                  children: [
                    const Text(
                      '👑 나 (사용자)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: _purple,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '🔥 연속 3일 · $_myTotalXp XP',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        color: _purple,
                      ),
                    ),
                  ],
                ),
              ),
              ...List.generate(_friends.length, (idx) {
                final f = _friends[idx];
                final cheered = f['cheered'] == true;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: const Color(0xFFF3F4F6),
                        child: Text(
                          '${idx + 1}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: _textColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${f['name']} · 🔥 ${f['streak']}일 연속',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '${f['badge']} · ${f['xp']} XP',
                              style: const TextStyle(
                                fontSize: 11,
                                color: _mutedColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton(
                        onPressed: cheered
                            ? null
                            : () {
                                setState(() => f['cheered'] = true);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: _purple,
                                    content: Text(
                                      '${f['name']} 님에게 오늘 공부 찌르기 알림을 보냈어요! 👋',
                                    ),
                                  ),
                                );
                              },
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          side: const BorderSide(color: _purple),
                        ),
                        child: Text(
                          cheered ? '찌르기 완료 ✓' : '👋 공부 찌르기',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _lightPurple,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Text('🤖', style: TextStyle(fontSize: 18)),
                  SizedBox(width: 6),
                  Text(
                    'AI 튜터의 맞춤 처방',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: _textColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                _isUnlocked
                    ? '이항 부호 선수개념(SKL-2-037) 보완을 완료했어요! 이제 고1 \'방정식과 부등식\' 실전 문제로 실력을 굳혀볼까요?'
                    : '최근 \'방정식과 부등식\' 단원의 이항 과정에서 부호 실수가 잦아요.\n중1·중2 이항 선수개념 보완 후 집중 훈련을 시작할까요?',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: _textColor,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _openPrerequisiteQuizSheet,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _purple,
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: _purple),
                      ),
                      child: Text(
                        _isUnlocked ? '선수개념 완료 ✓' : '이항 선수개념 1분 보완',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () =>
                          _startPrescribedTraining(unit: '방정식과 부등식'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _purple,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text(
                        '추천 훈련 시작 ▶',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFEEEEEE)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '스킬 레이더 (공통수학 1)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: _textColor,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 210,
                width: double.infinity,
                child: CustomPaint(
                  painter: PentagonRadarChartPainter(
                    values: radarValues,
                    labels: const ['다항식', '방정식', '부등식', '도형·경우', '행렬'],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFEEEEEE)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '자주 틀리는 오류 유형',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: _textColor,
                ),
              ),
              const SizedBox(height: 16),
              _buildErrorTypeBar(
                rankTitle: '1. 단순 부호/계산 실수 (#SIGN_ERROR)',
                percentText: _isUnlocked ? '30% (개선됨 ↓)' : '45%',
                value: _isUnlocked ? 0.30 : 0.45,
                color: const Color(0xFFFF6B6B),
              ),
              const SizedBox(height: 14),
              _buildErrorTypeBar(
                rankTitle: '2. 문제 조건/제한 누락 (#REMAINDER_SIGN_ERROR)',
                percentText: '30%',
                value: 0.30,
                color: const Color(0xFFF6AD55),
              ),
              const SizedBox(height: 14),
              _buildErrorTypeBar(
                rankTitle: '3. 곱셈 공식 제곱항 부호 혼동 (#SQUARE_TERM_ERROR)',
                percentText: '25%',
                value: 0.25,
                color: _purple,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryStat({required String label, required String value}) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: _purple,
          ),
        ),
        const SizedBox(height: 3),
        Text(label, style: const TextStyle(fontSize: 11, color: _mutedColor)),
      ],
    );
  }

  Widget _buildErrorTypeBar({
    required String rankTitle,
    required String percentText,
    required double value,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              rankTitle,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: _textColor,
              ),
            ),
            Text(
              percentText,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 7,
            backgroundColor: const Color(0xFFEEEEEE),
            color: color,
          ),
        ),
      ],
    );
  }
}
