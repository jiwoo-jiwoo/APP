// 피그마 시안(image_fc8b10.png, image_fc8b34.png) + 기획서(P5) 보완 사항을 100% 반영한 학습 파이프라인 화면
// [앱 제공 문제 기본 흐름]:
// 0. 문제 먼저 제시 & 풀이 환경(모눈종이 연습장 + [1순위: 📷 카메라로 풀이 촬영하기] + [2순위: ✏️ 그냥 정답 입력하기 & 제출하기])
// -> (카메라 선택 시) 1. 공책 풀이 촬영(다크 뷰파인더+가이드라인) -> 2. 이미지 확인(재촬영/다음) -> 3. UFO 스캐닝 로딩
// -> 4. 풀이 분석 결과(사진 위 인터랙티브 형광펜 핀 [1][2][?] + 번호별 상세 설명 + AI 로봇 플로팅 버튼)
// -> 5. AI 튜터 채팅(원본 풀이 보기 토글 + 수식 블록 설명 + 빠른 응답 칩 + 음성 마이크 + GS-LEAK 방어)
// -> 6. 다시 풀기(모눈종이 연습장 + 재촬영 / 그냥 정답 입력하기 / 제출하기)
// -> 7. 완료 축하 모달 카드(XP 내역 + 레벨 바 + 신규 배지 + [비슷한 변형 문제] / [다른 문제])
import 'dart:async';

import 'package:flutter/material.dart';

import '../models/practice_question.dart';
import '../services/learning_storage.dart';
import '../services/question_service.dart';

export '../models/practice_question.dart';

enum _FigmaFlowStage {
  problemSolveWorkspace, // 0. 앱 제공 문제 먼저 제시 + 문제 풀이 환경 ([카메라 촬영] -> [그냥 정답 입력])
  cameraCapture, // 1. 공책 풀이 촬영 (다크 카메라 가이드라인)
  imageConfirm, // 2. 이미지 확인 (재촬영 / 다음 ->)
  ufoLoading, // 3. 분석 로딩 ("와아앙~ AI가 풀이 과정을 꼼꼼히 읽고 있어요...")
  analysisResult, // 4. 풀이 분석 결과 (사진 위 형광펜 핀 + 번호별 상세 설명 스크롤)
  aiTutorChat, // 5. AI 튜터 대화창 (이항 원리 수식 블록 + 빠른 응답 칩 + 음성/안전필터)
  retryScratchpad, // 6. 오개념 코칭 후 다시 풀기 (모눈종이 필기 연습장 + 재촬영 / 정답 입력 / 제출하기)
}

class _HighlightPinData {
  final int number;
  final String label;
  final String shortTooltip;
  final String detailTitle;
  final String detailBody;
  final String prerequisiteTag;
  final bool isErrorPin;
  final bool isUncertainOcr;
  final Alignment photoAlignment;

  const _HighlightPinData({
    required this.number,
    required this.label,
    required this.shortTooltip,
    required this.detailTitle,
    required this.detailBody,
    required this.prerequisiteTag,
    this.isErrorPin = true,
    this.isUncertainOcr = false,
    required this.photoAlignment,
  });
}

class _ChatBubbleData {
  final bool isUser;
  final String text;
  final List<String> mathBlocks;
  final String? afterMathText;
  final bool isSafetyGuard;

  const _ChatBubbleData({
    required this.isUser,
    required this.text,
    this.mathBlocks = const [],
    this.afterMathText,
    this.isSafetyGuard = false,
  });
}

class ProblemScreen extends StatefulWidget {
  final PracticeQuestion? reviewQuestion;
  final Future<void> Function()? onReviewCompleted;
  final QuestionService questionService;
  final String topic;

  /// false(기본값): 앱이 문제를 먼저 제공하고 [카메라 촬영] / [그냥 정답 입력] 환경을 보여줌
  /// true: 하단 중앙 카메라 FAB 등에서 외부 문제집을 즉시 촬영할 때 카메라부터 시작
  final bool startWithCamera;

  const ProblemScreen({
    super.key,
    this.reviewQuestion,
    this.onReviewCompleted,
    this.questionService = const MockQuestionService(),
    this.topic = '다항식',
    this.startWithCamera = false,
  });

  @override
  State<ProblemScreen> createState() => _ProblemScreenState();
}

class _ProblemScreenState extends State<ProblemScreen> {
  static const _purple = Color(0xFF7C5CFA);
  static const _lightPurple = Color(0xFFF3EEFF);
  static const _guideOrangeRed = Color(0xFFFF5238);
  static const _errorPink = Color(0xFFFF6B6B);
  static const _textColor = Color(0xFF171717);
  static const _mutedColor = Color(0xFF777777);

  bool get _isReview => widget.reviewQuestion != null;
  final Set<String> _savedAttemptKeys = {};
  bool _reviewCompletedSaved = false;

  List<PracticeQuestion> _questions = [];
  bool _loading = true;
  String? _loadError;

  int _questionIndex = 0;
  late _FigmaFlowStage _stage;

  // 촬영 시나리오 (완벽한 풀이 바로 완료 모달 시연 vs 오개념 AI 개입 시연)
  bool _simulatePerfectFirstTry = false;
  bool _ocrUncertainConfirmed = false;

  // 분석 결과 화면 상태
  int _selectedPinNumber = 1;
  int? _expandedStepIndex = 2; // "k를 알기 위해선..." 아코디언 확장 상태
  final ScrollController _analysisScrollController = ScrollController();

  // AI 튜터 채팅 상태
  bool _showOriginalSolutionInChat = false;
  bool _voiceListening = false;
  final TextEditingController _chatInputController = TextEditingController();
  final List<_ChatBubbleData> _chatMessages = [];

  // 문제 풀이 환경 & 다시 풀기 (모눈종이 연습장 + 정답 직접 입력) 상태
  final List<List<Offset>> _scribbleStrokes = [];
  bool _isVariantMode = false;
  final TextEditingController _directAnswerController = TextEditingController();
  int? _selectedChoiceIndex;

  PracticeQuestion get _question => _questions[_questionIndex];

  @override
  void initState() {
    super.initState();
    _stage = widget.startWithCamera
        ? _FigmaFlowStage.cameraCapture
        : _FigmaFlowStage.problemSolveWorkspace;

    final reviewQuestion = widget.reviewQuestion;
    if (reviewQuestion != null) {
      _questions = [reviewQuestion];
      _loading = false;
      _initQuestionFlow(keepCameraStart: widget.startWithCamera);
    } else {
      _loadQuestions();
    }
  }

