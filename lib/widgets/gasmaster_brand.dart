import 'package:flutter/material.dart';

/// Compact GasMaster logo: pump icon in a circle + wordmark.
class GasMasterBrand extends StatelessWidget {
  final bool compact;

  const GasMasterBrand({super.key, this.compact = true});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final avatarRadius = compact ? 14.0 : 22.0;
    final iconSize = compact ? 16.0 : 24.0;
    final textStyle = compact
        ? theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          )
        : theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: avatarRadius,
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(
            Icons.local_gas_station,
            size: iconSize,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        SizedBox(width: compact ? 8 : 12),
        Text('GasMaster', style: textStyle),
      ],
    );
  }
}

/// AppBar title with brand row and optional screen subtitle below.
class GasMasterAppBarTitle extends StatelessWidget {
  final String? subtitle;

  const GasMasterAppBarTitle({super.key, this.subtitle});

  @override
  Widget build(BuildContext context) {
    if (subtitle == null || subtitle!.isEmpty) {
      return const GasMasterBrand(compact: true);
    }

    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const GasMasterBrand(compact: true),
        Text(
          subtitle!,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
