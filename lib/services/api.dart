import 'dart:convert';

import 'package:http/http.dart' as http;

/// STEPi 기능명세서(백엔드 21개 DB 테이블 · AI① · AI② 규격)에 맞춘 공통 API 클래스입니다.
///
/// [화요일 백엔드·AI①·AI② 연동 방법]
/// 1. `defaultDevBaseUrl`에 FastAPI 서버 주소(예: 'http://192.168.0.10:8000')를 넣거나
///    실행 시 `--dart-define=API_BASE_URL=http://...`를 전달하면 즉시 실서버와 통신합니다.
/// 2. `baseUrl`이 비어 있으면 프론트엔드 단독 시연(Auto-Fallback Mock 모드)으로 동작합니다.
class Api {
  Api._();

  // 화요일 연동 시 백엔드(FastAPI) 서버 주소를 여기에 입력하거나 --dart-define으로 주입하세요.
  static const String defaultDevBaseUrl = '';

  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl =>
      _envBaseUrl.isNotEmpty ? _envBaseUrl : defaultDevBaseUrl;

  static bool get isBackendConfigured => baseUrl.trim().isNotEmpty;

  static const Duration _timeout = Duration(seconds: 20);

  // 인증 토큰 (POST /api/auth/login 또는 /api/v1/auth/login 성공 시 설정)
  static String? _accessToken;

  static void setAccessToken(String? token) {
    _accessToken = token;
  }

  // ---------------------------------------------------------------------------
  // STEPi 기능명세서 기반 공식 엔드포인트 상수
  // (백엔드 8-1 ~ 8-16 작업 순서 및 웹/앱 기능명세서 경로 반영)
  // ---------------------------------------------------------------------------
  static const String loginEndpoint = '/api/v1/auth/login';
  static const String checkEmailEndpoint = '/api/v1/auth/check-email';
  static const String sessionsEndpoint = '/api/v1/learning-sessions';
  static const String capturedProblemsEndpoint = '/api/v1/captured-problems';
  static const String attemptsEndpoint = '/api/v1/attempts';
  static const String ai1AnalyzeEndpoint = '/api/v1/ai1/analyze';
  static const String ai2TutorDecisionEndpoint = '/api/v1/ai2/decision';
  static const String studentStatesEndpoint = '/api/v1/students/me/states';
  static const String studentGamificationEndpoint =
      '/api/v1/students/me/gamification';
  static const String studentHistoryEndpoint = '/api/v1/students/me/history';

  static Map<String, String> get _headers {
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json; charset=utf-8',
      if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
    };
  }

  static Uri _buildUri(String path, Map<String, String>? queryParameters) {
    if (baseUrl.isEmpty) {
      throw StateError(
        'Backend 주소가 설정되지 않았습니다. '
        'API_BASE_URL을 설정해 주세요.',
      );
    }

    final base = baseUrl.replaceFirst(RegExp(r'/+$'), '');
    final endpoint = path.replaceFirst(RegExp(r'^/+'), '');

    final uri = Uri.parse('$base/$endpoint');

    if (!uri.hasAuthority || (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw StateError('Backend 주소 형식이 올바르지 않습니다.');
    }

    return uri.replace(
      queryParameters: {...uri.queryParameters, ...?queryParameters},
    );
  }

  /// 데이터 조회 (GET)
  static Future<dynamic> get(
    String path, {
    Map<String, String>? queryParameters,
  }) async {
    final response = await http
        .get(_buildUri(path, queryParameters), headers: _headers)
        .timeout(_timeout);

    return _handleResponse(response);
  }

  /// 데이터 전송 (POST)
  static Future<dynamic> post(String path, {Object? body}) async {
    final response = await http
        .post(
          _buildUri(path, null),
          headers: _headers,
          body: body == null ? null : jsonEncode(body),
        )
        .timeout(_timeout);

    return _handleResponse(response);
  }

  // ---------------------------------------------------------------------------
  // [8-8 & 8-9] 문제+손글씨 풀이 이미지 업로드 및 AI①(ai_analysis_results) 분석 요청
  // DB 매핑: captured_problems, attempts, ai_analysis_results, student_misconceptions
  // ---------------------------------------------------------------------------
  static Future<Map<String, dynamic>?> submitAndAnalyzeSolution({
    required String problemCode,
    required int solveTimeSeconds,
    required int hintCount,
    String? studentAnswer,
    String? solutionImageUrl,
  }) async {
    if (!isBackendConfigured) return null;

    final result = await post(
      ai1AnalyzeEndpoint,
      body: {
        'problem_code': problemCode,
        'student_answer': studentAnswer,
        'solution_image_url': solutionImageUrl ?? '/uploads/solution_temp.jpg',
        'solve_time_seconds': solveTimeSeconds,
        'hint_count': hintCount,
      },
    );

    return result is Map ? Map<String, dynamic>.from(result) : null;
  }

  // ---------------------------------------------------------------------------
  // [8-12 & 8-13] AI② Tutor Orchestrator 개입 요청 (tutor_actions 테이블 규격)
  // 지원 action_type: HINT | CONCEPT_REVIEW | PREREQUISITE_REVIEW | VARIANT_PROBLEM | MOTIVATION
  // ---------------------------------------------------------------------------
  static Future<Map<String, dynamic>?> requestTutorAction({
    required String problemCode,
    required String actionType,
    int? attemptId,
    int? aiAnalysisId,
    int? firstErrorStep,
    String? misconceptionCode,
    String? studentMessage,
    int hintCount = 1,
  }) async {
    if (!isBackendConfigured) return null;

    final result = await post(
      ai2TutorDecisionEndpoint,
      body: {
        'problem_code': problemCode,
        'action_type': actionType,
        'attempt_id': attemptId,
        'ai_analysis_id': aiAnalysisId,
        'first_error_step': firstErrorStep,
        'misconception_code': misconceptionCode,
        'student_message': studentMessage,
        'hint_count': hintCount,
      },
    );

    return result is Map ? Map<String, dynamic>.from(result) : null;
  }

  // ---------------------------------------------------------------------------
  // [8-7 & 8-15] 학습 시도(attempts) 및 학습 이벤트 로그(learning_logs) 저장
  // ---------------------------------------------------------------------------
  static Future<Map<String, dynamic>?> recordLearningEvent({
    required String eventType,
    required String problemCode,
    Map<String, dynamic>? metadata,
  }) async {
    if (!isBackendConfigured) return null;

    final result = await post(
      attemptsEndpoint,
      body: {
        'event_type': eventType,
        'problem_code': problemCode,
        'metadata': metadata ?? const <String, dynamic>{},
      },
    );

    return result is Map ? Map<String, dynamic>.from(result) : null;
  }

  static dynamic _handleResponse(http.Response response) {
    final text = utf8.decode(response.bodyBytes);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        statusCode: response.statusCode,
        message: text.isEmpty ? 'API 요청에 실패했습니다.' : text,
      );
    }

    if (text.trim().isEmpty) {
      return null;
    }

    try {
      return jsonDecode(text);
    } on FormatException {
      throw ApiException(
        statusCode: response.statusCode,
        message: '서버 응답이 올바른 JSON 형식이 아닙니다.',
      );
    }
  }
}

/// 서버 오류를 전달하는 예외 클래스입니다.
class ApiException implements Exception {
  final int statusCode;
  final String message;

  const ApiException({required this.statusCode, required this.message});

  @override
  String toString() {
    return 'ApiException($statusCode): $message';
  }
}
