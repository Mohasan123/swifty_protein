import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import '../models/ligand.dart';

/// Thrown for any ligand fetch/parse failure, with a user-friendly message.
class LigandException implements Exception {
  final String message;
  const LigandException(this.message);
  @override
  String toString() => message;
}

class LigandService {
  static const _baseUrl = 'https://files.rcsb.org/ligands/view';
  static const _timeout = Duration(seconds: 15);
  static const _listAssetPath = 'assets/ligands.txt';

  // Simple in-memory cache so re-opening a ligand is instant.
  final Map<String, Ligand> _cache = {};

  /// Loads the bundled list of ligand IDs (one per line) from assets/ligands.txt
  Future<List<String>> loadLigandList() async {
    final raw = await rootBundle.loadString(_listAssetPath);
    return raw
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
  }

  /// Fetches and parses a single ligand's .cif file from RCSB.
  /// Throws [LigandException] with a user-friendly message on any failure.
  Future<Ligand> fetchLigand(String ligandId) async {
    final cached = _cache[ligandId];
    if (cached != null) return cached;

    final http.Response response;
    try {
      final uri = Uri.parse('$_baseUrl/$ligandId.cif');
      response = await http.get(uri).timeout(_timeout);
    } on http.ClientException {
      throw const LigandException('No internet connection. Please check your network.');
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw const LigandException('Request timeout. Please try again.');
      }
      throw const LigandException('An unexpected network error occurred.');
    }

    if (response.statusCode == 404) {
      throw const LigandException(
          'Ligand not found (404). This ligand may not exist in the database.');
    }
    if (response.statusCode != 200) {
      throw LigandException('Server error (${response.statusCode}). Please try again.');
    }

    final Ligand ligand;
    try {
      ligand = CifParser.parse(ligandId, response.body);
    } catch (_) {
      throw const LigandException('Failed to parse ligand data. The file may be corrupted.');
    }

    if (ligand.atoms.isEmpty) {
      throw const LigandException('Failed to parse ligand data. No atoms found in the file.');
    }

    _cache[ligandId] = ligand;
    return ligand;
  }

  void clearCache() => _cache.clear();
}
