# Swifty Protein — explained for a web developer

This doc is for someone who knows HTML/CSS/JS (maybe React) but has never
touched Flutter or mobile development. It explains what we built, in terms
you already know, plus a manual test checklist and what each screen should
look like.

---

## 1. What Flutter actually is (the web analogy)

| Web concept | Flutter equivalent |
|---|---|
| HTML/CSS/JS | Dart (one language for everything) |
| React component (`function Button()`) | Widget (`class Button extends StatelessWidget`) |
| `useState()` | `setState()` inside a `StatefulWidget` |
| `npm install` + `package.json` | `flutter pub get` + `pubspec.yaml` |
| `<div style="...">` | `Container(decoration: ...)` |
| CSS Flexbox | `Row()` / `Column()` widgets |
| Browser DevTools | `flutter run` terminal output + hot reload |
| REST fetch() | `http.get()` (same idea, different syntax) |
| LocalStorage / cookies | `flutter_secure_storage` (this app) — but it's encrypted, like a vault |
| A `<canvas>` + Three.js | We literally embedded a real **WebView** (mini Chrome) showing an HTML page with Three.js in it — same code you'd write for a website |

**Key idea**: there is no DOM. Instead of writing HTML tags, you nest Dart
objects called widgets. `Column(children: [A, B, C])` is the same mental
model as a `<div style="display:flex; flex-direction:column">` with three
children.

**Hot reload** is like saving a file and seeing the browser auto-refresh —
except it preserves your app's current state (you don't lose your scroll
position or typed text).

---

## 2. What this app does, screen by screen

It's a **protein/molecule viewer**. Think of it like a tiny Spotify, but
instead of songs you browse "ligands" (small molecules), and instead of
playing audio, you get a spinning 3D model of the molecule's atoms.

```
Splash (1) → Login (2) → List of molecules (3) → 3D viewer (4)
```

### Screen 1 — Splash screen
Just a logo + name on screen for ~2 seconds while the app boots. Same
purpose as a loading spinner on a website's first paint. No logic here.

