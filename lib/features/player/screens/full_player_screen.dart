import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:ui';
import 'package:flick/core/theme/app_colors.dart';
import 'package:flick/models/song.dart';
import 'package:flick/services/player_service.dart';
import 'package:flick/features/player/widgets/waveform_seek_bar.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:just_audio/just_audio.dart';

class FullPlayerScreen extends StatefulWidget {
  final Object heroTag;
  const FullPlayerScreen({super.key, this.heroTag = 'album_art_hero'});

  @override
  State<FullPlayerScreen> createState() => _FullPlayerScreenState();
}

class _FullPlayerScreenState extends State<FullPlayerScreen> {
  final PlayerService _playerService = PlayerService();

  // For nice time formatting (mm:ss)
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: ValueListenableBuilder<Song?>(
        valueListenable: _playerService.currentSongNotifier,
        builder: (context, song, _) {
          if (song == null) {
            // Should usually close the screen if song becomes null or error
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.of(context).pop();
            });
            return const SizedBox.shrink();
          }

          return Dismissible(
            key: const Key('full_player_dismiss'),
            direction: DismissDirection.down,
            onDismissed: (_) {
              Navigator.of(context).pop();
            },
            child: GestureDetector(
              onHorizontalDragEnd: (details) {
                if (details.primaryVelocity! < -500) {
                  // Swipe Left -> Next
                  _playerService.next();
                } else if (details.primaryVelocity! > 500) {
                  // Swipe Right -> Previous
                  _playerService.previous();
                }
              },
              child: Stack(
                children: [
                  // Ambient background using album art blur
                  if (song.albumArt != null)
                    Positioned.fill(
                      child: Image.file(
                        File(song.albumArt!),
                        fit: BoxFit.cover,
                        opacity: const AlwaysStoppedAnimation(0.3),
                      ),
                    ),
                  Positioned.fill(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                      child: Container(
                        color: AppColors.background.withValues(alpha: 0.8),
                      ),
                    ),
                  ),

                  SafeArea(
                    child: Column(
                      children: [
                        // Top Bar
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(
                                  LucideIcons.chevronDown,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const Text(
                                "Now Playing",
                                style: TextStyle(
                                  fontFamily: 'ProductSans',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                  letterSpacing: 1,
                                ),
                              ),
                              IconButton(
                                onPressed: () {}, // Options menu
                                icon: const Icon(
                                  Icons.more_vert,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const Spacer(),

                        // Hero Album Art
                        Hero(
                          tag: widget.heroTag,
                          child: Container(
                            width: MediaQuery.of(context).size.width * 0.85,
                            height: MediaQuery.of(context).size.width * 0.85,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(40),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 32,
                                  offset: const Offset(0, 16),
                                ),
                              ],
                              image: song.albumArt != null
                                  ? DecorationImage(
                                      image: FileImage(File(song.albumArt!)),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: song.albumArt == null
                                ? Container(
                                    decoration: BoxDecoration(
                                      color: AppColors.glassBackgroundStrong,
                                      borderRadius: BorderRadius.circular(40),
                                    ),
                                    child: const Icon(
                                      LucideIcons.music,
                                      size: 80,
                                      color: AppColors.textTertiary,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 48),
                        // Metadata
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Column(
                            children: [
                              Text(
                                song.title,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontFamily: 'ProductSans',
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                song.artist,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontFamily: 'ProductSans',
                                  fontSize: 16,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const Spacer(),

                        const Spacer(),

                        // Scrolling Waveform & Controls
                        SizedBox(
                          height: 160,
                          child: Stack(
                            children: [
                              // Waveform Layer
                              Positioned.fill(
                                child: ValueListenableBuilder<Duration>(
                                  valueListenable:
                                      _playerService.positionNotifier,
                                  builder: (context, position, _) {
                                    return ValueListenableBuilder<Duration>(
                                      valueListenable:
                                          _playerService.durationNotifier,
                                      builder: (context, duration, _) {
                                        if (duration.inMilliseconds == 0) {
                                          return const SizedBox();
                                        }

                                        final screenWidth = MediaQuery.of(
                                          context,
                                        ).size.width;
                                        final waveWidth = screenWidth * 4;
                                        final progress =
                                            position.inMilliseconds /
                                            duration.inMilliseconds;
                                        // Center the playhead
                                        final offset =
                                            -(progress * waveWidth) +
                                            (screenWidth / 2);

                                        return ClipRect(
                                          child: OverflowBox(
                                            maxWidth: waveWidth,
                                            minWidth: waveWidth,
                                            alignment: Alignment.centerLeft,
                                            child: Transform.translate(
                                              offset: Offset(offset, 0),
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(
                                                  vertical: 10,
                                                ), // Padding for controls space
                                                child: WaveformSeekBar(
                                                  barCount: 300,
                                                  position: position,
                                                  duration: duration,
                                                  onChanged: (newPos) {
                                                    // Seeking on a scrolling waveform is tricky visually
                                                    // Standard seek might feel weird if it jumps
                                                    _playerService.seek(newPos);
                                                  },
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),

                              // Controls Layer (Overlay)
                              Center(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(50),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(
                                      sigmaX: 16,
                                      sigmaY: 16,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      color: const Color(
                                        0xFF121212,
                                      ).withValues(alpha: 0.6),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        children: [
                                          // Shuffle
                                          ValueListenableBuilder<bool>(
                                            valueListenable: _playerService
                                                .isShuffleNotifier,
                                            builder: (context, isShuffle, _) {
                                              return IconButton(
                                                onPressed: () => _playerService
                                                    .toggleShuffle(),
                                                icon: Icon(
                                                  LucideIcons.shuffle,
                                                  size: 20,
                                                  color: isShuffle
                                                      ? AppColors.accent
                                                      : AppColors.textTertiary,
                                                ),
                                              );
                                            },
                                          ),

                                          // Previous
                                          IconButton(
                                            onPressed: () =>
                                                _playerService.previous(),
                                            iconSize: 28,
                                            icon: const Icon(
                                              LucideIcons.skipBack,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),

                                          // Play/Pause
                                          ValueListenableBuilder<bool>(
                                            valueListenable: _playerService
                                                .isPlayingNotifier,
                                            builder: (context, isPlaying, _) {
                                              return Container(
                                                width: 64,
                                                height: 64,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: AppColors.accent,
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: AppColors.accent
                                                          .withValues(
                                                            alpha: 0.4,
                                                          ),
                                                      blurRadius: 24,
                                                      offset: const Offset(
                                                        0,
                                                        8,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                child: IconButton(
                                                  onPressed: () =>
                                                      _playerService
                                                          .togglePlayPause(),
                                                  iconSize: 28,
                                                  icon: Icon(
                                                    isPlaying
                                                        ? LucideIcons.pause
                                                        : LucideIcons.play,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),

                                          // Next
                                          IconButton(
                                            onPressed: () =>
                                                _playerService.next(),
                                            iconSize: 28,
                                            icon: const Icon(
                                              LucideIcons.skipForward,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),

                                          // Loop
                                          ValueListenableBuilder<LoopMode>(
                                            valueListenable:
                                                _playerService.loopModeNotifier,
                                            builder: (context, loopMode, _) {
                                              IconData icon;
                                              Color color;
                                              switch (loopMode) {
                                                case LoopMode.off:
                                                  icon = LucideIcons.repeat;
                                                  color =
                                                      AppColors.textTertiary;
                                                  break;
                                                case LoopMode.all:
                                                  icon = LucideIcons.repeat;
                                                  color = AppColors.accent;
                                                  break;
                                                case LoopMode.one:
                                                  icon = LucideIcons.repeat1;
                                                  color = AppColors.accent;
                                                  break;
                                              }
                                              return IconButton(
                                                onPressed: () => _playerService
                                                    .toggleLoopMode(),
                                                icon: Icon(
                                                  icon,
                                                  size: 20,
                                                  color: color,
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              // Time Labels
                              Positioned(
                                bottom: 8,
                                left: 24,
                                right: 24,
                                child: ValueListenableBuilder<Duration>(
                                  valueListenable:
                                      _playerService.positionNotifier,
                                  builder: (context, position, _) {
                                    return ValueListenableBuilder<Duration>(
                                      valueListenable:
                                          _playerService.durationNotifier,
                                      builder: (context, duration, _) {
                                        return Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              _formatDuration(position),
                                              style: const TextStyle(
                                                fontFamily: 'ProductSans',
                                                fontSize: 12,
                                                color: AppColors.textTertiary,
                                                fontFeatures: [
                                                  FontFeature.tabularFigures(),
                                                ],
                                              ),
                                            ),
                                            Text(
                                              _formatDuration(duration),
                                              style: const TextStyle(
                                                fontFamily: 'ProductSans',
                                                fontSize: 12,
                                                color: AppColors.textTertiary,
                                                fontFeatures: [
                                                  FontFeature.tabularFigures(),
                                                ],
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
