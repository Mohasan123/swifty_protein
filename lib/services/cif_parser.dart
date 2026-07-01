/// Represents a single atom in a ligand
class LigandAtom {
  final String atomId;      // e.g. "C1", "O2"
  final String element;     // e.g. "C", "O", "N"
  final double x;
  final double y;
  final double z;
  final String? charge;

  const LigandAtom({
    required this.atomId,
    required this.element,
    required this.x,
    required this.y,
    required this.z,
    this.charge,
  });

  Map<String, dynamic> toJson() => {
        'atomId': atomId,
        'element': element,
        'x': x,
        'y': y,
        'z': z,
        'charge': charge,
      };
}

/// Represents a bond between two atoms
class LigandBond {
  final String atom1Id;
  final String atom2Id;
  final String bondOrder; // 'SING', 'DOUB', 'TRIP', 'AROM'

  const LigandBond({
    required this.atom1Id,
    required this.atom2Id,
    required this.bondOrder,
  });

  Map<String, dynamic> toJson() => {
        'atom1Id': atom1Id,
        'atom2Id': atom2Id,
        'bondOrder': bondOrder,
      };
}

/// Parsed ligand data
class LigandData {
  final String id;
  final String name;
  final String formula;
  final List<LigandAtom> atoms;
  final List<LigandBond> bonds;

  const LigandData({
    required this.id,
    required this.name,
    required this.formula,
    required this.atoms,
    required this.bonds,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'formula': formula,
        'atoms': atoms.map((a) => a.toJson()).toList(),
        'bonds': bonds.map((b) => b.toJson()).toList(),
      };
}

/// Parses RCSB .cif ligand files
class CifParser {
  static LigandData parse(String cifContent, String ligandId) {
    final lines = cifContent.split('\n');

    String name = ligandId;
    String formula = '';
    final atoms = <LigandAtom>[];
    final bonds = <LigandBond>[];

    // Extract simple key-value fields
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('_chem_comp.name')) {
        name = _extractValue(trimmed);
      } else if (trimmed.startsWith('_chem_comp.formula ') &&
          !trimmed.startsWith('_chem_comp.formula_weight')) {
        formula = _extractValue(trimmed);
      }
    }

    // Parse atom loop
    atoms.addAll(_parseAtomLoop(lines));

    // Parse bond loop
    bonds.addAll(_parseBondLoop(lines));