### Screen 2 — Login screen
- Has a "Register" and "Sign in" mode (one screen, toggled by a text link —
  like a single-page login/signup tab switch you'd build in React).
- Password requirements: 8+ characters, at least one letter and one digit.
- Passwords are **hashed** before being saved (SHA-256) — never stored as
  plain text. This is the same principle as `bcrypt` on a Node backend,
  just simpler since there's no real server here — everything lives
  encrypted on the phone itself.
- **Biometric login** — Face ID / fingerprint. This is a phone OS feature
  we just ask permission to use; we don't implement any face-recognition
  ourselves.
- **Security rule specific to this assignment**: the login screen must
  reappear every single time the app comes back from the background —
  even if you were already logged in 10 seconds ago. This is intentional
  (it's a project requirement, simulating "sensitive medical data must
  always re-authenticate").

### Screen 3 — Ligand list ("Protein library")
- A scrollable list of ~300 molecule IDs (like `ATP`, `HEM`, `NAD`).
  This is just a static text file bundled into the app — equivalent to a
  local JSON file you'd `import` in a JS project, no server needed.
- Has a **search bar** that filters the list as you type — same as
  filtering an array in JS with `.filter()` on every keystroke.
- Tapping a molecule fetches its real 3D structure from a public chemistry
  database (RCSB) over the internet — this is a normal HTTP GET request,
  exactly like `fetch()`.

### Screen 4 — 3D protein viewer
- This is the "wow" screen. Shows the molecule as balls (atoms) and sticks
  (bonds), color-coded by chemical element (carbon = gray, oxygen = red,
  nitrogen = blue, etc — this is a real chemistry standard called "CPK
  coloring", not something we invented).
- You can **drag to rotate** and **pinch to zoom** — exactly like Google
  Maps gestures.
- **Tap an atom** to see what element it is.
- **Share button** takes a screenshot and opens your phone's normal share
  sheet (same one you see when sharing a photo from your camera roll).

**How the 3D part is actually built**: instead of using a native mobile 3D
engine, we embedded a real `webview_flutter` (a hidden mini-browser) and
loaded a plain HTML file (`viewer.html`) that uses **Three.js** — the exact
same JS 3D library you'd use on a website. Flutter just sends it the
molecule's data as JSON, and the JS code on the other side draws the
spheres and cylinders. If you've ever used Three.js before, you can read
and edit `viewer.html` directly with zero Flutter knowledge.

---

## 3. The file structure (what lives where)

```
lib/
├── main.dart                     # app entry point — like index.js
├── models/
│   └── ligand.dart                # data shapes (Atom, Bond, Ligand) + the .cif file parser
├── services/
│   ├── auth_service.dart          # login/register/biometrics logic
│   └── ligand_service.dart        # fetches molecule data from the internet
├── screens/                       # one file per screen, like one .jsx per page
│   ├── splash_screen.dart
│   ├── login_screen.dart
│   ├── ligands_list_screen.dart
│   └── protein_viewer_screen.dart
└── utils/
    └── app_theme.dart              # colors/fonts — like a CSS variables file
assets/
├── ligands.txt                    # the list of ~300 molecule IDs (static data)
└── viewer.html                    # the Three.js 3D viewer (real HTML/JS)
```

A useful mental model: `services/` = your API client code, `models/` = your
TypeScript interfaces (but with real parsing logic attached), `screens/` =
your pages, `utils/` = your shared config/constants.

---

## 4. What you'll actually see (previews)

I generated visual mockups of all 4 screens above this message so you can
show your friend exactly what's expected before running anything.

1. **Splash** — dark background, glowing cyan flask icon, app name, small
   spinner underneath.
2. **Login** — username + password fields, a solid cyan "Sign in" button,
   and an outlined "Use biometrics" button with a fingerprint icon below it.
3. **Ligand list** — a search bar at top, a count ("312 ligands"), then a
   scrolling list of molecule codes each with a small atom icon. Tapping
   one shows a spinner in place of the icon while it loads.
4. **3D viewer** — a dark canvas with a ball-and-stick molecule that can be
   rotated/zoomed, a small floating label when you tap an atom, and a
   bottom panel showing atom/bond counts and element color tags.

---

## 5. Manual test checklist

Since this is mostly UI + device features (camera roll, biometrics,
network), most testing here is manual — there isn't a meaningful way to
"unit test" a fingerprint prompt. Here's what to click through, in order:

### Setup
- [ ] `flutter pub get` runs with no errors
- [ ] `flutter run` builds and launches on a real device or emulator
      (biometrics often don't work in iOS Simulator/some emulators — use a
      real phone if you can, like the project subject recommends)

### Splash screen
- [ ] App opens to splash screen, stays visible for ~1-2 seconds
- [ ] Auto-navigates to Login without you tapping anything

### Login — registration
- [ ] Tap "Register" link — form switches to signup mode
- [ ] Try a weak password (e.g. `abc`) → should show a clear error, not crash
- [ ] Try a password with no digit (e.g. `abcdefgh`) → should show an error
- [ ] Register with a valid username + valid password (e.g. `tester1` /
      `password123`) → should succeed and go to the ligand list

### Login — re-opening the app (the important security test)
- [ ] While on the ligand list screen, press the phone's Home button (or
      swipe to background the app)
- [ ] Reopen the app → it MUST show the Login screen again, not the list
      you were just on. This is intentional and required by the assignment.

### Login — biometrics
- [ ] If your phone has Face ID/fingerprint set up, the "Use biometrics"
      button should appear
- [ ] Tap it → phone's native Face ID/fingerprint prompt appears
- [ ] Successful scan → goes to ligand list
- [ ] Cancel or fail the scan on purpose → app shows a friendly error
      message, does NOT crash, lets you try again or use password instead

### Login — wrong credentials
- [ ] Try logging in with a username that was never registered → clear
      "Account not found" message
- [ ] Try the right username with wrong password → clear "Incorrect
      password" message

### Ligand list
- [ ] List loads and shows ~300 entries
- [ ] Type in the search bar (e.g. "AT") → list filters live, no need to
      press Enter or any button
- [ ] Clear the search → full list returns
- [ ] Search something that matches nothing → shows a "No ligands found"
      style message, not a blank crash screen

### Ligand list — network behavior
- [ ] Turn on Airplane Mode, tap a ligand → should show a friendly "No
      internet connection" alert, not a frozen spinner or a crash
- [ ] Turn internet back on, tap a ligand → spinner appears briefly, then
      navigates to the 3D viewer
- [ ] Tap a second ligand right after the first finishes loading → should
      work the same way (tests that loading state resets properly)

### 3D viewer
- [ ] Molecule appears as colored balls connected by gray sticks
- [ ] One-finger drag → molecule rotates
- [ ] Two-finger pinch → molecule zooms in/out
- [ ] Tap directly on an atom (a ball) → small label pops up showing its
      element and ID
- [ ] Tap the label / tap elsewhere → label disappears
- [ ] Tap the share icon (top right) → phone's native share sheet opens
      with a screenshot of the current view
- [ ] Tap the back arrow (top left) → returns to the ligand list, search
      text you typed earlier should still be there

### Edge cases worth trying together
- [ ] Rotate the phone to landscape on any screen → layout shouldn't break
      or clip content
- [ ] Try a ligand ID that doesn't exist in the database (you can edit
      `assets/ligands.txt` to add a fake one like `ZZZ999` temporarily) →
      should show a "Ligand not found (404)" message, not a crash
- [ ] Background the app *while* a molecule is loading → reopening should
      not leave the spinner stuck forever

---

## 6. Quick troubleshooting glossary

| You see... | It usually means... |
|---|---|
| Red screen with text | A runtime error/crash — read the message, it usually names the exact file+line |
| `undefined_method` / `undefined_getter` at build time | Two files disagree on a function name (this is what we fixed last time — like calling a function that was renamed in one file but not another) |
| App builds but biometrics button never shows | Either the emulator has no fingerprint configured, or you're on a device with no biometric hardware — try a real phone |
| Hot reload doesn't pick up a change | Some changes (like editing `main.dart`'s structure) need a full restart, not just hot reload — stop and re-run `flutter run` |

---

Good luck working through it together — since your friend is also new to
this, the React/web analogies above should make Flutter feel a lot less
foreign than it looks at first glance.
