import 'dart:math';

/// Represents a single atom in a ligand
class Atom {
  final String id;
  final String element;
  final double x;
  final double y;
  final double z;
  final String? name;

  const Atom({
    required this.id,
    required this.element,
    required this.x,
    required this.y,
    required this.z,
    this.name,
  });

  /// CPK color hex for this element
  String get cpkColor {
    switch (element.toUpperCase()) {
      case 'H':  return '#FFFFFF';
      case 'C':  return '#404040';
      case 'N':  return '#3050F8';
      case 'O':  return '#FF0D0D';
      case 'F':  return '#90E050';
      case 'CL': return '#1FF01F';
      case 'BR': return '#A62929';
      case 'I':  return '#940094';
      case 'S':  return '#FFFF30';
      case 'P':  return '#FF8000';
      case 'FE': return '#E06633';
      case 'ZN': return '#7D80B0';
      case 'MG': return '#8AFF00';
      case 'CA': return '#3DFF00';
      case 'NA': return '#AB5CF2';
      case 'K':  return '#8F40D4';
      case 'MN': return '#9C7AC7';
      case 'CU': return '#C88033';
      case 'CO': return '#F090A0';
      case 'NI': return '#50D050';
      default:   return '#BEA06E'; // generic
    }
  }

  /// Van der Waals radius for space-fill model
  double get vdwRadius {
    switch (element.toUpperCase()) {
      case 'H':  return 1.20;
      case 'C':  return 1.70;
      case 'N':  return 1.55;
      case 'O':  return 1.52;
      case 'F':  return 1.47;
      case 'S':  return 1.80;
      case 'P':  return 1.80;
      case 'CL': return 1.75;
      case 'BR': return 1.85;
      case 'I':  return 1.98;
      default:   return 1.70;
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'element': element,
    'x': x,
    'y': y,
    'z': z,
    'name': name ?? id,
    'color': cpkColor,
    'vdwRadius': vdwRadius,
  };
}

/// Represents a bond between two atoms
class Bond {
  final String atom1Id;
  final String atom2Id;
  final String order; // SING, DOUB, TRIP, AROM

  const Bond({
    required this.atom1Id,
    required this.atom2Id,
    required this.order,
  });

  Map<String, dynamic> toJson() => {
    'atom1': atom1Id,
    'atom2': atom2Id,
    'order': order,
  };
}

/// Parsed ligand data
class Ligand {
  final String id;
  final List<Atom> atoms;
  final List<Bond> bonds;
  final String? name;
  final String? formula;

  const Ligand({
    required this.id,
    required this.atoms,
    required this.bonds,
    this.name,
    this.formula,
  });

  int get atomCount => atoms.length;
  int get bondCount => bonds.length;
}

/// Parses RCSB .cif files for ligand structures
class CifParser {
  static Ligand parse(String ligandId, String cifContent) {
    final lines = cifContent.split('\n');

    String? name;
    String? formula;
    final atoms = <Atom>[];
    final bonds = <Bond>[];

    // Extract simple key-value fields
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('_chem_comp.name')) {
        name = _extractValue(trimmed);
      } else if (trimmed.startsWith('_chem_comp.formula ')) {
        formula = _extractValue(trimmed);
      }
    }

    // Parse atom loop
    atoms.addAll(_parseAtomLoop(lines));

    // Parse bond loop
    bonds.addAll(_parseBondLoop(lines));

