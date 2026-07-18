import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Brand asset paths under [assets/branding/].
abstract final class GasMasterBrandAssets {
  static const icon = 'assets/branding/icon.png';
  static const logo = 'assets/branding/logo.png';
  static const name = 'assets/branding/name.png';
}

/// Compact GasMaster wordmark or full logo for empty states.
class GasMasterBrand extends StatelessWidget {
  final bool compact;
  final VoidCallback? onTap;

  const GasMasterBrand({super.key, this.compact = true, this.onTap});

  @override
  Widget build(BuildContext context) {
    final image = compact
        ? Image.asset(
            GasMasterBrandAssets.name,
            height: 30,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          )
        : Image.asset(
            GasMasterBrandAssets.logo,
            height: 160,
            width: 280,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          );

    if (onTap == null) {
      return Semantics(label: 'GasMaster', child: image);
    }

    return Semantics(
      button: true,
      label: 'Home',
      child: Tooltip(
        message: 'Home',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: image,
          ),
        ),
      ),
    );
  }
}

/// Faded logo for use behind scrollable content (e.g. garage vehicle list).
class GasMasterWatermark extends StatelessWidget {
  const GasMasterWatermark({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final opacity = isDark ? 0.10 : 0.07;

    return IgnorePointer(
      child: Center(
        child: Opacity(
          opacity: opacity,
          child: Image.asset(
            GasMasterBrandAssets.logo,
            width: 280,
            height: 280,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
          ),
        ),
      ),
    );
  }
}

/// AppBar title with brand row and optional screen subtitle below.
class GasMasterAppBarTitle extends StatelessWidget {
  final String? subtitle;

  const GasMasterAppBarTitle({super.key, this.subtitle});

  void _onBrandTap(BuildContext context) {
    if (GoRouterState.of(context).uri.path == '/') return;
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final brand = GasMasterBrand(
      compact: true,
      onTap: () => _onBrandTap(context),
    );

    if (subtitle == null || subtitle!.isEmpty) {
      return brand;
    }

    final theme = Theme.of(context);
    // Expand to the AppBar title slot width so the subtitle isn't capped
    // by the intrinsic width of the brand wordmark image.
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          brand,
          Text(
            subtitle!,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            maxLines: 2,
            softWrap: true,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
