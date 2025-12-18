import 'package:isar/isar.dart';

import '../database.dart';
import '../../models/song.dart';

/// Repository for song CRUD operations.
class SongRepository {
  final Isar _isar;

  SongRepository({Isar? isar}) : _isar = isar ?? Database.instance;

  /// Get all songs ordered by title.
  Future<List<Song>> getAllSongs() async {
    final entities = await _isar.songEntitys.where().sortByTitle().findAll();
    return entities.map(_entityToSong).toList();
  }

  /// Get songs by folder URI.
  Future<List<Song>> getSongsByFolder(String folderUri) async {
    final entities = await _isar.songEntitys
        .filter()
        .folderUriEqualTo(folderUri)
        .sortByTitle()
        .findAll();
    return entities.map(_entityToSong).toList();
  }

  /// Search songs by title, artist, or album.
  Future<List<Song>> searchSongs(String query) async {
    final lowerQuery = query.toLowerCase();
    final entities = await _isar.songEntitys
        .filter()
        .titleContains(lowerQuery, caseSensitive: false)
        .or()
        .artistContains(lowerQuery, caseSensitive: false)
        .or()
        .albumContains(lowerQuery, caseSensitive: false)
        .sortByTitle()
        .findAll();
    return entities.map(_entityToSong).toList();
  }

  /// Get song count.
  Future<int> getSongCount() async {
    return await _isar.songEntitys.count();
  }

  /// Add or update a song.
  Future<void> upsertSong(SongEntity entity) async {
    await _isar.writeTxn(() async {
      // Check if song with same URI exists
      final existing = await _isar.songEntitys
          .filter()
          .uriEqualTo(entity.uri)
          .findFirst();

      if (existing != null) {
        entity.id = existing.id;
      }

      await _isar.songEntitys.put(entity);
    });
  }

  /// Add multiple songs in a batch.
  Future<void> upsertSongs(List<SongEntity> entities) async {
    await _isar.writeTxn(() async {
      for (final entity in entities) {
        final existing = await _isar.songEntitys
            .filter()
            .uriEqualTo(entity.uri)
            .findFirst();

        if (existing != null) {
          entity.id = existing.id;
        }
      }
      await _isar.songEntitys.putAll(entities);
    });
  }

  /// Delete a song by ID.
  Future<void> deleteSong(int id) async {
    await _isar.writeTxn(() async {
      await _isar.songEntitys.delete(id);
    });
  }

  /// Delete all songs for a specific folder.
  Future<void> deleteSongsForFolder(String folderUri) async {
    await _isar.writeTxn(() async {
      await _isar.songEntitys.filter().folderUriEqualTo(folderUri).deleteAll();
    });
  }

  /// Delete all songs.
  Future<void> deleteAllSongs() async {
    await _isar.writeTxn(() async {
      await _isar.songEntitys.clear();
    });
  }

  /// Watch for changes in the songs collection.
  Stream<void> watchSongs() {
    return _isar.songEntitys.watchLazy();
  }

  /// Convert entity to Song model.
  Song _entityToSong(SongEntity entity) {
    return Song(
      id: entity.id.toString(),
      title: entity.title,
      artist: entity.artist,
      albumArt: entity.albumArtUri,
      duration: Duration(milliseconds: entity.durationMs),
      fileType: entity.fileType,
      resolution: entity.resolution,
      album: entity.album,
      filePath: entity.uri,
    );
  }
}
