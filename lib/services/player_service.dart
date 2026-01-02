import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flick/models/song.dart';

/// Singleton service to manage global audio playback state.
class PlayerService {
  static final PlayerService _instance = PlayerService._internal();

  factory PlayerService() {
    return _instance;
  }

  PlayerService._internal() {
    _init();
  }

  final AudioPlayer _player = AudioPlayer();

  // State Notifiers
  final ValueNotifier<Song?> currentSongNotifier = ValueNotifier(null);
  final ValueNotifier<bool> isPlayingNotifier = ValueNotifier(false);
  final ValueNotifier<Duration> positionNotifier = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> durationNotifier = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> bufferedPositionNotifier = ValueNotifier(
    Duration.zero,
  );

  // Playback Mode State
  final ValueNotifier<bool> isShuffleNotifier = ValueNotifier(false);
  final ValueNotifier<LoopMode> loopModeNotifier = ValueNotifier(LoopMode.off);

  // Playlist Management
  final List<Song> _playlist = [];
  int _currentIndex = -1;

  void _init() {
    // Listen to player state
    _player.playerStateStream.listen((state) {
      isPlayingNotifier.value = state.playing;
      if (state.processingState == ProcessingState.completed) {
        _onSongFinished();
      }
    });

    // Listen to position updates
    _player.positionStream.listen((pos) {
      positionNotifier.value = pos;
    });

    // Listen to buffered position
    _player.bufferedPositionStream.listen((pos) {
      bufferedPositionNotifier.value = pos;
    });

    // Listen to duration changes
    _player.durationStream.listen((dur) {
      if (dur != null) {
        durationNotifier.value = dur;
      }
    });
  }

  Future<void> _onSongFinished() async {
    // Auto-advance logic
    if (loopModeNotifier.value == LoopMode.one) {
      if (currentSongNotifier.value != null) {
        await play(currentSongNotifier.value!);
      }
    } else {
      await next();
    }
  }

  /// Play a specific song.
  /// If [playlist] is provided, it replaces the current queue.
  Future<void> play(Song song, {List<Song>? playlist}) async {
    try {
      if (playlist != null) {
        _playlist.clear();
        _playlist.addAll(playlist);
        _currentIndex = _playlist.indexOf(song);
      } else {
        // If playing a standalone song not in current playlist, add it or just play it?
        // For simplicity, let's treat it as a single song playlist if queue is empty/desync.
        if (!_playlist.contains(song)) {
          _playlist.clear();
          _playlist.add(song);
          _currentIndex = 0;
        } else {
          _currentIndex = _playlist.indexOf(song);
        }
      }

      currentSongNotifier.value = song;

      // Reset duration/position for UI responsiveness
      positionNotifier.value = Duration.zero;
      durationNotifier.value = Duration.zero;

      if (song.filePath != null) {
        await _player.setAudioSource(
          AudioSource.uri(Uri.parse(song.filePath!)),
        );
        await _player.play();
      }
    } catch (e) {
      debugPrint("Error playing song: $e");
    }
  }

  Future<void> pause() async {
    await _player.pause();
  }

  Future<void> resume() async {
    await _player.play();
  }

  Future<void> togglePlayPause() async {
    if (isPlayingNotifier.value) {
      await pause();
    } else {
      await resume();
    }
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  Future<void> next() async {
    if (_playlist.isEmpty) return;

    if (_currentIndex < _playlist.length - 1) {
      _currentIndex++;
      await play(_playlist[_currentIndex]);
    } else if (loopModeNotifier.value == LoopMode.all) {
      _currentIndex = 0;
      await play(_playlist[_currentIndex]);
    } else {
      // End of playlist, stop or stay?
      // Let's stop
      await pause();
      await seek(Duration.zero);
    }
  }

  Future<void> previous() async {
    if (_playlist.isEmpty) return;

    // If more than 3 seconds in, restart song
    if (positionNotifier.value.inSeconds > 3) {
      await seek(Duration.zero);
    } else {
      if (_currentIndex > 0) {
        _currentIndex--;
        await play(_playlist[_currentIndex]);
      } else {
        // Wrap around if desired, or just restart first song
        await seek(Duration.zero);
      }
    }
  }

  // Shuffle/Loop Toggles
  void toggleShuffle() {
    final enable = !isShuffleNotifier.value;
    isShuffleNotifier.value = enable;

    if (enable) {
      // Enable shuffle: shuffle the current playlist (except current song stays first ideally, or just shuffle all)
      // For a proper shuffle, we should keep the current song playing.
      // A simple approach:
      final current = currentSongNotifier.value;
      if (current != null) {
        // Remove current, shuffle rest, put current back at 0?
        // Or just shuffle mostly.
        // Let's just shuffle the whole thing for now to keep it simple, finding new index.
        _playlist.shuffle();
        _currentIndex = _playlist.indexOf(current);
      } else {
        _playlist.shuffle();
      }
    } else {
      // Disable shuffle: Restore original order?
      // We didn't save original order in this simple implementation.
      // Enhancing this would require storing _originalPlaylist.
      // Let's sort by title as a fallback or just leave it as is (randomized order becomes new order).
      // User might expect it to revert.
      _playlist.sort((a, b) => a.title.compareTo(b.title));
      final current = currentSongNotifier.value;
      if (current != null) {
        _currentIndex = _playlist.indexOf(current);
      }
    }
  }

  void toggleLoopMode() {
    final modes = LoopMode.values;
    final nextIndex = (loopModeNotifier.value.index + 1) % modes.length;
    loopModeNotifier.value = modes[nextIndex];
  }

  void dispose() {
    _player.dispose();
    currentSongNotifier.dispose();
    isPlayingNotifier.dispose();
    positionNotifier.dispose();
    durationNotifier.dispose();
    bufferedPositionNotifier.dispose();
  }
}
