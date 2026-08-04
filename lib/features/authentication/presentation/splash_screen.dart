import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lifebalance/core/security/token_service.dart';
import 'package:video_player/video_player.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  VideoPlayerController? _videoController;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    final controller = VideoPlayerController.asset(
      'assets/videos/SplashScreenLB.mp4',
    );
    _videoController = controller;
    try {
      await controller.initialize();
      controller.setLooping(false);
      controller.addListener(_onVideoListener);
      await controller.play();
      if (!mounted) return;
      setState(() {});
    } catch (_) {
      // Si el video no puede reproducirse, navegar igualmente.
      _navigateToLogin();
    }
  }

  void _onVideoListener() {
    final controller = _videoController;
    if (controller == null || _navigated) return;
    final position = controller.value.position;
    final duration = controller.value.duration;
    if (controller.value.isInitialized &&
        position >= duration &&
        duration > Duration.zero) {
      _navigateToLogin();
    }
  }

  Future<void> _navigateToLogin() async {
    if (_navigated || !mounted) return;
    _navigated = true;

    try {
      final hasToken = await ref.read(tokenServiceProvider).hasValidToken();
      if (!mounted) return;
      if (hasToken) {
        context.go('/dashboard');
      } else {
        context.go('/landing');
      }
    } catch (_) {
      // Security: silencio total ante fallos de lectura de token; nunca
      // loguear contenido de credenciales (PCI-DSS 10.5 / OWASP-API-9).
      if (!mounted) return;
      context.go('/landing');
    }
  }

  @override
  void dispose() {
    _videoController?.removeListener(_onVideoListener);
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _videoController;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SizedBox.expand(
        child: controller != null && controller.value.isInitialized
            ? FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: controller.value.size.width,
                  height: controller.value.size.height,
                  child: VideoPlayer(controller),
                ),
              )
            : const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
      ),
    );
  }
}
