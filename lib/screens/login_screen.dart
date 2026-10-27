// 학생용 APP 전용 로그인 · 회원가입 화면 (STEPi 앱 기능명세서 R8~R21 반영)
// 학부모·선생님은 별도 WEB 담당 파트로 분리되어 있으므로, 앱에서는 WEB 접속 안내 모달(R8)만 띄웁니다.
import 'package:flutter/material.dart';

import '../main.dart';
import '../services/api.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _primaryPurple = Color(0xFF9B7EFA);
  static const _deepPurple = Color(0xFF7652FF);
  static const _lightPurple = Color(0xFFF5F1FF);
  static const _accentOrange = Color(0xFFFF8A3D);
  static const _mutedColor = Color(0xFF777777);

  // false: 학생 로그인, true: 학생 회원가입
  bool _isSignUpMode = false;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController(text: 'student@stepi.kr');
  final _passwordController = TextEditingController(text: 'stepi1234!');
  final _passwordConfirmController = TextEditingController();
  final _learningGoalController = TextEditingController(
    text: '다항식과 방정식 오개념 완벽 정복',
  );

  String _selectedGrade = '고등학교 1학년';
  static const _grades = <String>['고등학교 1학년', '중학교 3학년', '중학교 2학년', '중학교 1학년'];

  bool _emailChecked = false;
  bool _agreeTerms = false;
  bool _agreePrivacy = false;
  bool _submitting = false;
  bool _obscurePassword = true;
  String? _errorText;

  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    _learningGoalController.dispose();
    super.dispose();
  }

  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(backgroundColor: _deepPurple, content: Text(message)),
      );
  }

  /// 앱 명세서 R18: 이메일 중복 확인
  Future<void> _checkDuplicateEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _errorText = '이메일을 입력해주세요.');
      return;
    }
    if (!_emailRegex.hasMatch(email)) {
      setState(() => _errorText = '올바른 이메일 형식을 입력해주세요.');
      return;
    }

    if (Api.isBackendConfigured) {
      try {
        await Api.get(
          Api.checkEmailEndpoint,
          queryParameters: {'email': email},
        );
      } on ApiException catch (e) {
        if (e.statusCode == 409) {
          setState(() {
            _emailChecked = false;
            _errorText = '이미 사용 중인 이메일입니다.';
          });
          return;
        }
      } catch (_) {}
    }

    setState(() {
      _emailChecked = true;
      _errorText = null;
    });
    _showToast('사용 가능한 이메일입니다.');
  }

  /// 앱 명세서 R9~R15: 학생 로그인 실행
  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty) {
      setState(() => _errorText = '이메일을 입력해주세요.');
      return;
    }
    if (!_emailRegex.hasMatch(email)) {
      setState(() => _errorText = '올바른 이메일 형식을 입력해주세요.');
      return;
    }
    if (password.isEmpty) {
      setState(() => _errorText = '비밀번호를 입력해주세요.');
      return;
    }
    if (password.length < 8) {
      setState(() => _errorText = '비밀번호는 8자 이상 입력해주세요.');
      return;
    }

    setState(() {
      _submitting = true;
      _errorText = null;
    });

    try {
      if (Api.isBackendConfigured) {
        final response = await Api.post(
          Api.loginEndpoint,
          body: {'email': email, 'password': password, 'role': 'STUDENT'},
        );

        if (response is Map) {
          final serverRole = response['role']?.toString();
          if (serverRole != null &&
              serverRole.isNotEmpty &&
              serverRole != 'STUDENT') {
            setState(() {
              _submitting = false;
              _errorText = '선생님/학부모 계정은 전용 WEB에서 로그인해 주세요.';
            });
            return;
          }

          final token =
              response['access_token']?.toString() ??
              response['token']?.toString();
          if (token != null && token.isNotEmpty) {
            Api.setAccessToken(token);
          }
        }
      } else {
        await Future<void>.delayed(const Duration(milliseconds: 350));
      }

      if (!mounted) return;
      setState(() => _submitting = false);

      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (context) => const MainScreen()),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        if (e.statusCode == 404) {
          _errorText = '가입되지 않은 계정입니다. 회원가입을 먼저 진행해주세요.';
        } else if (e.statusCode == 401) {
          _errorText = '비밀번호가 일치하지 않습니다.';
        } else {
          _errorText = '로그인에 실패했습니다. 잠시 후 다시 시도해주세요.';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorText = '로그인에 실패했습니다. 잠시 후 다시 시도해주세요.';
      });
    }
  }

  /// 앱 명세서 R16~R21: 학생 회원가입 실행
  Future<void> _handleSignUp() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _passwordConfirmController.text;

    if (name.isEmpty) {
      setState(() => _errorText = '이름을 입력해주세요.');
      return;
    }
    if (email.isEmpty || !_emailRegex.hasMatch(email)) {
      setState(() => _errorText = '올바른 이메일 형식을 입력해주세요.');
      return;
    }
    if (!_emailChecked) {
      setState(() => _errorText = '이메일 중복 확인을 먼저 진행해주세요.');
      return;
    }
    if (password.length < 8) {
      setState(() => _errorText = '비밀번호는 8자 이상 입력해주세요.');
      return;
    }
    if (password != confirm) {
      setState(() => _errorText = '비밀번호가 일치하지 않습니다.');
      return;
    }
    if (!_agreeTerms || !_agreePrivacy) {
      setState(() => _errorText = '[필수] 약관에 동의해주세요.');
      return;
    }

    setState(() {
      _submitting = true;
      _errorText = null;
    });

    try {
      if (Api.isBackendConfigured) {
        await Api.post(
          '/api/v1/auth/signup',
          body: {
            'name': name,
            'email': email,
            'password': password,
            'role': 'STUDENT',
            'grade_level': _selectedGrade,
            'learning_goal': _learningGoalController.text.trim(),
          },
        );
      } else {
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }

      if (!mounted) return;
      setState(() {
        _submitting = false;
        _isSignUpMode = false;
      });
      _showToast('회원가입이 완료되었습니다. 로그인해주세요!');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorText = '회원가입 요청 중 오류가 발생했습니다. 다시 시도해주세요.';
      });
    }
  }

  /// 앱 명세서 R8: 선생님/학부모 선택 시 관리자 WEB 유도 안내 팝업 노출
  void _showWebRedirectModal() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Row(
            children: [
              Icon(Icons.language_rounded, color: _deepPurple),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '선생님 · 학부모 WEB 안내',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          content: const Text(
            '선생님/학부모님은 전용 WEB 대시보드에서 학생의 학습 현황, 오개념 분석, 학습 리포트를 관리할 수 있어요!\n\nPC 또는 모바일 브라우저에서 STEPi 관리자 웹으로 접속해 주세요.',
            style: TextStyle(fontSize: 14, height: 1.55),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: FilledButton.styleFrom(backgroundColor: _deepPurple),
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _lightPurple,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    size: 58,
                    color: _deepPurple,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'STEPi',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      color: _deepPurple,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '로그인하여 내게 딱 맞는 역추적 학습을 시작하세요',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _mutedColor,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // 학생 로그인 / 회원가입 카드
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0D000000),
                          blurRadius: 16,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildModeTabButton(
                                title: '학생 로그인',
                                active: !_isSignUpMode,
                                onTap: () {
                                  setState(() {
                                    _isSignUpMode = false;
                                    _errorText = null;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildModeTabButton(
                                title: '회원가입',
                                active: _isSignUpMode,
                                onTap: () {
                                  setState(() {
                                    _isSignUpMode = true;
                                    _errorText = null;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        if (_isSignUpMode) ...[
                          TextField(
                            controller: _nameController,
                            decoration: _inputDecoration(
                              label: '이름',
                              hint: '홍길동',
                              icon: Icons.person_outline_rounded,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                onChanged: (_) {
                                  if (_emailChecked) {
                                    setState(() => _emailChecked = false);
                                  }
                                },
                                decoration: _inputDecoration(
                                  label: '이메일 아이디',
                                  hint: 'student@stepi.kr',
                                  icon: Icons.alternate_email_rounded,
                                ),
                              ),
                            ),
                            if (_isSignUpMode) ...[
                              const SizedBox(width: 8),
                              SizedBox(
                                height: 52,
                                child: OutlinedButton(
                                  onPressed: _checkDuplicateEmail,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: _emailChecked
                                        ? const Color(0xFF278B4B)
                                        : _deepPurple,
                                    side: BorderSide(
                                      color: _emailChecked
                                          ? const Color(0xFF278B4B)
                                          : _deepPurple,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text(
                                    _emailChecked ? '확인완료 ✓' : '중복확인',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 12),

                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: _inputDecoration(
                            label: '비밀번호 (8자 이상)',
                            hint: '비밀번호를 입력해주세요',
                            icon: Icons.lock_outline_rounded,
                            suffix: IconButton(
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 20,
                              ),
                            ),
                          ),
                        ),

                        if (_isSignUpMode) ...[
                          const SizedBox(height: 12),
                          TextField(
                            controller: _passwordConfirmController,
                            obscureText: _obscurePassword,
                            decoration: _inputDecoration(
                              label: '비밀번호 확인',
                              hint: '비밀번호를 한 번 더 입력해주세요',
                              icon: Icons.lock_reset_rounded,
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedGrade,
                            decoration: _inputDecoration(
                              label: '학년 선택',
                              hint: '',
                              icon: Icons.school_outlined,
                            ),
                            items: _grades
                                .map(
                                  (g) => DropdownMenuItem<String>(
                                    value: g,
                                    child: Text(g),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedGrade = val);
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _learningGoalController,
                            decoration: _inputDecoration(
                              label: '나의 학습 목표 (선택)',
                              hint: '예: 다항식과 이차방정식 완전 정복',
                              icon: Icons.flag_outlined,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _buildTermsAgreementBox(),
                        ],

                        if (_errorText != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF5F5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _errorText!,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFE53E3E),
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 18),
                        ElevatedButton(
                          onPressed: _submitting
                              ? null
                              : (_isSignUpMode ? _handleSignUp : _handleLogin),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _deepPurple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            _submitting
                                ? '로그인 중입니다...'
                                : _isSignUpMode
                                ? '학생 계정으로 가입하기'
                                : '로그인',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 선생님 / 학부모 WEB 유도 안내 버튼 (명세서 R8)
                  TextButton(
                    onPressed: _showWebRedirectModal,
                    child: const Text(
                      '선생님 / 학부모이신가요? (전용 WEB 안내)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _deepPurple,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeTabButton({
    required String title,
    required bool active,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: active ? _lightPurple : const Color(0xFFF7FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? _deepPurple : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: active ? _deepPurple : _mutedColor,
          ),
        ),
      ),
    );
  }

  Widget _buildTermsAgreementBox() {
    final allAgreed = _agreeTerms && _agreePrivacy;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          CheckboxListTile(
            value: allAgreed,
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text(
              '전체 약관 동의',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            onChanged: (val) {
              final next = val ?? false;
              setState(() {
                _agreeTerms = next;
                _agreePrivacy = next;
              });
            },
          ),
          const Divider(height: 6),
          CheckboxListTile(
            value: _agreeTerms,
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text(
              '[필수] 서비스 이용약관 동의',
              style: TextStyle(fontSize: 12),
            ),
            onChanged: (val) => setState(() => _agreeTerms = val ?? false),
          ),
          CheckboxListTile(
            value: _agreePrivacy,
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text(
              '[필수] 개인정보 처리방침 동의',
              style: TextStyle(fontSize: 12),
            ),
            onChanged: (val) => setState(() => _agreePrivacy = val ?? false),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, size: 20, color: _primaryPurple),
      suffixIcon: suffix,
      isDense: true,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _accentOrange, width: 2),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
