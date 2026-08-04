import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

/// Pantalla de bienvenida mostrada tras el splash para usuarios sin sesión.
/// Propuesta de valor en carrusel de tarjetas, jerarquía clara de acciones
/// (login primario / registro web secundario) y fondo orgánico.
class LandingScreen extends ConsumerStatefulWidget {
  const LandingScreen({super.key});

  static const String registerUrl = 'https://lifebalance-adv3.onrender.com/register';

  @override
  ConsumerState<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends ConsumerState<LandingScreen>
    with SingleTickerProviderStateMixin {
  static const Color background = Color(0xFFF4F9F5);
  static const Color darkGreen = Color(0xFF022C22);
  static const Color emerald = Color(0xFF3E6F58);
  static const Color mint = Color(0xFFE9F1EC);

  late final AnimationController _controller;
  late final Animation<double> _fadeIn;
  late final Animation<double> _scale;
  final PageController _pageController = PageController(viewportFraction: 0.82);
  int _currentPage = 0;

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Buenos días';
    if (hour < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  Future<void> _openRegisterWeb() async {
    final uri = Uri.parse(LandingScreen.registerUrl);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        messenger.showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el registro en la web.')),
        );
      }
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el registro en la web.')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _scale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: background,
      body: Stack(
        children: [
          // Fondo orgánico: formas suaves que rompen la monotonía.
          const _OrganicBackground(),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(0, 24, 0, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: FadeTransition(
                            opacity: _fadeIn,
                            child: ScaleTransition(
                              scale: _scale,
                              child: Column(
                                children: [
                                  const Text(
                                    'LifeBalance',
                                    style: TextStyle(
                                      color: darkGreen,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 26,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Container(
                                    width: 112,
                                    height: 112,
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white,
                                      border: Border.all(color: mint, width: 2),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Colors.black12,
                                          blurRadius: 16,
                                          offset: Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: ClipOval(
                                      child: Image.asset(
                                        'assets/images/logo.png',
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: FadeTransition(
                            opacity: _fadeIn,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _greeting,
                                  style: textTheme.headlineMedium?.copyWith(
                                    color: darkGreen,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Tu salud en equilibrio, paso a paso.',
                                  style: textTheme.bodyLarge?.copyWith(
                                    color: darkGreen.withValues(alpha: 0.75),
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        _BenefitsCarousel(
                          controller: _pageController,
                          onPageChanged: (index) =>
                              setState(() => _currentPage = index),
                        ),
                        const SizedBox(height: 16),
                        _DotsIndicator(
                          count: 3,
                          currentIndex: _currentPage,
                        ),
                      ],
                    ),
                  ),
                ),
                _AccessSection(onRegisterWeb: _openRegisterWeb),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Fondo con formas orgánicas difuminadas (sensación de fluidez y bienestar).
class _OrganicBackground extends StatelessWidget {
  const _OrganicBackground();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            Positioned(
              top: -90,
              right: -70,
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _LandingScreenState.mint.withValues(alpha: 0.7),
                ),
              ),
            ),
            Positioned(
              top: 220,
              left: -80,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFD8E8DF).withValues(alpha: 0.6),
                ),
              ),
            ),
            Positioned(
              bottom: 80,
              right: -60,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _LandingScreenState.mint.withValues(alpha: 0.8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Carrusel de tarjetas de beneficios con swipe horizontal.
class _BenefitsCarousel extends StatelessWidget {
  const _BenefitsCarousel({
    required this.controller,
    required this.onPageChanged,
  });

  final PageController controller;
  final ValueChanged<int> onPageChanged;

  static const List<_BenefitData> _benefits = [
    _BenefitData(
      title: 'Menos sedentarismo',
      description:
          'Alertas suaves si llevas 45 min en reposo, para que hagas una pausa activa.',
      illustration: _WalkIllustration(),
      tint: Color(0xFFE3F0E8),
    ),
    _BenefitData(
      title: 'Bienestar monitoreado',
      description:
          'Registra pasos, ritmo cardíaco y descanso desde tu reloj. Datos cifrados.',
      illustration: _HeartIllustration(),
      tint: Color(0xFFFDEBE9),
    ),
    _BenefitData(
      title: 'Insights para tu día',
      description:
          'Historial claro y alertas personalizables para decidir mejor cada jornada.',
      illustration: _InsightsIllustration(),
      tint: Color(0xFFE9ECF6),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 300,
      child: PageView.builder(
        controller: controller,
        itemCount: _benefits.length,
        onPageChanged: onPageChanged,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: _BenefitCard(data: _benefits[index]),
          );
        },
      ),
    );
  }
}

class _BenefitData {
  const _BenefitData({
    required this.title,
    required this.description,
    required this.illustration,
    required this.tint,
  });

  final String title;
  final String description;
  final Widget illustration;
  final Color tint;
}

class _BenefitCard extends StatelessWidget {
  const _BenefitCard({required this.data});

  final _BenefitData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 18, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: data.tint,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Center(child: data.illustration),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: _LandingScreenState.darkGreen,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  data.description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: _LandingScreenState.darkGreen.withValues(alpha: 0.7),
                        height: 1.3,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Ilustración: corredor con cronómetro (pausa activa).
class _WalkIllustration extends StatelessWidget {
  const _WalkIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: _LandingScreenState.mint,
            ),
          ),
          const Icon(Icons.directions_walk, size: 56, color: _LandingScreenState.emerald),
          Positioned(
            bottom: 10,
            right: 6,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: _LandingScreenState.emerald,
              ),
              child: const Icon(Icons.timer_outlined, size: 20, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ilustración: corazón con pulso y señal del reloj.
class _HeartIllustration extends StatelessWidget {
  const _HeartIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFFBE5E2),
            ),
          ),
          const Icon(Icons.favorite, size: 52, color: Color(0xFFE0524F)),
          const Positioned(
            top: 12,
            right: 10,
            child: Icon(Icons.watch_outlined, size: 26, color: _LandingScreenState.darkGreen),
          ),
        ],
      ),
    );
  }
}

/// Ilustración: gráfica de tendencia con alerta.
class _InsightsIllustration extends StatelessWidget {
  const _InsightsIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFE6EAF5),
            ),
          ),
          const Icon(Icons.show_chart, size: 54, color: Color(0xFF4A6FA5)),
          const Positioned(
            top: 8,
            left: 6,
            child: Icon(Icons.notifications_active_outlined,
                size: 24, color: Color(0xFFE0A23A)),
          ),
        ],
      ),
    );
  }
}

/// Indicador de página del carrusel.
class _DotsIndicator extends StatelessWidget {
  const _DotsIndicator({required this.count, required this.currentIndex});

  final int count;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == currentIndex ? 22 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == currentIndex
                  ? _LandingScreenState.emerald
                  : _LandingScreenState.emerald.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}

/// Sección de acceso con jerarquía clara:
/// login primario (sólido) y registro web secundario (outline).
class _AccessSection extends ConsumerWidget {
  const _AccessSection({required this.onRegisterWeb});

  final VoidCallback onRegisterWeb;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 16, offset: Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton(
              onPressed: () => context.go('/login'),
              style: FilledButton.styleFrom(
                backgroundColor: _LandingScreenState.emerald,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 2,
              ),
              child: const Text(
                'Iniciar sesión',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRegisterWeb,
              style: OutlinedButton.styleFrom(
                foregroundColor: _LandingScreenState.darkGreen.withValues(alpha: 0.75),
                padding: const EdgeInsets.symmetric(vertical: 15),
                side: BorderSide(
                  color: _LandingScreenState.darkGreen.withValues(alpha: 0.25),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w500),
              ),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Crear cuenta en la web'),
            ),
          ],
        ),
      ),
    );
  }
}
