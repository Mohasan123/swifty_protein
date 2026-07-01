# Fix Summary

Your files were a mix of two different generations of the same screens/services —
some referencing `LigandData`/`LigandAtom` (old model), others referencing
`Ligand`/`Atom` (your newer, better model in `ligand.dart`). I standardized
everything on **`ligand.dart`** and fixed every file that disagreed with it.

## What was wrong, file by file

### `cif_parser.dart` — **deleted**
This was a leftover duplicate. `ligand.dart` already contains its own `CifParser`
class plus the `Atom`/`Bond`/`Ligand` models (with CPK colors and VdW radii baked
in, which the old version didn't have). Keeping both caused two different,
incompatible `Ligand`-like models to float around the codebase.

### `ligand_service.dart` — rewritten
Old version had no `loadLigandList()` method and returned a `LigandResult`
wrapper. Your `ligands_list_screen.dart` expects:
- `await _service.loadLigandList()` → `List<String>`
- `await _service.fetchLigand(id)` → `Ligand` directly (throwing on failure)

New version does exactly that, throwing a `LigandException` with a
user-friendly `.toString()` message on any network/parse/404/timeout error —
which is what `_showError(e.toString())` in your list screen expects.

### `auth_service.dart` — added missing getter
`login_screen.dart` calls `auth.availableBiometrics`, which didn't exist.
Added:
```dart
Future<List<BiometricType>> get availableBiometrics async { ... }
```
Returns `[]` on any error rather than throwing, since `login_screen.dart`
doesn't wrap it in try/catch.

### `protein_viewer_screen.dart` — rewritten
Old version took `required this.ligandData` (a `LigandData`). Your list
screen calls `ProteinViewerScreen(ligand: ligand)` with a `Ligand`. Rewrote the
widget to:
- Accept `required this.ligand` (type `Ligand`)
- Convert `Ligand`/`Atom`/`Bond` → the JSON shape `viewer.html` expects
  (`atomId`, `atom1Id`, `atom2Id`, `bondOrder` keys) inside `_ligandToJson()`

### `assets/viewer.html` — updated
Element-color lookup now uppercases symbols before matching (`Cl` → `CL`)
since `Atom.element` casing isn't guaranteed, and the CPK map keys are
uppercase. Field names already matched the new JSON shape.

### `test/widget_test.dart` — replaced
`flutter create ios android` regenerates this file from Flutter's default
counter-app template, which references `MyApp` — a class that doesn't exist
in your project. Replaced it with a minimal smoke test against
`SwiftyProteinApp` (the actual root widget in `main.dart`).

### `main.dart` — now uses `AppTheme.dark`
Was building its own inline `ThemeData` instead of your `app_theme.dart`
theme. Now imports and applies `AppTheme.dark` so your theme file actually
takes effect across the app.

## How to apply this to your existing project

Replace these files in your project with the ones in this archive:
```
lib/main.dart
lib/models/ligand.dart              (NEW location — move ligand.dart here)
lib/services/auth_service.dart
lib/services/ligand_service.dart
lib/screens/protein_viewer_screen.dart
test/widget_test.dart
assets/viewer.html
```

Delete:
```
lib/services/cif_parser.dart   (if it still exists anywhere in your tree)
```

Keep as-is (already correct):
```
lib/screens/login_screen.dart
lib/screens/ligands_list_screen.dart
lib/screens/splash_screen.dart
lib/utils/app_theme.dart
assets/ligands.txt
```

Then:
```bash
flutter clean
flutter pub get
flutter run
```
