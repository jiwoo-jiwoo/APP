import '../models/practice_question.dart';

abstract class QuestionService {
  Future<List<PracticeQuestion>> fetchQuestions();
}

class MockQuestionService implements QuestionService {
  final String unit;

  const MockQuestionService({this.unit = '다항식'});

  static const _questionsByUnit = <String, List<PracticeQuestion>>{
    '다항식': [
      // 객관식
      PracticeQuestion(
        problemCode: 'PRB-1-008',
        title: '곱셈 공식 활용',
        question: '99²을 곱셈 공식을 이용하여 계산한 값은?',
        choices: ['9801', '9901', '9981', '10001'],
        correctIndex: 0,
        difficulty: 2,
        purpose: 'PRACTICE',
        explanation: '99²=(100-1)²=10000-200+1=9801입니다.',
      ),

      // 주관식
      PracticeQuestion(
        problemCode: 'PRB-1-014',
        title: '나머지정리',
        question: 'P(x)=x²-3x+5를 x-2로 나눈 나머지를 구하시오.',
        questionType: PracticeQuestion.shortAnswer,
        answerText: '3',
        gradingMode: 'NUMERIC',
        difficulty: 1,
        purpose: 'DIAGNOSTIC',
        explanation: '나머지정리에 의해 나머지는 P(2)=4-6+5=3입니다.',
      ),

      // 주관식
      PracticeQuestion(
        problemCode: 'PRB-1-017',
        title: '인수정리',
        question: 'x-3이 x²+ax-6의 인수일 때 a를 구하시오.',
        questionType: PracticeQuestion.shortAnswer,
        answerText: '-1',
        gradingMode: 'NUMERIC',
        difficulty: 2,
        purpose: 'PRACTICE',
        explanation: 'P(3)=9+3a-6=0이므로 3+3a=0, a=-1입니다.',
      ),
    ],

    '방정식과 부등식': [
      // 객관식
      PracticeQuestion(
        problemCode: 'PRB-2-001',
        title: '허수단위',
        question: 'i²+i⁴의 값은?',
        choices: ['-2', '-1', '0', '2'],
        correctIndex: 2,
        difficulty: 1,
        purpose: 'DIAGNOSTIC',
        explanation: 'i²=-1, i⁴=1이므로 합은 0입니다.',
      ),

      // 주관식
      PracticeQuestion(
        problemCode: 'PRB-2-004',
        title: '복소수의 상등',
        question: '(x+1)+(2y-3)i=5+7i일 때 x+y를 구하시오.',
        questionType: PracticeQuestion.shortAnswer,
        answerText: '9',
        gradingMode: 'NUMERIC',
        difficulty: 2,
        purpose: 'PRACTICE',
        explanation:
            'x+1=5에서 x=4, 2y-3=7에서 y=5이므로 '
            'x+y=9입니다.',
      ),

      // 주관식
      PracticeQuestion(
        problemCode: 'PRB-2-012',
        title: '판별식',
        question: '2x²-3x-2=0의 판별식을 구하시오.',
        questionType: PracticeQuestion.shortAnswer,
        answerText: '25',
        gradingMode: 'NUMERIC',
        difficulty: 1,
        purpose: 'DIAGNOSTIC',
        explanation: 'D=(-3)²-4·2·(-2)=9+16=25입니다.',
      ),
    ],

    '경우의 수': [
      // 객관식
      PracticeQuestion(
        problemCode: 'PRB-3-004',
        title: '곱의 법칙',
        question:
            '셔츠 3벌과 바지 2벌 중 한 벌씩 고르는 '
            '경우의 수는?',
        choices: ['5', '6', '8', '9'],
        correctIndex: 1,
        difficulty: 1,
        purpose: 'PRACTICE',
        explanation:
            '셔츠 3가지와 바지 2가지의 단계별 선택이므로 '
            '3×2=6입니다.',
      ),

      // 주관식
      PracticeQuestion(
        problemCode: 'PRB-3-009',
        title: '순열',
        question: '6P2를 계산하시오.',
        questionType: PracticeQuestion.shortAnswer,
        answerText: '30',
        gradingMode: 'NUMERIC',
        difficulty: 1,
        purpose: 'DIAGNOSTIC',
        explanation: '6P2=6×5=30입니다.',
      ),

      // 주관식
      PracticeQuestion(
        problemCode: 'PRB-3-013',
        title: '조합',
        question: '6C2를 계산하시오.',
        questionType: PracticeQuestion.shortAnswer,
        answerText: '15',
        gradingMode: 'NUMERIC',
        difficulty: 1,
        purpose: 'DIAGNOSTIC',
        explanation: '6C2=6×5/(2×1)=15입니다.',
      ),
    ],

    '행렬': [
      // 객관식
      PracticeQuestion(
        problemCode: 'PRB-4-001',
        title: '행렬의 성분',
        question:
            'A=[[1,2,3],[4,5,6]]에서 '
            '제2행 제3열의 성분은?',
        choices: ['2', '3', '5', '6'],
        correctIndex: 3,
        difficulty: 1,
        purpose: 'DIAGNOSTIC',
        explanation: '제2행은 [4,5,6]이고 그 제3열 성분은 6입니다.',
      ),

      // 주관식
      PracticeQuestion(
        problemCode: 'PRB-4-004',
        title: '행렬의 성분 찾기',
        question: 'A=[[2,-1],[0,5]]일 때 a₁₂를 구하시오.',
        questionType: PracticeQuestion.shortAnswer,
        answerText: '-1',
        gradingMode: 'NUMERIC',
        difficulty: 1,
        purpose: 'PRACTICE',
        explanation: 'a₁₂는 제1행 제2열 성분이므로 -1입니다.',
      ),

      // 주관식
      PracticeQuestion(
        problemCode: 'PRB-4-007',
        title: '행렬의 상등',
        question:
            '[[x,2],[3,4]]=[[1,2],[3,4]]일 때 '
            'x를 구하시오.',
        questionType: PracticeQuestion.shortAnswer,
        answerText: '1',
        gradingMode: 'NUMERIC',
        difficulty: 1,
        purpose: 'PRACTICE',
        explanation: '상등인 행렬의 대응 성분은 같으므로 x=1입니다.',
      ),
    ],
  };

  @override
  Future<List<PracticeQuestion>> fetchQuestions() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));

    return List<PracticeQuestion>.unmodifiable(
      _questionsByUnit[unit] ?? const <PracticeQuestion>[],
    );
  }
}
