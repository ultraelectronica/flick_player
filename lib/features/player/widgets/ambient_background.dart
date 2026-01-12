import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flick/models/song.dart';

class AmbientBackground extends StatelessWidget {
  final Song? song;

  const AmbientBackground({super.key, this.song});

  @override
  Widget build(BuildContext context) {
    if (song?.albumArt == null) {
      return const SizedBox();
    }

    return RepaintBoundary(
      child: Stack(
        children: [
          // Brighter background image with increased opacity
          Positioned.fill(
            child: Image.file(
              File(song!.albumArt!),
              fit: BoxFit.cover,
              opacity: const AlwaysStoppedAnimation(0.6),
            ),
          ),
          // Blurred overlay - reduced sigma from 80 to 25 for better performance
          // Wrapped in RepaintBoundary to isolate expensive blur operations
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
              child: Container(color: Colors.black.withValues(alpha: 0.3)),
            ),
          ),
        ],
      ),
    );
  }
}
