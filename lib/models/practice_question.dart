class PracticeQuestion {
  static const multipleChoice = 'MULTIPLE_CHOICE';
  static const shortAnswer = 'SHORT_ANSWER';

  final String? problemCode;
  final String title;
  final String question;
  final String questionType;
  final List<String> choices;
  final int correctIndex;
  final String explanation;

  // 주관식의 표시용 정답과 모의 채점 방식
  final String? answerText;
  final String? gradingMode;

  final int? difficulty;
  final String? purpose;

  const PracticeQuestion({
    this.problemCode,
    required this.title,
    required this.question,
    this.questionType = multipleChoice,
    this.choices = const [],
    this.correctIndex = -1,
    required this.explanation,
    this.answerText,
    this.gradingMode,
    this.difficulty,
    this.purpose,
  });

  bool get isShortAnswer => questionType == shortAnswer;

  String get correctAnswer {
    if (isShortAnswer) {
      return answerText ?? '';
    }

    return choices[correctIndex];
  }

  void validate() {
    if (question.trim().isEmpty) {
      throw const FormatException('문제 내용이 비어 있어요.');
    }

    if (isShortAnswer) {
      // 이번 단계에서는 숫자 하나인 답만 채점합니다.
      final expected = double.tryParse(answerText ?? '');

      if (gradingMode != 'NUMERIC' || expected == null || !expected.isFinite) {
        throw const FormatException('지원하지 않는 주관식 채점 방식이에요.');
      }

      return;
    }

    if (questionType != multipleChoice ||
        choices.isEmpty ||
        correctIndex < 0 ||
        correctIndex >= choices.length) {
      throw const FormatException('문제의 선택지 또는 정답이 잘못됐어요.');
    }
  }

  bool matchesNumericAnswer(String input) {
    if (!isShortAnswer || gradingMode != 'NUMERIC') {
      return false;
    }

    final normalized = input.trim().replaceAll('−', '-').replaceAll('－', '-');

    final actual = double.tryParse(normalized);
    final expected = double.tryParse(answerText ?? '');

    if (actual == null ||
        expected == null ||
        !actual.isFinite ||
        !expected.isFinite) {
      return false;
    }

    return actual == expected;
  }

  // 백엔드 응답 형식이 확정되기 전의 앱 내부 규격입니다.
  factory PracticeQuestion.fromJson(Map<String, dynamic> json) {
    final title = json['title'];
    final question = json['question'];
    final explanation = json['explanation'];
    final type = json['questionType'] ?? multipleChoice;
    final rawChoices = json['choices'] ?? const <String>[];
    final rawCorrectIndex = json['correctIndex'] ?? -1;

    if (title is! String ||
        question is! String ||
        explanation is! String ||
        type is! String ||
        rawChoices is! List ||
        rawChoices.any((item) => item is! String) ||
        rawCorrectIndex is! int ||
        (json['correctAnswer'] != null && json['correctAnswer'] is! String) ||
        (json['gradingMode'] != null && json['gradingMode'] is! String)) {
      throw const FormatException('문제 데이터 형식이 올바르지 않습니다.');
    }

    final result = PracticeQuestion(
      problemCode: json['problemCode']?.toString(),
      title: title,
      question: question,
      questionType: type,
      choices: List<String>.unmodifiable(rawChoices.cast<String>()),
      correctIndex: rawCorrectIndex,
      explanation: explanation,
      answerText: json['correctAnswer'] as String?,
      gradingMode: json['gradingMode'] as String?,
      difficulty: json['difficulty'] is int ? json['difficulty'] as int : null,
      purpose: json['purpose']?.toString(),
    );

    result.validate();
    return result;
  }

  Map<String, dynamic> toJson() {
    return {
      'problemCode': problemCode,
      'title': title,
      'question': question,
      'questionType': questionType,
      'choices': choices,
      'correctIndex': correctIndex,
      'correctAnswer': correctAnswer,
      'gradingMode': gradingMode,
      'difficulty': difficulty,
      'purpose': purpose,
      'explanation': explanation,
    };
  }
}
