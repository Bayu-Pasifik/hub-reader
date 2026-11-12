import 'package:flutter/material.dart';

import 'cover_image.dart';

/// Kartu seri untuk grid/daftar horizontal: sampul + judul + keterangan.
class SeriesCard extends StatelessWidget {
  const SeriesCard({
    super.key,
    required this.title,
    required this.coverUrl,
    this.subtitle,
    this.onTap,
    this.onLongPress,
    this.width,
  });

  final String title;
  final String? coverUrl;
  final String? subtitle;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            CoverImage(url: coverUrl),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}
