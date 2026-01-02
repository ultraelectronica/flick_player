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
  const FullPlayerScreen({super.key});

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
                          tag: 'album_art_hero',
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 48,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
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
                                      color: AppColors.glassBackgroundStrong,
                                      child: const Icon(
                                        LucideIcons.music,
                                        size: 64,
                                        color: AppColors.textTertiary,
                                      ),
                                    )
                                  : null,
                            ),
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

                        // Waveform Seek Bar
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: ValueListenableBuilder<Duration>(
                            valueListenable: _playerService.positionNotifier,
                            builder: (context, position, _) {
                              return ValueListenableBuilder<Duration>(
                                valueListenable:
                                    _playerService.durationNotifier,
                                builder: (context, duration, _) {
                                  return Column(
                                    children: [
                                      WaveformSeekBar(
                                        position: position,
                                        duration: duration,
                                        onChanged: (newPos) {
                                          _playerService.seek(newPos);
                                        },
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
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
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Controls
                        Padding(
                          padding: const EdgeInsets.only(bottom: 48),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              // Shuffle Button
                              ValueListenableBuilder<bool>(
                                valueListenable:
                                    _playerService.isShuffleNotifier,
                                builder: (context, isShuffle, _) {
                                  return IconButton(
                                    onPressed: () =>
                                        _playerService.toggleShuffle(),
                                    icon: Icon(
                                      LucideIcons.shuffle,
                                      color: isShuffle
                                          ? AppColors.accent
                                          : AppColors.textTertiary,
                                    ),
                                  );
                                },
                              ),

                              IconButton(
                                onPressed: () => _playerService.previous(),
                                iconSize: 32,
                                icon: const Icon(
                                  LucideIcons.skipBack,
                                  color: AppColors.textPrimary,
                                ),
                              ),

                              // Play/Pause Big Button
                              ValueListenableBuilder<bool>(
                                valueListenable:
                                    _playerService.isPlayingNotifier,
                                builder: (context, isPlaying, _) {
                                  return Container(
                                    width: 72,
                                    height: 72,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.accent,
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.accent.withValues(
                                            alpha: 0.4,
                                          ),
                                          blurRadius: 24,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: IconButton(
                                      onPressed: () =>
                                          _playerService.togglePlayPause(),
                                      iconSize: 32,
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

                              IconButton(
                                onPressed: () => _playerService.next(),
                                iconSize: 32,
                                icon: const Icon(
                                  LucideIcons.skipForward,
                                  color: AppColors.textPrimary,
                                ),
                              ),

                              // Loop Button
                              ValueListenableBuilder<LoopMode>(
                                valueListenable:
                                    _playerService.loopModeNotifier,
                                builder: (context, loopMode, _) {
                                  IconData icon;
                                  Color color;
                                  switch (loopMode) {
                                    case LoopMode.off:
                                      icon = LucideIcons.repeat;
                                      color = AppColors.textTertiary;
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
                                    onPressed: () =>
                                        _playerService.toggleLoopMode(),
                                    icon: Icon(icon, color: color),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
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
