import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../theme/colors.dart';

class LiveScoreScreen extends StatefulWidget {
  final String? initialUrl;
  final String? title;

  const LiveScoreScreen({
    super.key,
    this.initialUrl,
    this.title,
  });

  @override
  State<LiveScoreScreen> createState() => _LiveScoreScreenState();
}

class _LiveScoreScreenState extends State<LiveScoreScreen> with SingleTickerProviderStateMixin {
  late final WebViewController _controller;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  
  bool _isLoading = true;
  int _progress = 0;
  String _selectedSource = 'ITF'; // 'ITF' or 'TENUP'

  final String _itfUrl = 'https://www.itftennis.com/en/itf-tours/beach-tennis-tour/';
  final String _tenupUrl = 'https://tenup.fft.fr/recherche/tournois';

  @override
  void initState() {
    super.initState();
    
    // Animation de pulsation du point LIVE
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    final url = widget.initialUrl ?? _itfUrl;
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0A0F1D))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (mounted) {
              setState(() {
                _progress = progress;
                _isLoading = progress < 100;
              });
            }
          },
          onPageStarted: (String url) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (String url) {
            if (mounted) setState(() => _isLoading = false);
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint("WebView error: ${error.description}");
          },
        ),
      )
      ..loadRequest(Uri.parse(url));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _switchSource(String source) {
    if (_selectedSource == source) return;
    setState(() {
      _selectedSource = source;
      _isLoading = true;
    });
    final url = source == 'ITF' ? _itfUrl : _tenupUrl;
    _controller.loadRequest(Uri.parse(url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0F1D),
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF334B),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF334B).withOpacity(0.8),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              widget.title ?? "Direct Scores & Tableaux",
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: -0.2),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: const Icon(Icons.refresh_rounded, color: AppColors.gold, size: 18),
            ),
            tooltip: "Actualiser",
            onPressed: () => _controller.reload(),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Column(
            children: [
              // Sélecteur de Source stylisé (ITF World Tour / FFT Ten'Up)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141D30),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _switchSource('ITF'),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              gradient: _selectedSource == 'ITF'
                                  ? const LinearGradient(colors: [Color(0xFFE8604C), Color(0xFFF4A535)])
                                  : null,
                              borderRadius: BorderRadius.circular(11),
                              boxShadow: _selectedSource == 'ITF'
                                  ? [
                                      BoxShadow(
                                        color: AppColors.coral.withOpacity(0.4),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text("🌍 ", style: TextStyle(fontSize: 13)),
                                Text(
                                  "ITF World Tour",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: _selectedSource == 'ITF' ? FontWeight.w900 : FontWeight.w500,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _switchSource('TENUP'),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              gradient: _selectedSource == 'TENUP'
                                  ? const LinearGradient(colors: [Color(0xFFE8604C), Color(0xFFF4A535)])
                                  : null,
                              borderRadius: BorderRadius.circular(11),
                              boxShadow: _selectedSource == 'TENUP'
                                  ? [
                                      BoxShadow(
                                        color: AppColors.coral.withOpacity(0.4),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text("🇫🇷 ", style: TextStyle(fontSize: 13)),
                                Text(
                                  "FFT Ten'Up",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: _selectedSource == 'TENUP' ? FontWeight.w900 : FontWeight.w500,
                                    fontSize: 12.5,
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
              if (_isLoading)
                LinearProgressIndicator(
                  value: _progress > 0 ? _progress / 100 : null,
                  backgroundColor: Colors.transparent,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.gold),
                  minHeight: 2.5,
                )
              else
                const SizedBox(height: 2.5),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading && _progress < 40)
            Container(
              color: const Color(0xFF0A0F1D),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.gold.withOpacity(0.3)),
                      ),
                      child: const CircularProgressIndicator(
                        color: AppColors.gold,
                        strokeWidth: 2.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _selectedSource == 'ITF' 
                          ? "Chargement de l'ITF Beach Tennis..."
                          : "Connexion à l'espace FFT Ten'Up...",
                      style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
