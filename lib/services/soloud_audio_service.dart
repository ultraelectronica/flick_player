import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart' as soloud;

/// Service that wraps flutter_soloud for gapless playback and crossfade.
///
/// This provides a clean Dart interface for SoLoud audio engine
/// which supports gapless playback and crossfade transitions.
class SoloudAudioService {
  static final SoloudAudioService _instance = SoloudAudioService._internal();

  factory SoloudAudioService() => _instance;

  SoloudAudioService._internal();

  // SoLoud instance
  late final soloud.SoLoud _soloud;

  // State notifiers for UI binding
  final ValueNotifier<SoloudPlaybackState> stateNotifier = ValueNotifier(
    SoloudPlaybackState.idle,
  );
  final ValueNotifier<Duration> positionNotifier = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> durationNotifier = ValueNotifier(Duration.zero);
  final ValueNotifier<double> bufferLevelNotifier = ValueNotifier(1.0);
  final ValueNotifier<double> volumeNotifier = ValueNotifier(1.0);
  final ValueNotifier<bool> crossfadeEnabledNotifier = ValueNotifier(false);
  final ValueNotifier<double> crossfadeDurationNotifier = ValueNotifier(3.0);
  final ValueNotifier<double> playbackSpeedNotifier = ValueNotifier(1.0);

  // Event callbacks
  void Function(String path)? onTrackEnded;
  void Function(String fromPath, String toPath)? onCrossfadeStarted;
  void Function(String path)? onNextTrackReady;
  void Function(String message)? onError;

  Timer? _progressTimer;
  Timer? _crossfadeTimer;
  bool _initialized = false;
  String? _currentPath;
  String? _nextPath;

  // Current and next audio sources for crossfade
  soloud.AudioSource? _currentSource;
  soloud.AudioSource? _nextSource;
  soloud.SoundHandle? _currentHandle;
  soloud.SoundHandle? _nextHandle;

  // Crossfade state
  bool _isCrossfading = false;
  double _crossfadeProgress = 0.0;

  // Track duration and position manually
  Duration? _trackDuration;
  DateTime? _playStartTime;
  Duration _manualPosition = Duration.zero;

  /// Check if native audio engine is available on this platform.
  bool get isNativeAvailable => true; // SoLoud works on all platforms

  /// Initialize the SoLoud audio engine.
  /// Must be called once at app startup.
  /// Returns true if initialization succeeded.
  Future<bool> init() async {
    if (_initialized) return true;

    try {
      _soloud = soloud.SoLoud.instance;
      await _soloud.init();
      _initialized = true;
      debugPrint('SoLoud audio engine initialized');

      // Start progress updates
      _startProgressUpdates();
      return true;
    } catch (e) {
      debugPrint('Failed to initialize SoLoud audio engine: $e');
      return false;
    }
  }

  /// Check if the engine is initialized.
  bool get isInitialized => _initialized;

  /// Get the current playback state.
  SoloudPlaybackState get state => stateNotifier.value;

  /// Get whether audio is currently playing.
  bool get isPlaying =>
      stateNotifier.value == SoloudPlaybackState.playing ||
      stateNotifier.value == SoloudPlaybackState.crossfading;

  /// Get the current track path.
  String? get currentPath => _currentPath;

  /// Set the track duration (should be called before or after play).
  void setTrackDuration(Duration duration) {
    _trackDuration = duration;
    durationNotifier.value = duration;
  }

  /// Play an audio file.
  Future<void> play(String path) async {
    if (!_initialized) {
      throw StateError('SoLoud audio engine not initialized');
    }

    try {
      // Stop any current playback
      if (_currentHandle != null) {
        await _soloud.stop(_currentHandle!);
        _currentHandle = null;
      }
      if (_nextHandle != null) {
        await _soloud.stop(_nextHandle!);
        _nextHandle = null;
      }

      // Load and play the new track
      _currentSource = await _soloud.loadFile(path);
      _currentPath = path;

      // Duration will be tracked manually or from metadata
      _trackDuration = null; // Will be set when available

      _currentHandle = await _soloud.play(
        _currentSource!,
        volume: volumeNotifier.value,
        looping: false,
      );

      _playStartTime = DateTime.now();
      _manualPosition = Duration.zero;
      stateNotifier.value = SoloudPlaybackState.playing;
      _startProgressUpdates();
    } catch (e) {
      debugPrint('Error playing track: $e');
      onError?.call('Failed to play track: $e');
      rethrow;
    }
  }

