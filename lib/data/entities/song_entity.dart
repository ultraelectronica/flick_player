import 'package:isar/isar.dart';

part 'song_entity.g.dart';

/// Database entity for storing song metadata.
@collection
class SongEntity {
  Id id = Isar.autoIncrement;

  /// Content URI for the audio file
  @Index()
  late String uri;

  /// Song title (from metadata or filename)
  @Index(type: IndexType.value, caseSensitive: false)
  late String title;

  /// Artist name
  @Index(type: IndexType.value, caseSensitive: false)
  late String artist;

  /// Album name
  @Index(type: IndexType.value, caseSensitive: false)
  String? album;

  /// Path to album art (could be extracted embedded art or separate file)
  String? albumArtUri;

  /// Duration in milliseconds
  late int durationMs;

  /// File type/codec (e.g., "FLAC", "MP3", "WAV")
  late String fileType;

  /// Audio resolution (e.g., "24-bit/96kHz", "16-bit/44.1kHz")
  String? resolution;

  /// Bitrate in kbps
  int? bitrate;

  /// Sample rate in Hz
  int? sampleRate;

  /// Bit depth (e.g., 16, 24, 32)
  int? bitDepth;

  /// File size in bytes
  late int fileSize;

  /// Date the file was added to the library
  late DateTime dateAdded;

  /// Last modification time of the file
  DateTime? lastModified;

  /// Parent folder URI
  @Index()
  String? folderUri;

  /// Track number in album
  int? trackNumber;

  /// Year/date of release
  int? year;

  /// Genre
  String? genre;
}