    return LigandData(
      id: ligandId,
      name: name,
      formula: formula,
      atoms: atoms,
      bonds: bonds,
    );
  }

  static String _extractValue(String line) {
    final parts = line.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return parts.sublist(1).join(' ').replaceAll("'", '').trim();
    }
    return '';
  }

  static List<LigandAtom> _parseAtomLoop(List<String> lines) {
    final atoms = <LigandAtom>[];

    // Find the atom loop section
    int loopStart = -1;
    final columnIndices = <String, int>{};

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      // Look for the start of atom loop
      if (line == 'loop_') {
        // Check if the next lines define atom columns
        int j = i + 1;
        final tempColumns = <String, int>{};
        int colIdx = 0;

        while (j < lines.length && lines[j].trim().startsWith('_chem_comp_atom.')) {
          tempColumns[lines[j].trim()] = colIdx++;
          j++;
        }

        if (tempColumns.isNotEmpty &&
            tempColumns.containsKey('_chem_comp_atom.atom_id')) {
          loopStart = j;
          columnIndices.addAll(tempColumns);
          break;
        }
      }
    }

    if (loopStart == -1 || columnIndices.isEmpty) return atoms;

    // Required column indices
    final atomIdCol = columnIndices['_chem_comp_atom.atom_id'] ?? -1;
    final elementCol = columnIndices['_chem_comp_atom.type_symbol'] ?? -1;
    final xCol = columnIndices['_chem_comp_atom.model_Cartn_x'] ??
        columnIndices['_chem_comp_atom.pdbx_model_Cartn_x_ideal'] ??
        -1;
    final yCol = columnIndices['_chem_comp_atom.model_Cartn_y'] ??
        columnIndices['_chem_comp_atom.pdbx_model_Cartn_y_ideal'] ??
        -1;
    final zCol = columnIndices['_chem_comp_atom.model_Cartn_z'] ??
        columnIndices['_chem_comp_atom.pdbx_model_Cartn_z_ideal'] ??
        -1;
    final chargeCol = columnIndices['_chem_comp_atom.charge'] ?? -1;

    if (atomIdCol == -1 || elementCol == -1 || xCol == -1) return atoms;

    // Parse data rows
    for (int i = loopStart; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty || line.startsWith('#') || line.startsWith('_') || line == 'loop_') break;

      final parts = _splitCifLine(line);
      if (parts.length <= atomIdCol) continue;

      try {
        final atomId = parts[atomIdCol].replaceAll('"', '').replaceAll("'", '');
        final element = elementCol < parts.length
            ? parts[elementCol].replaceAll('"', '').replaceAll("'", '')
            : 'C';
        final x = xCol < parts.length ? double.tryParse(parts[xCol]) ?? 0.0 : 0.0;
        final y = yCol < parts.length ? double.tryParse(parts[yCol]) ?? 0.0 : 0.0;
        final z = zCol < parts.length ? double.tryParse(parts[zCol]) ?? 0.0 : 0.0;
        final charge = chargeCol < parts.length ? parts[chargeCol] : null;

        // Skip hydrogen if element is just whitespace or dot
        if (element.isEmpty || element == '.') continue;

        atoms.add(LigandAtom(
          atomId: atomId,
          element: element,
          x: x,
          y: y,
          z: z,
          charge: charge == '?' || charge == '.' ? null : charge,
        ));
      } catch (_) {
        continue;
      }
    }

    return atoms;
  }

  static List<LigandBond> _parseBondLoop(List<String> lines) {
    final bonds = <LigandBond>[];

    int loopStart = -1;
    final columnIndices = <String, int>{};

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      if (line == 'loop_') {
        int j = i + 1;
        final tempColumns = <String, int>{};
        int colIdx = 0;

        while (j < lines.length && lines[j].trim().startsWith('_chem_comp_bond.')) {
          tempColumns[lines[j].trim()] = colIdx++;
          j++;
        }

        if (tempColumns.isNotEmpty &&
            tempColumns.containsKey('_chem_comp_bond.atom_id_1')) {
          loopStart = j;
          columnIndices.addAll(tempColumns);
          break;
        }
      }
    }

    if (loopStart == -1 || columnIndices.isEmpty) return bonds;

    final atom1Col = columnIndices['_chem_comp_bond.atom_id_1'] ?? -1;
    final atom2Col = columnIndices['_chem_comp_bond.atom_id_2'] ?? -1;
    final orderCol = columnIndices['_chem_comp_bond.value_order'] ?? -1;

    if (atom1Col == -1 || atom2Col == -1) return bonds;

    for (int i = loopStart; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty || line.startsWith('#') || line.startsWith('_') || line == 'loop_') break;

      final parts = _splitCifLine(line);
      if (parts.length <= atom2Col) continue;

      try {
        final atom1 = parts[atom1Col].replaceAll('"', '').replaceAll("'", '');
        final atom2 = parts[atom2Col].replaceAll('"', '').replaceAll("'", '');
        final order = orderCol < parts.length ? parts[orderCol] : 'SING';

        bonds.add(LigandBond(
          atom1Id: atom1,
          atom2Id: atom2,
          bondOrder: order,
        ));
      } catch (_) {
        continue;
      }
    }

    return bonds;
  }

  /// Splits a CIF data line respecting quoted strings
  static List<String> _splitCifLine(String line) {
    final parts = <String>[];
    final buffer = StringBuffer();
    bool inQuote = false;
    String quoteChar = '';

    for (int i = 0; i < line.length; i++) {
      final ch = line[i];

      if (inQuote) {
        if (ch == quoteChar) {
          inQuote = false;
          parts.add(buffer.toString());
          buffer.clear();
        } else {
          buffer.write(ch);
        }
      } else if (ch == '"' || ch == "'") {
        inQuote = true;
        quoteChar = ch;
      } else if (ch == ' ' || ch == '\t') {
        if (buffer.isNotEmpty) {
          parts.add(buffer.toString());
          buffer.clear();
        }
      } else {
        buffer.write(ch);
      }
    }

    if (buffer.isNotEmpty) parts.add(buffer.toString());
    return parts;
  }
}