  /// Queue the next track for gapless playback.
  /// The next track will automatically start when the current one ends.
  Future<void> queueNext(String path) async {
    if (!_initialized) {
      throw StateError('SoLoud audio engine not initialized');
    }

    try {
      // Preload the next track
      _nextPath = path;
      _nextSource = await _soloud.loadFile(path);
      onNextTrackReady?.call(path);
      debugPrint('Queued next track for gapless playback: $path');
    } catch (e) {
      debugPrint('Error queueing next track: $e');
      onError?.call('Failed to queue next track: $e');
    }
  }

  /// Pause playback.
  Future<void> pause() async {
    if (!_initialized) return;

    if (_currentHandle != null) {
      _soloud.setPause(_currentHandle!, true);
      stateNotifier.value = SoloudPlaybackState.paused;
    }
    if (_nextHandle != null) {
      _soloud.setPause(_nextHandle!, true);
    }
  }

  /// Resume playback.
  Future<void> resume() async {
    if (!_initialized) return;

    if (_currentHandle != null) {
      _soloud.setPause(_currentHandle!, false);
      // Reset play start time to account for pause
      _playStartTime = DateTime.now().subtract(_manualPosition);
      stateNotifier.value = SoloudPlaybackState.playing;
      _startProgressUpdates();
    }
    if (_nextHandle != null) {
      _soloud.setPause(_nextHandle!, false);
    }
  }

  /// Stop playback completely.
  Future<void> stop() async {
    if (!_initialized) return;

    if (_currentHandle != null) {
      _soloud.stop(_currentHandle!);
      _currentHandle = null;
    }
    if (_nextHandle != null) {
      _soloud.stop(_nextHandle!);
      _nextHandle = null;
    }

    _currentSource = null;
    _nextSource = null;
    _currentPath = null;
    _nextPath = null;
    _isCrossfading = false;
    _crossfadeProgress = 0.0;
    _trackDuration = null;
    _playStartTime = null;
    _manualPosition = Duration.zero;

    _stopProgressUpdates();
    stateNotifier.value = SoloudPlaybackState.stopped;
  }

  /// Seek to a position in seconds.
  Future<void> seek(Duration position) async {
    if (!_initialized) return;
    if (_currentHandle == null) return;

    try {
      _soloud.seek(_currentHandle!, position);
    } catch (e) {
      debugPrint('Error seeking: $e');
    }
  }

  /// Set the volume (0.0 to 1.0).
  Future<void> setVolume(double volume) async {
    if (!_initialized) return;
    final clampedVolume = volume.clamp(0.0, 1.0);
    volumeNotifier.value = clampedVolume;

    if (_currentHandle != null) {
      _soloud.setVolume(_currentHandle!, clampedVolume);
    }
    if (_nextHandle != null) {
      _soloud.setVolume(_nextHandle!, clampedVolume);
    }
  }

  /// Enable or disable crossfade.
  Future<void> setCrossfade({
    required bool enabled,
    double? durationSecs,
  }) async {
    if (!_initialized) return;

    crossfadeEnabledNotifier.value = enabled;
    if (durationSecs != null) {
      crossfadeDurationNotifier.value = durationSecs;
    }
  }

  /// Skip to the next queued track (with crossfade if enabled).
  Future<void> skipToNext() async {
    if (!_initialized) return;
    if (_nextSource == null || _nextPath == null) return;

    if (crossfadeEnabledNotifier.value && _currentHandle != null) {
      await _crossfadeToNext();
    } else {
      await _gaplessTransitionToNext();
    }
  }

