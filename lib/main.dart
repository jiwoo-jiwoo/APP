import 'package:flutter/material.dart';

import 'screens/home_tab.dart';
import 'screens/learning_tab.dart';
import 'screens/login_screen.dart';
import 'screens/problem_screen.dart';
import 'screens/shop_tab.dart';
import 'screens/skill_tree_tab.dart';

import 'services/learning_storage.dart';
import 'services/question_service.dart';
import 'services/reward_storage.dart';

final RouteObserver<PageRoute<dynamic>> appRouteObserver =
    RouteObserver<PageRoute<dynamic>>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const StepIApp());
}

class StepIApp extends StatelessWidget {
  const StepIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'STEPi',
      debugShowCheckedModeBanner: false,
      navigatorObservers: [appRouteObserver],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF9B7EFA)),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF171717),
          elevation: 0,
          centerTitle: false,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      home: const LoginScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with WidgetsBindingObserver, RouteAware {
  static const _primaryColor = Color(0xFF9B7EFA);

  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  // 0: 홈, 1: 학습, 2: 리포트·스킬맵, 3: 마이·상점
  int _selectedIndex = 0;
  final _homeKey = GlobalKey<HomeTabState>();

  ExperienceProgress _experience = const ExperienceProgress(0);

  bool _loadingExperience = true;
  bool _refreshingExperience = false;
  bool _refreshingGold = false;

  String? _experienceError;
  String? _goldError;

  PageRoute<dynamic>? _subscribedRoute;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _pages = [
      HomeTab(key: _homeKey, onNavigate: _onItemTapped),
      LearningTab(
        onExperienceChanged: () {
          _refreshExperience();
        },
      ),
      SkillTreeTab(
        onExperienceChanged: () {
          _refreshExperience();
        },
      ),
      const ShopTab(),
    ];

    _refreshBalances();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final route = ModalRoute.of(context);

    if (route is PageRoute<dynamic> && route != _subscribedRoute) {
      appRouteObserver.unsubscribe(this);

      _subscribedRoute = route;
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didPopNext() {
    _refreshBalances();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshBalances();
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
  }

  void _onItemTapped(int index) {
    if (index < 0 || index >= _pages.length) return;

    setState(() {
      _selectedIndex = index;
    });

    _refreshBalances();
  }

  /// 하단 중앙 보라색 카메라 FAB 터치 시 외부 문제집/공책 즉시 촬영 모드(startWithCamera: true) 실행
  Future<void> _openDirectCameraCapture() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => const ProblemScreen(
          topic: '외부 문제집 촬영',
          questionService: MockQuestionService(unit: '다항식'),
          startWithCamera: true,
        ),
      ),
    );

    if (mounted) {
      await _refreshBalances();
    }
  }

  Future<void> _refreshBalances() async {
    await Future.wait<void>([_refreshExperience(), _refreshGold()]);
  }

  Future<void> _refreshExperience() async {
    if (!mounted || _refreshingExperience) return;

    _refreshingExperience = true;

    try {
      final progress = await LearningStorage.getExperienceProgress();

      if (!mounted) return;

      setState(() {
        _experience = progress;
        _loadingExperience = false;
        _experienceError = null;
      });
      _homeKey.currentState?.refresh();
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loadingExperience = false;
        _experienceError = '저장된 경험치를 불러오지 못했습니다.';
      });

      _showStorageError(_experienceError!);
    } finally {
      _refreshingExperience = false;
    }
  }

  Future<void> _refreshGold() async {
    if (!mounted || _refreshingGold) return;

    _refreshingGold = true;

    try {
      await RewardStorage.getGold();

      if (!mounted) return;

      setState(() {
        _goldError = null;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _goldError = '저장된 골드를 불러오지 못했습니다.';
      });

      _showStorageError(_goldError!);
    } finally {
      _refreshingGold = false;
    }
  }

  void _showStorageError(String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final messenger = _messengerKey.currentState;

      if (messenger == null) return;

      messenger.hideCurrentSnackBar();

      messenger.showSnackBar(
        SnackBar(
          content: Text(message),
          action: SnackBarAction(
            label: '재시도',
            onPressed: () {
              _refreshBalances();
            },
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _messengerKey,
      child: Scaffold(
        extendBody: true,
        appBar: AppBar(
          title: const Text(
            'STEPi',
            style: TextStyle(fontWeight: FontWeight.w800, color: _primaryColor),
          ),
          actions: [
            _buildLevelBadge(),
            const SizedBox(width: 8),
            _buildGoldBadge(),
            const SizedBox(width: 4),
            IconButton(
              tooltip: '학부모·교사 리포트 및 로그인 전환',
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute<void>(
                    builder: (context) => const LoginScreen(),
                  ),
                );
              },
              icon: const Icon(
                Icons.switch_account_rounded,
                size: 22,
                color: Color(0xFF777777),
              ),
            ),
            const SizedBox(width: 8),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(32),
            child: _buildExperienceBar(),
          ),
        ),
        body: SafeArea(
          bottom: false,
          child: IndexedStack(index: _selectedIndex, children: _pages),
        ),
        bottomNavigationBar: _buildFloatingPillBottomBar(),
      ),
    );
  }

  /// 첨부 시안(image_fb9a19.png)과 동일한 연보라색 라운드 캡슐형 하단바 + 중앙 돌출 카메라 촬영 버튼
  Widget _buildFloatingPillBottomBar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Center(
          heightFactor: 1.0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: SizedBox(
              height: 92,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomCenter,
                children: [
                  // 연보라색 둥근 캡슐 바
                  Container(
                    height: 68,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBB2FC),
                      borderRadius: BorderRadius.circular(36),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildPillNavItem(
                          index: 0,
                          icon: Icons.home_outlined,
                          activeIcon: Icons.home_rounded,
                          tooltip: '홈',
                        ),
                        _buildPillNavItem(
                          index: 1,
                          icon: Icons.menu_book_outlined,
                          activeIcon: Icons.menu_book_rounded,
                          tooltip: '단원 학습',
                        ),
                        const SizedBox(width: 64), // 중앙 카메라 버튼 자리
                        _buildPillNavItem(
                          index: 2,
                          icon: Icons.bar_chart_rounded,
                          activeIcon: Icons.bar_chart_rounded,
                          tooltip: '역추적 스킬맵 · 분석',
                        ),
                        _buildPillNavItem(
                          index: 3,
                          icon: Icons.account_circle_outlined,
                          activeIcon: Icons.account_circle_rounded,
                          tooltip: '보상 상점 · 마이',
                        ),
                      ],
                    ),
                  ),

                  // 중앙 상단으로 살짝 돌출된 보라색 원형 카메라 촬영 FAB
                  Positioned(
                    top: 0,
                    child: GestureDetector(
                      onTap: _openDirectCameraCapture,
                      child: Tooltip(
                        message: '문제+손글씨 풀이 바로 촬영하기',
                        child: Container(
                          width: 62,
                          height: 62,
                          decoration: const BoxDecoration(
                            color: Color(0xFF8364F4),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Color(0x408364F4),
                                blurRadius: 12,
                                offset: Offset(0, 5),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            color: Colors.white,
                            size: 30,
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
      ),
    );
  }

  Widget _buildPillNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String tooltip,
  }) {
    final isSelected = _selectedIndex == index;

    return IconButton(
      tooltip: tooltip,
      onPressed: () => _onItemTapped(index),
      icon: Icon(
        isSelected ? activeIcon : icon,
        size: 30,
        color: isSelected ? const Color(0xFF171717) : const Color(0xFF2D2546),
      ),
    );
  }

  Widget _buildLevelBadge() {
    String label;
    String tooltip;

    if (_loadingExperience) {
      label = 'Lv. …';
      tooltip = '경험치를 불러오는 중입니다.';
    } else if (_experienceError != null) {
      label = 'Lv. —';
      tooltip = _experienceError!;
    } else {
      label = 'Lv. ${_experience.level}';
      tooltip =
          '누적 ${_experience.totalXp} XP\n'
          '다음 레벨까지 ${_experience.remainingXp} XP';
    }

    return Center(
      child: Tooltip(
        message: tooltip,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F1FF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: _primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGoldBadge() {
    return ValueListenableBuilder<int?>(
      valueListenable: RewardStorage.goldNotifier,
      builder: (context, gold, child) {
        final label = _goldError != null
            ? '— G'
            : gold == null
            ? '… G'
            : '$gold G';

        return Center(
          child: Tooltip(
            message: _goldError ?? '오늘의 퀘스트에서 골드를 받을 수 있어요.',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7E6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.monetization_on_rounded,
                    size: 18,
                    color: Color(0xFFE5A000),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFF9B7000),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildExperienceBar() {
    final unavailable = _loadingExperience || _experienceError != null;

    String label;

    if (_loadingExperience) {
      label = '경험치 불러오는 중…';
    } else if (_experienceError != null) {
      label = '경험치 로드 실패';
    } else {
      label =
          '${_experience.currentLevelXp}'
          ' / ${ExperienceProgress.xpPerLevel} XP';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: unavailable ? 0.0 : _experience.progress,
                minHeight: 6,
                backgroundColor: const Color(0xFFF0EBFF),
                color: _primaryColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF777777)),
          ),
        ],
      ),
    );
  }
}