  @override
  void dispose() {
    _analysisScrollController.dispose();
    _chatInputController.dispose();
    _directAnswerController.dispose();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final questions = await widget.questionService.fetchQuestions();
      for (final q in questions) {
        q.validate();
      }
      if (!mounted) return;
      setState(() {
        _questions = List<PracticeQuestion>.unmodifiable(questions);
        _loading = false;
      });
      if (_questions.isNotEmpty) {
        _initQuestionFlow(keepCameraStart: widget.startWithCamera);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = '문제를 불러오지 못했어요.';
      });
    }
  }

  void _initQuestionFlow({
    bool asVariant = false,
    bool keepCameraStart = false,
  }) {
    setState(() {
      _stage = keepCameraStart
          ? _FigmaFlowStage.cameraCapture
          : (asVariant
                ? _FigmaFlowStage.retryScratchpad
                : _FigmaFlowStage.problemSolveWorkspace);
      _isVariantMode = asVariant;
      _selectedPinNumber = 1;
      _expandedStepIndex = 2;
      _ocrUncertainConfirmed = false;
      _showOriginalSolutionInChat = false;
      _scribbleStrokes.clear();
      _directAnswerController.clear();
      _selectedChoiceIndex = null;
      _chatMessages
        ..clear()
        ..addAll(const [
          _ChatBubbleData(isUser: true, text: '이항할 때 왜 부호가 바뀌는지 잘 이해가 안 가 😢'),
          _ChatBubbleData(
            isUser: false,
            text: '좋은 질문이에요! 이항은 사실 마법처럼 숫자가 넘어가는 게 아니라, \'양변에 같은 수를 더하거나 빼는 원리\'랍니다.\n\n예를 들어볼게요.',
            mathBlocks: ['x - 3 = 5', 'x - 3 + 3 = 5 + 3'],
            afterMathText: '그러면 왼쪽은 x만 남고, 오른쪽은 5 + 3이 되죠! 결과적으로 -3이 넘어가서 +3이 된 것처럼 보이는 거랍니다.',
          ),
        ]);
    });
  }

  List<_HighlightPinData> _pinsForCurrentQuestion() {
    return [
      _HighlightPinData(
        number: 1,
        label: '1',
        shortTooltip: '길이는 음수일 수 없어요!',
        detailTitle: '길이는 음수 일 수 없어요',
        detailBody: '점과 직선 사이의 거리 공식을 적용할 때 절댓값 기호 |ax₁ + by₁ + c| 를 누락하여 거리값이 음수로 계산되었어요.',
        prerequisiteTag: '선수개념: STP-2-014 절댓값의 성질과 거리',
        isErrorPin: true,
        photoAlignment: const Alignment(-0.08, -0.18),
      ),
      _HighlightPinData(
        number: 2,
        label: '2 · 현이란...',
        shortTooltip: '현의 정의와 피타고라스 정리 연결',
        detailTitle: '현이란 원 위의 두 점을 이은 선분이에요',
        detailBody: '원의 중심에서 현에 내린 수선은 현을 수직이등분해요. 따라서 반지름 r=5, 현의 절반 2√5를 이용하면 중심과 직선 사이의 거리 d = √(5² - (2√5)²) = √5 가 됩니다.',
        prerequisiteTag: '선수개념: 중3 원과 직선 · 피타고라스 정리',
        isErrorPin: false,
        photoAlignment: const Alignment(-0.62, -0.28),
      ),
      _HighlightPinData(
        number: 3,
        label: '3',
        shortTooltip: '원의 중심과 직선 거리 공식 확인',
        detailTitle: 'k를 알기 위해선 원의 중심과 직선의 거리를 알아야 해요',
        detailBody: '원의 중심 (1, 1)과 직선 2x + y - k = 0 사이의 거리 d = |2(1) + 1 - k| / √(2² + 1²) = |3 - k| / √5 입니다. 이 값이 √5와 같아야 하므로 |3 - k| = 5 에서 k를 구할 수 있어요!',
        prerequisiteTag: '핵심개념: 고1 원과 직선의 위치 관계 (STP-3)',
        isErrorPin: true,
        photoAlignment: const Alignment(0.32, 0.05),
      ),
      _HighlightPinData(
        number: 4,
        label: '?',
        shortTooltip: '손글씨 부호 확인 (ADR-03)',
        detailTitle: '단순계산 실수 및 이항 부호 점검 (#부호오류)',
        detailBody: '|3 - k| = 5 를 풀 때 3 - k = 5 또는 3 - k = -5 로 나누어 이항해야 해요. 마지막 줄의 "5, -5" 손글씨가 맞는지 확인해 주세요!',
        prerequisiteTag: '선수개념: SKL-2-037 일차방정식에서 이항하기',
        isErrorPin: true,
        isUncertainOcr: true,
        photoAlignment: const Alignment(-0.15, 0.58),
      ),
    ];
  }

  /// 이미지 확인에서 [다음 ->] 클릭 시 UFO 로딩 화면을 거쳐 결과 화면 또는 완료 모달로 이동
  Future<void> _startUfoAnalysis() async {
    setState(() {
      _stage = _FigmaFlowStage.ufoLoading;
    });

    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    if (_simulatePerfectFirstTry) {
      setState(() {
        _stage = _FigmaFlowStage.imageConfirm;
      });
      await _recordCurrentAttempt(isCorrect: true);
      if (!mounted) return;
      _showCompletionRewardModal(isRetrySuccess: false);
    } else {
      await _recordCurrentAttempt(isCorrect: false);
      if (!mounted) return;
      setState(() {
        _stage = _FigmaFlowStage.analysisResult;
      });
    }
  }

  /// AI 튜터 채팅 전송 (정답 직접 노출 차단 GS-LEAK 포함)
  void _sendChatMessage(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return;
    _chatInputController.clear();

    final lower = text.toLowerCase();
    final isLeakAttempt =
        lower.contains('정답') ||
        lower.contains('답만') ||
        lower.contains('답 알려') ||
        lower.contains('선생님이');

    setState(() {
      _chatMessages.add(_ChatBubbleData(isUser: true, text: text));

      if (isLeakAttempt) {
        _chatMessages.add(
          const _ChatBubbleData(
            isUser: false,
            isSafetyGuard: true,
            text: '🔒 [정답 노출 0% 가드 작동]\n최종 정답 숫자를 바로 알려주면 스스로 깨닫는 기회를 놓치게 돼요! 대신 마지막 등식 |3 - k| = 5 에서 3 - k 가 될 수 있는 두 수를 먼저 적어볼까요?',
          ),
        );
      } else if (text.contains('예시 문제') || text.contains('비슷한')) {
        _chatMessages.add(
          const _ChatBubbleData(
            isUser: false,
            text: '좋아요! 같은 원리의 미니 예시 문제를 하나 볼까요?\n\n만약 |x - 2| = 4 라면, 절댓값 안의 (x - 2)는 +4 또는 -4가 될 수 있어요.',
            mathBlocks: ['x - 2 = 4  또는  x - 2 = -4', 'x = 6  또는  x = -2'],
            afterMathText:
                '양변에 +2를 똑같이 더해준 결과예요! 이제 원래 문제의 |3 - k| = 5 도 다시 풀어볼까요?',
          ),
        );
      } else if (text.contains('이해했어')) {
        _chatMessages.add(
          const _ChatBubbleData(
            isUser: false,
            text: '멋져요! 🎉 양변에 같은 수를 더하고 빼는 이항의 원리를 완벽히 잡았네요. 이제 오른쪽 아래 [다시 풀기]로 가서 직접 마무리해 볼까요?',
          ),
        );
      } else {
        _chatMessages.add(
          const _ChatBubbleData(
            isUser: false,
            text: '중심 (1, 1)에서 직선까지의 거리 공식에 대입한 뒤, 양변에 √5를 곱해 분모를 먼저 없애보세요!',
            mathBlocks: ['|3 - k| / √5 = √5', '|3 - k| = 5'],
            afterMathText: '여기서 k의 값 두 개를 구하면 정답에 도달할 수 있어요!',
          ),
        );
      }
    });
  }

  /// 문제를 풀 때마다 즉시 SharedPreferences(LearningStorage)에 영구 저장합니다.
  /// (1문제만 풀고 뒤로가기를 누르거나 앱을 완전히 종료해도 연속학습·경험치·퀘스트·오답노트에 즉시 반영됨)
  Future<void> _recordCurrentAttempt({required bool isCorrect}) async {
    if (_isReview) {
      if (isCorrect && !_reviewCompletedSaved) {
        _reviewCompletedSaved = true;
        try {
          if (widget.onReviewCompleted != null) {
            await widget.onReviewCompleted!();
          }
        } catch (_) {}
      }
      return;
    }

    final attemptKey = "$_questionIndex:$isCorrect:$_isVariantMode";
    if (_savedAttemptKeys.contains(attemptKey)) return;
    _savedAttemptKeys.add(attemptKey);

    final typed = _directAnswerController.text.trim();
    final answerMap = <String, dynamic>{
      ..._question.toJson(),
      'questionNumber': _questionIndex + 1,
      'selectedIndex': _question.isShortAnswer
          ? null
          : (isCorrect ? _question.correctIndex : _selectedChoiceIndex),
      'selectedAnswer': isCorrect
          ? _question.correctAnswer
          : (typed.isNotEmpty ? typed : '5, -5'),
      'isCorrect': isCorrect,
      'answeredAt': DateTime.now().toUtc().toIso8601String(),
      'firstErrorStep': 1,
      'misconceptionCode': 'MIS-2-001 (#이항 부호 오류)',
    };

    try {
      await LearningStorage.saveSession(
        sessionId: LearningStorage.createSessionId(),
        answers: [answerMap],
        correctCount: isCorrect ? 1 : 0,
        topic: widget.topic,
      );
    } catch (_) {}
  }

  /// 그냥 정답 입력 후 [제출하기] 클릭 시 처리
  Future<void> _handleDirectSubmit({required bool isRetryStage}) async {
    final typedAnswer = _directAnswerController.text.trim();
    final hasInput = typedAnswer.isNotEmpty || _selectedChoiceIndex != null;

    // 아직 답안을 입력하지 않고 [제출하기]를 누른 경우, 먼저 정답 입력 시트를 열어줌
    if (!hasInput) {
      await _openAnswerInputDialog(
        autoSubmitAfterConfirm: true,
        isRetryStage: isRetryStage,
      );
      return;
    }

    // 입력한 답안이 실제 정답과 일치하는지 엄격하게 판정 (처음 풀기·다시 풀기 모두 동일하게 실제 정답만 통과)
    final normalizedTyped = typedAnswer
        .replaceAll(' ', '')
        .replaceAll('−', '-')
        .replaceAll('－', '-');
    final normalizedCorrect = _question.correctAnswer
        .replaceAll(' ', '')
        .replaceAll('−', '-')
        .replaceAll('－', '-');

    final bool isCorrect;
    if (_isVariantMode) {
      // 쌍둥이 변형 문제(|5 - k| = 5 -> k = 0 또는 10) 정답 판정
      isCorrect =
          normalizedTyped == '0,10' ||
          normalizedTyped == '10,0' ||
          normalizedTyped == normalizedCorrect;
    } else if (_question.isShortAnswer) {
      // 주관식·단답형: 숫자 동치 비교 또는 정답 문자열 정확히 일치해야만 정답
      isCorrect =
          _question.matchesNumericAnswer(typedAnswer) ||
          (normalizedTyped.isNotEmpty && normalizedTyped == normalizedCorrect);
    } else {
      // 객관식: 텍스트를 직접 입력했다면 입력한 텍스트가 정답 보기(또는 정답 번호)와 정확히 일치해야 함
      if (normalizedTyped.isNotEmpty) {
        final correctNum = '${_question.correctIndex + 1}';
        isCorrect =
            normalizedTyped == normalizedCorrect ||
            normalizedTyped == correctNum ||
            normalizedTyped == '$correctNum번';
      } else {
        isCorrect =
            _selectedChoiceIndex != null &&
            _selectedChoiceIndex == _question.correctIndex;
      }
    }

    if (isCorrect) {
      await _showCompletionRewardModal(isRetrySuccess: isRetryStage);
      return;
    }

    // 오답을 직접 입력한 경우에도 즉시 오답 기록(+5 XP 및 오답노트/오늘학습)을 저장
    await _recordCurrentAttempt(isCorrect: false);
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded, color: _purple),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '아쉬워요! 풀이 과정을 점검해 볼까요?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          content: Text(
            '입력한 답안(${typedAnswer.isNotEmpty ? typedAnswer : "${_selectedChoiceIndex! + 1}번"})이 정답과 달라요.\n\n공책에 푼 풀이 과정을 카메라로 촬영하면 AI가 어느 줄에서 실수가 있었는지 짚어줄게요!',
            style: const TextStyle(fontSize: 13.5, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                setState(() {
                  _stage = _FigmaFlowStage.analysisResult;
                });
              },
              child: const Text('AI 분석 예시 바로보기'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                setState(() {
                  _simulatePerfectFirstTry = false;
                  _stage = _FigmaFlowStage.cameraCapture;
                });
              },
              style: FilledButton.styleFrom(backgroundColor: _purple),
              icon: const Icon(Icons.camera_alt_rounded, size: 18),
              label: const Text('공책 풀이 촬영하기'),
            ),
          ],
        );
      },
    );
  }

  /// 피그마 시안 1-4 & 2-5: 문제 풀이 완료 / 학습 완료 축하 모달 카드 (실제 누적 XP·레벨 실시간 연동)
  Future<void> _showCompletionRewardModal({
    required bool isRetrySuccess,
  }) async {
    await _recordCurrentAttempt(isCorrect: true);

    ExperienceProgress exp;
    try {
      exp = await LearningStorage.getExperienceProgress();
    } catch (_) {
      exp = const ExperienceProgress(0);
    }
    if (!mounted) return;

    final firstRowLabel = _isReview
        ? '오답 복습 완료'
        : (isRetrySuccess ? '첫 풀이 참여 경험치' : '기본 문제 풀이');
    final firstRowXp = '+ 5 XP';
    final secondRowLabel = _isReview
        ? '복습 완벽 마스터'
        : (isRetrySuccess ? '오개념 극복 재해결 (기본5+정답5)' : '정답 맞히기 보너스');
    final secondRowXp = _isReview
        ? '+ 0 XP'
        : (isRetrySuccess ? '+ 10 XP' : '+ 5 XP');
    final totalEarnedXpText = _isReview
        ? '+ 5 XP'
        : (isRetrySuccess ? '+ 15 XP' : '+ 10 XP');

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0xB3000000),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🎉', style: TextStyle(fontSize: 44)),
                const SizedBox(height: 12),
                Text(
                  isRetrySuccess ? '훌륭한 풀이입니다!' : '완벽한 풀이입니다!',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: _textColor,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '어려운 문제였는데 끝까지 해냈어요.',
                  style: TextStyle(fontSize: 13, color: _mutedColor),
                ),
                const SizedBox(height: 20),

                // 연보라 경험치 박스 (실제 LearningStorage 지급량과 100% 일치)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: _lightPurple,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            firstRowLabel,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF555555),
                            ),
                          ),
                          Text(
                            firstRowXp,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF555555),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            secondRowLabel,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF555555),
                            ),
                          ),
                          Text(
                            secondRowXp,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF555555),
                            ),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Divider(height: 1),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '총 획득 경험치',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: _purple,
                            ),
                          ),
                          Text(
                            totalEarnedXpText,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: _purple,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 실시간 레벨 게이지 바 (100 XP당 1레벨업 · LearningStorage 실제 데이터 연동)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Lv.${exp.level} 수학 탐험가',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _textColor,
                      ),
                    ),
                    Text(
                      '${exp.currentLevelXp} / ${ExperienceProgress.xpPerLevel} XP (누적 ${exp.totalXp} XP)',
                      style: const TextStyle(fontSize: 12, color: _mutedColor),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: exp.progress.clamp(0.0, 1.0),
                    minHeight: 7,
                    backgroundColor: const Color(0xFFEEEEEE),
                    color: _purple,
                  ),
                ),
                const SizedBox(height: 14),

                // 신규 배지 & 오늘의 퀘스트(골드 보상) 안내 카드
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F7F7),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Text('🏅', style: TextStyle(fontSize: 20)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isRetrySuccess
                                  ? '신규 배지: 포기하지 않는 도전자'
                                  : '오늘 학습 기록 저장 완료!',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: _textColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _isReview
                                  ? '홈 > [오늘의 퀘스트]에서 오답 복습 보상(+50 G)을 수령하세요!'
                                  : '연속 학습이 기록되었어요! 홈 > [오늘의 퀘스트]에서 +100 G를 받으세요.',
                              style: const TextStyle(
                                fontSize: 11,
                                color: _mutedColor,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 하단 버튼: 재풀이 완료 시 [비슷한 변형 문제] | [다른 문제], 첫 풀이 완료 시 [다음 맞춤 문제 풀기 ▶]
                if (isRetrySuccess)
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            Navigator.of(dialogContext).pop();
                            _initQuestionFlow(asVariant: true);
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFE2E2E2),
                            foregroundColor: _textColor,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            '비슷한 변형 문제',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () async {
                            Navigator.of(dialogContext).pop();
                            await _finishOrMoveNextQuestion();
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFE2E2E2),
                            foregroundColor: _textColor,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            '다른 문제',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.of(dialogContext).pop();
                        await _finishOrMoveNextQuestion();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _purple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        '다음 맞춤 문제 풀기 ▶',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _finishOrMoveNextQuestion() async {
    if (_isReview) {
      if (!mounted) return;
      Navigator.of(context).pop();
      return;
    }

    if (_questionIndex < _questions.length - 1) {
      setState(() {
        _questionIndex++;
      });
      // 다음 문제로 넘어갈 때도 문제를 먼저 보여주고 풀이 환경 제공!
      _initQuestionFlow(keepCameraStart: false);
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: _purple)),
      );
    }

    if (_loadError != null || _questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.topic)),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_loadError ?? '준비된 문제가 없습니다.'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('돌아가기'),
              ),
            ],
          ),
        ),
      );
    }

    switch (_stage) {
      case _FigmaFlowStage.problemSolveWorkspace:
        return _buildProblemWorkspaceScreen(isRetryStage: false);
      case _FigmaFlowStage.cameraCapture:
        return _buildCameraCaptureScreen();
      case _FigmaFlowStage.imageConfirm:
        return _buildImageConfirmScreen();
      case _FigmaFlowStage.ufoLoading:
        return _buildUfoLoadingScreen();
      case _FigmaFlowStage.analysisResult:
        return _buildAnalysisResultScreen();
      case _FigmaFlowStage.aiTutorChat:
        return _buildAiTutorChatScreen();
      case _FigmaFlowStage.retryScratchpad:
        return _buildProblemWorkspaceScreen(isRetryStage: true);
    }
  }

  // =========================================================================
  // 0 & 6. 문제 먼저 제시 + 문제 풀이 환경 (모눈종이 연습장 + [1순위: 카메라 촬영] + [2순위: 그냥 정답 입력])
  // =========================================================================
  Widget _buildProblemWorkspaceScreen({required bool isRetryStage}) {
    final hasEnteredAnswer =
        _directAnswerController.text.trim().isNotEmpty ||
        _selectedChoiceIndex != null;
    final enteredLabel = _directAnswerController.text.trim().isNotEmpty
        ? '입력한 답: ${_directAnswerController.text.trim()}'
        : (_selectedChoiceIndex != null
              ? '선택한 답: ${_selectedChoiceIndex! + 1}번 (${_question.choices[_selectedChoiceIndex!]})'
              : '그냥 정답 입력하기');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            if (isRetryStage) {
              setState(() {
                _stage = _FigmaFlowStage.analysisResult;
              });
            } else {
              Navigator.of(context).pop();
            }
          },
          icon: const Icon(Icons.chevron_left_rounded, size: 28),
        ),
        titleSpacing: 0,
        title: Text(
          isRetryStage
              ? (_isVariantMode ? '비슷한 변형 문제 풀기' : '다시 풀기')
              : (_isReview
                    ? '오답 정복 문제 풀기'
                    : '${widget.topic} (${_questionIndex + 1}/${_questions.length})'),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1) 상단 문제 카드 (우리가 제공하는 문제를 먼저 명확하게 제시)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9F8FF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE6DFFF)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _lightPurple,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _isVariantMode
                                    ? '✨ 숫자·조건이 바뀐 쌍둥이 변형 문항'
                                    : (isRetryStage
                                          ? '🔄 오개념 코칭 후 재도전'
                                          : '📘 STEPi 맞춤 제공 문제 · ${_question.title}'),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: _purple,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              _question.isShortAnswer ? '단답·서술형' : '객관식',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _mutedColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _isVariantMode
                              ? '반지름이 5이고 (2, 1)을 중심으로 하는 원이 2x + y - k = 0에 의하여 잘린 현의 길이가 4√5일 때, 상수 k의 값을 구하시오.\n\n[연계 단원 문제] ${_question.question}'
                              : _question.question,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: _textColor,
                            height: 1.48,
                          ),
                        ),
                        if (!_question.isShortAnswer &&
                            _question.choices.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: List.generate(_question.choices.length, (
                              idx,
                            ) {
                              final selected = _selectedChoiceIndex == idx;
                              return ChoiceChip(
                                label: Text(
                                  '${idx + 1}) ${_question.choices[idx]}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: selected
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    color: selected ? _purple : _textColor,
                                  ),
                                ),
                                selected: selected,
                                selectedColor: _lightPurple,
                                backgroundColor: Colors.white,
                                onSelected: (_) {
                                  setState(() {
                                    _selectedChoiceIndex = idx;
                                    _directAnswerController.text =
                                        _question.choices[idx];
                                  });
                                },
                              );
                            }),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 2) 중앙: 문제를 풀 수 있는 모눈종이 필기 연습장 환경 (직접 손글씨/마우스 필기 가능)
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE0E0E0)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: GestureDetector(
                              onPanStart: (details) {
                                setState(() {
                                  _scribbleStrokes.add([details.localPosition]);
                                });
                              },
                              onPanUpdate: (details) {
                                setState(() {
                                  _scribbleStrokes.last.add(
                                    details.localPosition,
                                  );
                                });
                              },
                              child: CustomPaint(
                                painter: _GridScratchpadPainter(
                                  strokes: _scribbleStrokes,
                                ),
                              ),
                            ),
                          ),
                          if (_scribbleStrokes.isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 24),
                                child: Text(
                                  '모눈종이 연습장에 자유롭게 풀어보거나,\n공책에 푼 뒤 아래 [카메라 촬영] 또는 [그냥 정답 입력하기]를 선택하세요 ✍️',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF999999),
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          Positioned(
                            top: 10,
                            right: 10,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_scribbleStrokes.isNotEmpty)
                                  IconButton(
                                    tooltip: '연습장 필기 지우기',
                                    onPressed: () {
                                      setState(() => _scribbleStrokes.clear());
                                    },
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      size: 20,
                                      color: _mutedColor,
                                    ),
                                  ),
                                const Padding(
                                  padding: EdgeInsets.all(6),
                                  child: Icon(
                                    Icons.edit_note_rounded,
                                    size: 22,
                                    color: _textColor,
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

                  // 3) 하단 액션 1순위: [📷 카메라로 공책 풀이 촬영하기]
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          // 처음 촬영할 때는 오개념 분석 플로우 시연, 다시 풀기 후 재촬영할 때는 정답 완료 플로우 시연
                          _simulatePerfectFirstTry = isRetryStage;
                          _stage = _FigmaFlowStage.cameraCapture;
                        });
                      },
                      icon: const Icon(Icons.camera_alt_rounded, size: 20),
                      label: Text(
                        isRetryStage
                            ? '공책 풀이 다시 촬영하기 (AI 과정 분석)'
                            : '카메라로 공책 풀이 촬영하기 (AI 과정 분석)',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _purple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 4) 하단 액션 2순위: [✏️ 그냥 정답 입력하기] | [제출하기]
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: OutlinedButton.icon(
                          onPressed: () => _openAnswerInputDialog(
                            autoSubmitAfterConfirm: false,
                            isRetryStage: isRetryStage,
                          ),
                          icon: Icon(
                            hasEnteredAnswer
                                ? Icons.check_circle_rounded
                                : Icons.keyboard_alt_outlined,
                            size: 18,
                            color: hasEnteredAnswer ? _purple : _textColor,
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _textColor,
                            side: BorderSide(
                              color: hasEnteredAnswer
                                  ? _purple
                                  : const Color(0xFFDDDDDD),
                              width: hasEnteredAnswer ? 1.5 : 1.0,
                            ),
                            padding: const EdgeInsets.symmetric(
                              vertical: 15,
                              horizontal: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          label: Text(
                            enteredLabel,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: hasEnteredAnswer ? _purple : _textColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () =>
                              _handleDirectSubmit(isRetryStage: isRetryStage),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _textColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            '제출하기',
                            style: TextStyle(
                              fontSize: 14,
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
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // 1. 공책 풀이 촬영 화면 (피그마 1-1: 다크 카메라 + 주황빨강 브래킷 + 중앙 점선)
  // =========================================================================
  Widget _buildCameraCaptureScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF141414),
      appBar: AppBar(
        backgroundColor: const Color(0xFF757575),
        foregroundColor: Colors.black,
        leading: IconButton(
          onPressed: () {
            // 앱 제공 문제에서 카메라로 들어온 경우 문제 풀이 화면으로 복귀
            if (!widget.startWithCamera) {
              setState(() {
                _stage = _FigmaFlowStage.problemSolveWorkspace;
              });
            } else {
              Navigator.of(context).pop();
            }
          },
          icon: const Icon(Icons.chevron_left_rounded, size: 28),
        ),
        title: const Text(
          '공책 풀이 촬영',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        actions: [
          // 시연 시 '오류 발견 플로우' vs '완벽 풀이 즉시 완료 모달' 전환 토글
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: FilterChip(
                label: Text(
                  _simulatePerfectFirstTry ? '시연: 한번에 정답' : '시연: 오개념 발견',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                selected: _simulatePerfectFirstTry,
                onSelected: (v) => setState(() => _simulatePerfectFirstTry = v),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Column(
              children: [
                const Spacer(),
                // 중앙 가이드라인 박스 (주황/빨강 모서리 브래킷 + 가로 점선)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: AspectRatio(
                    aspectRatio: 1.25,
                    child: CustomPaint(
                      painter: _CameraGuideFramePainter(
                        bracketColor: _guideOrangeRed,
                      ),
                      child: Container(
                        color: const Color(0xFF333333),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Text(
                              '[상단] 문제 영역\n${_question.question}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '[하단] 내가 푼 손글씨 수식 영역\n(한 문제와 풀이가 모두 보이도록 맞춰주세요)',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                const Text(
                  '가이드라인 안에 수식을 맞춰주세요',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 28),
                // 하단 원형 셔터 버튼
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 22),
                  color: Colors.black,
                  child: Center(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _stage = _FigmaFlowStage.imageConfirm;
                        });
                      },
                      child: Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          color: const Color(0xFF666666),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF444444),
                            width: 4,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // 2. 이미지 확인 화면 (피그마 1-2: 촬영된 공책 이미지 + 하단 [재촬영] / [다음 ->])
  // =========================================================================
  Widget _buildImageConfirmScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Column(
              children: [
                const SizedBox(height: 24),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: _buildSimulatedNotebookPhoto(showPins: false),
                  ),
                ),
                Container(
                  height: 84,
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  color: Colors.black,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _stage = _FigmaFlowStage.cameraCapture;
                          });
                        },
                        child: const Text(
                          '재촬영',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _startUfoAnalysis,
                        child: const Text(
                          '다음 →',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
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
      ),
    );
  }

  // =========================================================================
  // 3. 분석 로딩 화면 (피그마 1-3: "와아앙~" UFO 스캐닝 일러스트 + 안내 문구)
  // =========================================================================
  Widget _buildUfoLoadingScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 귀여운 UFO 스캐닝 일러스트 표현
                SizedBox(
                  width: 200,
                  height: 170,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        top: 8,
                        right: 18,
                        child: Transform.rotate(
                          angle: 0.25,
                          child: const Icon(
                            Icons.wb_twilight_rounded,
                            size: 64,
                            color: _textColor,
                          ),
                        ),
                      ),
                      const Positioned(
                        left: 20,
                        top: 48,
                        child: Text(
                          '와아\n  앙~',
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w400,
                            height: 1.15,
                            color: _textColor,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 12,
                        child: SizedBox(
                          width: 120,
                          child: LinearProgressIndicator(
                            backgroundColor: _lightPurple,
                            color: _purple,
                            minHeight: 4,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'AI가 사용자님의 풀이 과정을 꼼꼼히 읽고 있어요...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _textColor,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '손글씨 수식 OCR · SymPy 단계별 동치 검증 · 오개념 매핑 중',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: _mutedColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // 4. 풀이 분석 결과 & 더 자세한 설명 화면 (피그마 2-1, 2-2 통합 스크롤 뷰)
  // =========================================================================
  Widget _buildAnalysisResultScreen() {
    final pins = _pinsForCurrentQuestion();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            setState(() {
              _stage = _FigmaFlowStage.problemSolveWorkspace;
            });
          },
          icon: const Icon(Icons.chevron_left_rounded, size: 28),
        ),
        titleSpacing: 0,
        title: const Text(
          '풀이 분석 결과',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                // 상단 안내 문구: "ⓘ 형광펜으로 색칠된 부분을 누르면 필요한 개념을 알 수 있어요!"
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  color: Colors.white,
                  child: const Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: _mutedColor,
                      ),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '형광펜으로 색칠된 부분을 누르면 필요한 개념을 알 수 있어요!',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _textColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 스크롤 영역: 공책 사진(핀 오버레이) + 더 자세한 설명 번호별 리스트
                Expanded(
                  child: ListView(
                    controller: _analysisScrollController,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                    children: [
                      // 인터랙티브 공책 사진 + 형광펜 핀 오버레이
                      SizedBox(
                        height: 360,
                        child: _buildSimulatedNotebookPhoto(
                          showPins: true,
                          pins: pins,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // "🤖 더 자세한 설명 듣기" 헤더
                      Center(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            _analysisScrollController.animateTo(
                              260,
                              duration: const Duration(milliseconds: 350),
                              curve: Curves.easeOut,
                            );
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('🤖', style: TextStyle(fontSize: 16)),
                                SizedBox(width: 6),
                                Text(
                                  '더 자세한 설명 듣기',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: _textColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ADR-03 보완: 인식 불확실 줄 확인 배너
                      if (!_ocrUncertainConfirmed)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFFBBF24)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.help_outline_rounded,
                                color: Color(0xFFD97706),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  '마지막 줄 손글씨 "5, -5"가 맞나요? 인식 불확실 줄은 바로 오답 처리하지 않아요 (ADR-03).',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  setState(() => _ocrUncertainConfirmed = true);
                                },
                                child: const Text('맞아요'),
                              ),
                            ],
                          ),
                        ),

                      // 피그마 2-2: 번호별 단계 설명 아코디언 리스트 + 우측 하단 AI 튜터 로봇 버튼
                      Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAFAFA),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFFEEEEEE),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: List.generate(pins.length, (idx) {
                                final pin = pins[idx];
                                final isExpanded = _expandedStepIndex == idx;

                                return InkWell(
                                  onTap: () {
                                    setState(() {
                                      _expandedStepIndex = isExpanded
                                          ? null
                                          : idx;
                                      _selectedPinNumber = pin.number;
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              width: 22,
                                              height: 22,
                                              decoration: BoxDecoration(
                                                color: pin.isErrorPin
                                                    ? _purple
                                                    : const Color(0xFF3DB366),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Center(
                                                child: Text(
                                                  '${pin.number}',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                pin.detailTitle,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w800,
                                                  color: _textColor,
                                                ),
                                              ),
                                            ),
                                            Icon(
                                              isExpanded
                                                  ? Icons.keyboard_arrow_up
                                                  : Icons.keyboard_arrow_down,
                                              size: 20,
                                              color: _mutedColor,
                                            ),
                                          ],
                                        ),
                                        if (isExpanded) ...[
                                          const SizedBox(height: 8),
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              left: 34,
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  pin.detailBody,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    color: Color(0xFF4A5568),
                                                    height: 1.5,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 4,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: _lightPurple,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    '🔗 ${pin.prerequisiteTag}',
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: _purple,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),

                          // 피그마 2-2 우측 하단: 귀여운 AI 로봇 아바타 플로팅 버튼 -> AI 튜터 채팅 진입
                          Positioned(
                            right: 12,
                            bottom: 12,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _stage = _FigmaFlowStage.aiTutorChat;
                                });
                              },
                              child: Tooltip(
                                message: 'AI 튜터에게 질문하기',
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: _purple,
                                      width: 1.5,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x22000000),
                                        blurRadius: 8,
                                        offset: Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '🤖',
                                        style: TextStyle(fontSize: 20),
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'AI 튜터 질문',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: _purple,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 하단 고정 CTA 버튼: "다시 한번 풀어볼까요?"
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _stage = _FigmaFlowStage.retryScratchpad;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _purple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      child: const Text(
                        '다시 한번 풀어볼까요?',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 공책 손글씨 풀이 시뮬레이션 뷰 + 형광펜 핀 오버레이 (피그마 2-1, 2-2)
  Widget _buildSimulatedNotebookPhoto({
    required bool showPins,
    List<_HighlightPinData> pins = const [],
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFDCDCDC),
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 실제 공책 시험지/노트 질감 및 손글씨 수식 레이아웃
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '11',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF222222),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '원 (x-1)²+(y-1)²=25가 직선 2x+y-k=0에 의하여 잘린 현의 길이가 4√5일 때, 상수 k의 값을 모두 구하시오.\n(${_question.title}: ${_question.question})',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF222222),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 18),
                // 학생 손글씨 수식 시뮬레이션
                Transform.rotate(
                  angle: -0.12,
                  child: const Padding(
                    padding: EdgeInsets.only(left: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '√(5² - (2√5)²) = √(25 - 20) = √5',
                          style: TextStyle(
                            fontSize: 17,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF4A4A4A),
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'd = (2·1 + 1 - k) / √(2² + 1²) = -√5',
                          style: TextStyle(
                            fontSize: 17,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF4A4A4A),
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          '∴ k = 5, -5',
                          style: TextStyle(
                            fontSize: 20,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF4A4A4A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 피그마 2-1: 형광펜 핀 및 말풍선 툴팁 오버레이
          if (showPins)
            ...pins.map((pin) {
              final isSelected = _selectedPinNumber == pin.number;
              final pinColor = pin.isUncertainOcr
                  ? const Color(0xFFD97706)
                  : pin.isErrorPin
                  ? _errorPink
                  : _purple;

              return Align(
                alignment: pin.photoAlignment,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedPinNumber = pin.number;
                      _expandedStepIndex = pin.number - 1;
                    });
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: pinColor.withAlpha(215),
                          borderRadius: BorderRadius.circular(12),
                          border: isSelected
                              ? Border.all(color: Colors.white, width: 2)
                              : null,
                        ),
                        child: Text(
                          pin.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: _purple,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            pin.shortTooltip,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  // =========================================================================
  // 5. AI 튜터 채팅 화면 (피그마 2-3: 원본 풀이 토글 + 수식 블록 + 빠른 응답 칩)
  // =========================================================================
  Widget _buildAiTutorChatScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            setState(() {
              _stage = _FigmaFlowStage.analysisResult;
            });
          },
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        titleSpacing: 0,
        title: const Row(
          children: [
            Text(
              'AI 튜터',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            SizedBox(width: 6),
            CircleAvatar(radius: 4, backgroundColor: Color(0xFF3DB366)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _stage = _FigmaFlowStage.retryScratchpad;
              });
            },
            child: const Text(
              '다시 풀기 ▶',
              style: TextStyle(fontWeight: FontWeight.w800, color: _purple),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                // 상단 "쎈 공통수학1 - 425번 질문 중 / 터치해서 원본 풀이 보기 ▼" 아코디언
                InkWell(
                  onTap: () {
                    setState(() {
                      _showOriginalSolutionInChat =
                          !_showOriginalSolutionInChat;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    color: Colors.white,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _lightPurple,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.menu_book_rounded,
                                size: 18,
                                color: _purple,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '쎈 공통수학1 - 425번 (${_question.title}) 질문 중',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const Text(
                                    '터치해서 원본 풀이 보기',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: _mutedColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              _showOriginalSolutionInChat
                                  ? Icons.arrow_drop_up_rounded
                                  : Icons.arrow_drop_down_rounded,
                              color: _mutedColor,
                            ),
                          ],
                        ),
                        if (_showOriginalSolutionInChat) ...[
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 180,
                            child: _buildSimulatedNotebookPhoto(
                              showPins: false,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),

                // 채팅 메시지 리스트
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(18),
                    itemCount: _chatMessages.length,
                    itemBuilder: (context, idx) {
                      final msg = _chatMessages[idx];
                      if (msg.isUser) {
                        return Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 16, left: 48),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: const BoxDecoration(
                              color: _purple,
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(18),
                                topRight: Radius.circular(18),
                                bottomLeft: Radius.circular(18),
                                bottomRight: Radius.circular(4),
                              ),
                            ),
                            child: Text(
                              msg.text,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                height: 1.45,
                              ),
                            ),
                          ),
                        );
                      }

                      // AI 튜터 말풍선 (수식 블록 포함)
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 18, right: 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Text('🤖', style: TextStyle(fontSize: 16)),
                                SizedBox(width: 6),
                                Text(
                                  'AI 튜터',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: _mutedColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: msg.isSafetyGuard
                                    ? const Color(0xFFFFF5F5)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: msg.isSafetyGuard
                                      ? _errorPink
                                      : const Color(0xFFEEEEEE),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    msg.text,
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      height: 1.55,
                                      color: _textColor,
                                    ),
                                  ),
                                  for (final formula in msg.mathBlocks) ...[
                                    const SizedBox(height: 10),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                        horizontal: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8F9FA),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: const Color(0xFFE2E8F0),
                                        ),
                                      ),
                                      child: Text(
                                        formula,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontFamily: 'monospace',
                                          fontWeight: FontWeight.w800,
                                          color: _textColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (msg.afterMathText != null) ...[
                                    const SizedBox(height: 10),
                                    Text(
                                      msg.afterMathText!,
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        height: 1.55,
                                        color: _textColor,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // 피그마 2-3 하단 빠른 응답 칩 ("💡 아! 이제 이해했어", "🤩 비슷한 예시 문제 하나 내줄래?", "🔒 답만 알려줘")
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      _buildQuickReplyChip('💡 아! 이제 이해했어'),
                      const SizedBox(width: 8),
                      _buildQuickReplyChip('🤩 비슷한 예시 문제 하나 내줄래?'),
                      const SizedBox(width: 8),
                      _buildQuickReplyChip('🔒 그냥 정답이 뭔지만 알려줘'),
                    ],
                  ),
                ),

                // 하단 입력 바 (카메라 + 마이크 음성 + 텍스트 필드 + 보라색 전송 버튼)
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  color: Colors.white,
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _stage = _FigmaFlowStage.cameraCapture;
                          });
                        },
                        icon: const Icon(
                          Icons.camera_alt_rounded,
                          color: _mutedColor,
                        ),
                      ),
                      IconButton(
                        tooltip: '실시간 음성 질문 (STT/TTS)',
                        onPressed: () async {
                          setState(() => _voiceListening = true);
                          await Future<void>.delayed(
                            const Duration(milliseconds: 900),
                          );
                          if (!mounted) return;
                          setState(() => _voiceListening = false);
                          _sendChatMessage('비슷한 예시 문제 하나 내줄래?');
                        },
                        icon: Icon(
                          _voiceListening
                              ? Icons.graphic_eq_rounded
                              : Icons.mic_none_rounded,
                          color: _voiceListening ? _errorPink : _purple,
                        ),
                      ),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: TextField(
                            controller: _chatInputController,
                            onSubmitted: _sendChatMessage,
                            decoration: InputDecoration(
                              hintText: _voiceListening
                                  ? '음성 듣는 중...'
                                  : '궁금한 점을 자유롭게 물어보세요',
                              hintStyle: const TextStyle(fontSize: 13),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () =>
                            _sendChatMessage(_chatInputController.text),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: const BoxDecoration(
                            color: _purple,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_upward_rounded,
                            color: Colors.white,
                            size: 20,
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
      ),
    );
  }

  Widget _buildQuickReplyChip(String label) {
    return ActionChip(
      label: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      onPressed: () => _sendChatMessage(label),
    );
  }

  /// [그냥 정답 입력하기] 바텀시트 (객관식 보기 선택 + 주관식/단답형 텍스트 입력 모두 지원)
  Future<void> _openAnswerInputDialog({
    required bool autoSubmitAfterConfirm,
    required bool isRetryStage,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '정답 직접 입력하기',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          // 시연 시 1초 만에 정답을 채울 수 있는 빠른 입력 도우미
                          _directAnswerController.text =
                              _question.correctAnswer;
                          if (!_question.isShortAnswer) {
                            _selectedChoiceIndex = _question.correctIndex;
                          }
                          setModalState(() {});
                          setState(() {});
                        },
                        child: Text(
                          '예시 정답(${_question.correctAnswer}) 자동입력',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _purple,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (!_question.isShortAnswer &&
                      _question.choices.isNotEmpty) ...[
                    const Text(
                      '객관식 보기 선택',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _mutedColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(_question.choices.length, (idx) {
                        final selected = _selectedChoiceIndex == idx;
                        return ChoiceChip(
                          label: Text('${idx + 1}번: ${_question.choices[idx]}'),
                          selected: selected,
                          selectedColor: _lightPurple,
                          onSelected: (_) {
                            setModalState(() {
                              _selectedChoiceIndex = idx;
                              _directAnswerController.text =
                                  _question.choices[idx];
                            });
                            setState(() {});
                          },
                        );
                      }),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: _directAnswerController,
                    autofocus: _question.isShortAnswer,
                    decoration: InputDecoration(
                      labelText: '구한 정답 입력',
                      hintText: '구한 답을 입력하세요 (예: ${_question.correctAnswer})',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (val) {
                      final trimmed = val.trim();
                      if (!_question.isShortAnswer) {
                        final matchIdx = _question.choices.indexWhere(
                          (c) => c.trim() == trimmed,
                        );
                        _selectedChoiceIndex = matchIdx >= 0 ? matchIdx : null;
                      }
                      setModalState(() {});
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      if (autoSubmitAfterConfirm &&
                          (_directAnswerController.text.trim().isNotEmpty ||
                              _selectedChoiceIndex != null)) {
                        _handleDirectSubmit(isRetryStage: isRetryStage);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      autoSubmitAfterConfirm ? '입력 완료 및 제출하기' : '답안 저장하기',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// 피그마 1-1: 카메라 가이드 프레임 (주황/빨강 4모서리 브래킷 + 중앙 가로 점선)
class _CameraGuideFramePainter extends CustomPainter {
  final Color bracketColor;

  const _CameraGuideFramePainter({required this.bracketColor});

  @override
  void paint(Canvas canvas, Size size) {
    final borderPaint = Paint()
      ..color = Colors.white54
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawRect(Offset.zero & size, borderPaint);

    // 중앙 가로 점선
    final dashPaint = Paint()
      ..color = Colors.white38
      ..strokeWidth = 1.0;
    const dashWidth = 4.0;
    const dashSpace = 4.0;
    double startX = 0;
    final centerY = size.height / 2;
    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, centerY),
        Offset((startX + dashWidth).clamp(0, size.width), centerY),
        dashPaint,
      );
      startX += dashWidth + dashSpace;
    }

    // 4개 모서리 주황/빨강 L자 브래킷
    final bracketPaint = Paint()
      ..color = bracketColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.square;

    const len = 24.0;
    // 좌상단
    canvas.drawLine(const Offset(0, 0), const Offset(len, 0), bracketPaint);
    canvas.drawLine(const Offset(0, 0), const Offset(0, len), bracketPaint);
    // 우상단
    canvas.drawLine(
      Offset(size.width - len, 0),
      Offset(size.width, 0),
      bracketPaint,
    );
    canvas.drawLine(
      Offset(size.width, 0),
      Offset(size.width, len),
      bracketPaint,
    );
    // 좌하단
    canvas.drawLine(
      Offset(0, size.height - len),
      Offset(0, size.height),
      bracketPaint,
    );
    canvas.drawLine(
      Offset(0, size.height),
      Offset(len, size.height),
      bracketPaint,
    );
    // 우하단
    canvas.drawLine(
      Offset(size.width - len, size.height),
      Offset(size.width, size.height),
      bracketPaint,
    );
    canvas.drawLine(
      Offset(size.width, size.height - len),
      Offset(size.width, size.height),
      bracketPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CameraGuideFramePainter oldDelegate) => false;
}

/// 피그마 2-4: 모눈종이 격자 배경 + 학생 손글씨 드로잉 스트로크 페인터
class _GridScratchpadPainter extends CustomPainter {
  final List<List<Offset>> strokes;

  const _GridScratchpadPainter({required this.strokes});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFFEAEAEA)
      ..strokeWidth = 1.0;

    const step = 18.0;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final penPaint = Paint()
      ..color = const Color(0xFF2D3748)
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      for (var i = 0; i < stroke.length - 1; i++) {
        canvas.drawLine(stroke[i], stroke[i + 1], penPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GridScratchpadPainter oldDelegate) => true;
}