  /// Set the playback speed (0.5 to 2.0).
  Future<void> setPlaybackSpeed(double speed) async {
    if (!_initialized) return;
    final clampedSpeed = speed.clamp(0.5, 2.0);
    playbackSpeedNotifier.value = clampedSpeed;

    if (_currentHandle != null) {
      _soloud.setRelativePlaySpeed(_currentHandle!, clampedSpeed);
    }
    if (_nextHandle != null) {
      _soloud.setRelativePlaySpeed(_nextHandle!, clampedSpeed);
    }
  }

  /// Get the current playback speed.
  double getPlaybackSpeed() {
    if (!_initialized) return 1.0;
    return playbackSpeedNotifier.value;
  }

  /// Get the sample rate of the audio engine.
  int? getSampleRate() {
    if (!_initialized) return null;
    // SoLoud default sample rate is typically 44100
    return 44100;
  }

  /// Get the number of audio channels.
  int? getChannels() {
    if (!_initialized) return null;
    // SoLoud default is stereo
    return 2;
  }

  /// Shutdown the audio engine.
  Future<void> shutdown() async {
    if (!_initialized) return;

    await stop();
    _stopProgressUpdates();
    _stopCrossfadeTimer();
    _initialized = false;
  }

  /// Start periodic progress updates.
  void _startProgressUpdates() {
    _stopProgressUpdates();

    // Update progress every 50ms for smooth UI updates
    _progressTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      _updateProgress();
    });
  }

  /// Stop progress updates.
  void _stopProgressUpdates() {
    _progressTimer?.cancel();
    _progressTimer = null;
  }

  /// Update progress from SoLoud.
  void _updateProgress() {
    if (!_initialized || _currentHandle == null || _playStartTime == null) {
      return;
    }

    try {
      // Track position manually based on elapsed time
      final elapsed = DateTime.now().difference(_playStartTime!);
      _manualPosition = elapsed;
      positionNotifier.value = _manualPosition;

      // Use stored duration (will be set from song metadata)
      if (_trackDuration != null) {
        durationNotifier.value = _trackDuration!;

        // Check if track is ending and we have a next track queued
        final remaining = _trackDuration! - _manualPosition;
        final remainingSeconds = remaining.inSeconds.toDouble();
        final crossfadeDuration = crossfadeDurationNotifier.value;

        // Start crossfade or gapless transition when track is about to end
        if (_nextSource != null && _nextPath != null && !_isCrossfading) {
          if (crossfadeEnabledNotifier.value &&
              remainingSeconds <= crossfadeDuration &&
              remainingSeconds > 0) {
            // Start crossfade
            _crossfadeToNext();
          } else if (!crossfadeEnabledNotifier.value &&
              remainingSeconds <= 0.1 &&
              remainingSeconds > 0) {
            // Gapless transition
            _gaplessTransitionToNext();
          }
        }

        // Check if track ended
        if (_manualPosition >= _trackDuration!) {
          _onTrackEnded(_currentPath ?? '');
        }
      }
      // Note: Duration will need to be set from song metadata or file info
      // This will be handled by the PlayerService when calling play()

      bufferLevelNotifier.value = 1.0; // SoLoud handles buffering internally
    } catch (e) {
      debugPrint('Error updating progress: $e');
    }
  }

  /// Perform gapless transition to next track.
  Future<void> _gaplessTransitionToNext() async {
    if (_nextSource == null || _nextPath == null) return;

    final oldPath = _currentPath;
    _currentPath = _nextPath;
    _nextPath = null;

    // Stop current track
    if (_currentHandle != null) {
      _soloud.stop(_currentHandle!);
    }

    // Start next track immediately
    _currentSource = _nextSource;
    _nextSource = null;
    // Duration will be set from song metadata
    _trackDuration = null;
    _currentHandle = await _soloud.play(
      _currentSource!,
      volume: volumeNotifier.value,
      looping: false,
    );

    _playStartTime = DateTime.now();
    _manualPosition = Duration.zero;

    if (oldPath != null) {
      onTrackEnded?.call(oldPath);
    }
  }

  /// Perform crossfade transition to next track.
  Future<void> _crossfadeToNext() async {
    if (_nextSource == null || _nextPath == null || _isCrossfading) return;
    if (_currentHandle == null) return;

    _isCrossfading = true;
    stateNotifier.value = SoloudPlaybackState.crossfading;

    final oldPath = _currentPath;
    final fadeDuration = crossfadeDurationNotifier.value;

    // Start next track at volume 0
    _nextHandle = await _soloud.play(_nextSource!, volume: 0.0, looping: false);

    // Fade out current, fade in next
    final fadeDurationObj = Duration(seconds: fadeDuration.round());
    _soloud.fadeVolume(_currentHandle!, 0.0, fadeDurationObj);
    _soloud.fadeVolume(_nextHandle!, volumeNotifier.value, fadeDurationObj);

    onCrossfadeStarted?.call(oldPath ?? '', _nextPath!);

    // Start crossfade timer to complete transition
    _startCrossfadeTimer(fadeDuration, oldPath);
  }

  /// Start crossfade timer to complete transition.
  void _startCrossfadeTimer(double duration, String? oldPath) {
    _stopCrossfadeTimer();

    _crossfadeProgress = 0.0;
    final startTime = DateTime.now();

    _crossfadeTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      final elapsed =
          DateTime.now().difference(startTime).inMilliseconds / 1000.0;
      _crossfadeProgress = (elapsed / duration).clamp(0.0, 1.0);

      if (_crossfadeProgress >= 1.0) {
        timer.cancel();
        _completeCrossfade(oldPath);
      }
    });
  }

  /// Complete the crossfade transition.
  void _completeCrossfade(String? oldPath) {
    if (_nextHandle == null || _nextSource == null || _nextPath == null) return;

    // Stop old track
    if (_currentHandle != null) {
      _soloud.stop(_currentHandle!);
      // Dispose the old source
      if (_currentSource != null) {
        _soloud.disposeSource(_currentSource!);
      }
    }

    // Switch to next track
    _currentHandle = _nextHandle;
    _currentSource = _nextSource;
    _currentPath = _nextPath;
    // Duration will be set from song metadata
    _trackDuration = null;
    _nextHandle = null;
    _nextSource = null;
    _nextPath = null;
    _isCrossfading = false;
    _crossfadeProgress = 0.0;

    _playStartTime = DateTime.now();
    _manualPosition = Duration.zero;

    stateNotifier.value = SoloudPlaybackState.playing;

    if (oldPath != null) {
      onTrackEnded?.call(oldPath);
    }
  }

  /// Stop crossfade timer.
  void _stopCrossfadeTimer() {
    _crossfadeTimer?.cancel();
    _crossfadeTimer = null;
  }

  /// Handle track ended event.
  void _onTrackEnded(String path) {
    if (_nextSource != null && _nextPath != null) {
      // Auto-transition to next track
      if (crossfadeEnabledNotifier.value) {
        _crossfadeToNext();
      } else {
        _gaplessTransitionToNext();
      }
    } else {
      onTrackEnded?.call(path);
    }
  }

  /// Dispose resources.
  void dispose() {
    shutdown();
    _stopProgressUpdates();
    _stopCrossfadeTimer();
    stateNotifier.dispose();
    positionNotifier.dispose();
    durationNotifier.dispose();
    bufferLevelNotifier.dispose();
    volumeNotifier.dispose();
    crossfadeEnabledNotifier.dispose();
    crossfadeDurationNotifier.dispose();
    playbackSpeedNotifier.dispose();
  }
}

/// Playback state enum for SoLoud.
enum SoloudPlaybackState {
  idle,
  playing,
  paused,
  buffering,
  crossfading,
  stopped,
}
