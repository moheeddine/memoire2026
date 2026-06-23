import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ─── PROMO IMAGE GALLERY ──────────────────────────────────────────────────────
//
// Swipeable gallery that fills its parent box entirely.
//
// Usage — standalone (bounded height required):
//   SizedBox(height: 260, child: PromoImageGallery(imageUrls: urls))
//
// Usage — inside FlexibleSpaceBar (SliverAppBar provides the bounds):
//   FlexibleSpaceBar(background: PromoImageGallery(imageUrls: urls))
//
// Tapping any image opens a fullscreen viewer with pinch-to-zoom.

class PromoImageGallery extends StatefulWidget {
  final List<String> imageUrls;

  const PromoImageGallery({super.key, required this.imageUrls});

  @override
  State<PromoImageGallery> createState() => _PromoImageGalleryState();
}

class _PromoImageGalleryState extends State<PromoImageGallery> {
  int _current = 0;
  late final PageController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = PageController();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.imageUrls;

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Swipeable pages ────────────────────────────────────────────────
        PageView.builder(
          controller:    _ctrl,
          itemCount:     urls.length,
          onPageChanged: (i) => setState(() => _current = i),
          itemBuilder:   (_, i) => GestureDetector(
            onTap: () => _openFullscreen(context, i),
            child: Image.network(
              urls[i],
              fit: BoxFit.cover,
              loadingBuilder: (_, child, progress) =>
                  progress == null ? child : const _GalleryPlaceholder(),
              errorBuilder: (_, __, ___) => const _GalleryErrorTile(),
            ),
          ),
        ),

        // ── Bottom gradient (helps legibility of overlaid badges) ──────────
        Positioned(
          left: 0, right: 0, bottom: 0,
          child: Container(
            height: 110,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end:   Alignment.topCenter,
                colors: [Colors.black54, Colors.transparent],
              ),
            ),
          ),
        ),

        // ── Page counter badge (bottom-right, above dots) ──────────────────
        if (urls.length > 1)
          Positioned(
            bottom: 36, right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_current + 1} / ${urls.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

        // ── Dot indicators (bottom-center) ─────────────────────────────────
        if (urls.length > 1)
          Positioned(
            bottom: 14, left: 0, right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                urls.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width:  _current == i ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _current == i
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _openFullscreen(BuildContext context, int index) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _FullscreenGallery(
          imageUrls:    widget.imageUrls,
          initialIndex: index,
        ),
      ),
    );
  }
}

// ─── FULLSCREEN GALLERY ───────────────────────────────────────────────────────

class _FullscreenGallery extends StatefulWidget {
  final List<String> imageUrls;
  final int          initialIndex;

  const _FullscreenGallery({
    required this.imageUrls,
    required this.initialIndex,
  });

  @override
  State<_FullscreenGallery> createState() => _FullscreenGalleryState();
}

class _FullscreenGalleryState extends State<_FullscreenGallery> {
  late int            _current;
  late PageController _ctrl;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _ctrl    = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation:       0,
        leading: IconButton(
          icon:      const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: widget.imageUrls.length > 1
            ? Text(
                '${_current + 1} / ${widget.imageUrls.length}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              )
            : null,
        centerTitle: true,
      ),
      body: PageView.builder(
        controller:    _ctrl,
        itemCount:     widget.imageUrls.length,
        onPageChanged: (i) => setState(() => _current = i),
        itemBuilder:   (_, i) => InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Center(
            child: Image.network(
              widget.imageUrls[i],
              fit: BoxFit.contain,
              loadingBuilder: (_, child, progress) => progress == null
                  ? child
                  : const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary, strokeWidth: 2),
                    ),
              errorBuilder: (_, __, ___) => const Icon(
                Icons.broken_image_rounded,
                color: Colors.white30,
                size: 64,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── PLACEHOLDER WIDGETS ─────────────────────────────────────────────────────

class _GalleryPlaceholder extends StatelessWidget {
  const _GalleryPlaceholder();

  @override
  Widget build(BuildContext context) => Container(
        color: AppColors.surface,
        child: const Center(
          child: CircularProgressIndicator(
              color: AppColors.primary, strokeWidth: 2.5),
        ),
      );
}

class _GalleryErrorTile extends StatelessWidget {
  const _GalleryErrorTile();

  @override
  Widget build(BuildContext context) => Container(
        color: AppColors.surface,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.broken_image_outlined,
                color: AppColors.textLight, size: 36),
            SizedBox(height: 8),
            Text(
              'Image non disponible',
              style: TextStyle(color: AppColors.textLight, fontSize: 12),
            ),
          ],
        ),
      );
}