    return Ligand(
      id: ligandId,
      atoms: atoms,
      bonds: bonds,
      name: name,
      formula: formula,
    );
  }

  static String? _extractValue(String line) {
    final parts = line.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return parts.sublist(1).join(' ').replaceAll('"', '').replaceAll("'", '').trim();
    }
    return null;
  }

  static List<Atom> _parseAtomLoop(List<String> lines) {
    final atoms = <Atom>[];

    // Find atom loop block
    int loopStart = -1;
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].trim() == 'loop_') {
        // Check if next relevant line is atom block
        for (int j = i + 1; j < lines.length && j < i + 20; j++) {
          if (lines[j].trim().startsWith('_chem_comp_atom.')) {
            loopStart = i;
            break;
          }
          if (lines[j].trim().startsWith('_') && !lines[j].trim().startsWith('_chem_comp_atom.')) {
            break;
          }
        }
        if (loopStart >= 0) break;
      }
    }

    if (loopStart < 0) return atoms;

    // Collect column headers
    final headers = <String>[];
    int dataStart = loopStart + 1;
    while (dataStart < lines.length) {
      final trimmed = lines[dataStart].trim();
      if (trimmed.startsWith('_chem_comp_atom.')) {
        headers.add(trimmed.replaceFirst('_chem_comp_atom.', ''));
        dataStart++;
      } else {
        break;
      }
    }

    // Column indices we need
    final idIdx = headers.indexOf('atom_id');
    final elemIdx = headers.indexOf('type_symbol');
    // Ideal coordinates preferred, model coords as fallback
    int xIdx = headers.indexOf('pdbx_model_Cartn_x_ideal');
    int yIdx = headers.indexOf('pdbx_model_Cartn_y_ideal');
    int zIdx = headers.indexOf('pdbx_model_Cartn_z_ideal');
    if (xIdx < 0) xIdx = headers.indexOf('model_Cartn_x');
    if (yIdx < 0) yIdx = headers.indexOf('model_Cartn_y');
    if (zIdx < 0) zIdx = headers.indexOf('model_Cartn_z');

    if (idIdx < 0 || elemIdx < 0 || xIdx < 0 || yIdx < 0 || zIdx < 0) {
      return atoms;
    }

    // Parse data rows
    for (int i = dataStart; i < lines.length; i++) {
      final trimmed = lines[i].trim();
      if (trimmed.isEmpty || trimmed.startsWith('_') || trimmed.startsWith('#') || trimmed == 'loop_') break;

      final cols = _splitCifRow(trimmed);
      if (cols.length <= max(max(idIdx, elemIdx), max(xIdx, max(yIdx, zIdx)))) continue;

      final x = double.tryParse(cols[xIdx]) ?? 0.0;
      final y = double.tryParse(cols[yIdx]) ?? 0.0;
      final z = double.tryParse(cols[zIdx]) ?? 0.0;

      // Skip atoms with missing ideal coords (marked as '?')
      if (cols[xIdx] == '?' || cols[yIdx] == '?' || cols[zIdx] == '?') continue;

      atoms.add(Atom(
        id: cols[idIdx].replaceAll('"', '').replaceAll("'", ''),
        element: cols[elemIdx].replaceAll('"', '').replaceAll("'", ''),
        x: x,
        y: y,
        z: z,
      ));
    }

    return atoms;
  }

  static List<Bond> _parseBondLoop(List<String> lines) {
    final bonds = <Bond>[];

    int loopStart = -1;
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].trim() == 'loop_') {
        for (int j = i + 1; j < lines.length && j < i + 20; j++) {
          if (lines[j].trim().startsWith('_chem_comp_bond.')) {
            loopStart = i;
            break;
          }
          if (lines[j].trim().startsWith('_') && !lines[j].trim().startsWith('_chem_comp_bond.')) {
            break;
          }
        }
        if (loopStart >= 0) break;
      }
    }

    if (loopStart < 0) return bonds;

    final headers = <String>[];
    int dataStart = loopStart + 1;
    while (dataStart < lines.length) {
      final trimmed = lines[dataStart].trim();
      if (trimmed.startsWith('_chem_comp_bond.')) {
        headers.add(trimmed.replaceFirst('_chem_comp_bond.', ''));
        dataStart++;
      } else {
        break;
      }
    }

    final atom1Idx = headers.indexOf('atom_id_1');
    final atom2Idx = headers.indexOf('atom_id_2');
    final orderIdx = headers.indexOf('value_order');

    if (atom1Idx < 0 || atom2Idx < 0) return bonds;

    for (int i = dataStart; i < lines.length; i++) {
      final trimmed = lines[i].trim();
      if (trimmed.isEmpty || trimmed.startsWith('_') || trimmed.startsWith('#') || trimmed == 'loop_') break;

      final cols = _splitCifRow(trimmed);
      final maxIdx = max(atom1Idx, max(atom2Idx, orderIdx < 0 ? 0 : orderIdx));
      if (cols.length <= maxIdx) continue;

      bonds.add(Bond(
        atom1Id: cols[atom1Idx].replaceAll('"', '').replaceAll("'", ''),
        atom2Id: cols[atom2Idx].replaceAll('"', '').replaceAll("'", ''),
        order: orderIdx >= 0 ? cols[orderIdx] : 'SING',
      ));
    }

    return bonds;
  }

  /// Splits a CIF data row respecting quoted strings
  static List<String> _splitCifRow(String line) {
    final result = <String>[];
    final buffer = StringBuffer();
    bool inQuote = false;
    String quoteChar = '';

    for (int i = 0; i < line.length; i++) {
      final ch = line[i];
      if (inQuote) {
        if (ch == quoteChar) {
          inQuote = false;
          result.add(buffer.toString());
          buffer.clear();
        } else {
          buffer.write(ch);
        }
      } else if (ch == '"' || ch == "'") {
        inQuote = true;
        quoteChar = ch;
      } else if (ch == ' ' || ch == '\t') {
        if (buffer.isNotEmpty) {
          result.add(buffer.toString());
          buffer.clear();
        }
      } else {
        buffer.write(ch);
      }
    }
    if (buffer.isNotEmpty) result.add(buffer.toString());
    return result;
  }
}
