# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Cassa1 is a Flutter app for personal/family budget management. Users track income, expenses, transfers, and advances (`anticipi`) across multiple subjects (people). Built with Flutter + Riverpod, backed by Firebase (Auth + Firestore).

## Commands

```bash
# Install dependencies
flutter pub get

# Run on Edge browser (primary dev target)
flutter run -d edge

# Run with OpenRouter API key for voice features
flutter run -d edge --dart-define=OPENROUTER_API_KEY=your_key

# Run on Android emulator
flutter emulators          # list available emulators
flutter emulators --launch <AVD_NAME>
flutter run -d <DEVICE_ID>

# Build
flutter build apk          # Android
flutter build web           # Web
flutter build ios           # iOS

# Lint
flutter analyze

# No tests exist yet
```

## Architecture

### Data Flow

```
UI (ConsumerWidget) → Provider (StreamProvider) → Repository → Service (Firestore + Cache)
```

### Key Layers

- **Models** (`lib/data/models/`): `Subject`, `Group`, `Entry`, `AppTransaction`
  - Class is named `AppTransaction` (not `Transaction`) to avoid Flutter naming conflict
  - `AppTransaction` has four types: `income`, `expense`, `transfer`, `anticipi`
  - `transfer` type uses `fromSubjectId`/`toSubjectId` instead of `subjectId`
  - `anticipi` type behaves like an expense (uses `subjectId` + `entryId`) but is NOT included in saldo (balance) — shown separately in balance headers
  - All models have `fromJson`/`toJson`/`copyWith` for serialization and immutable updates

- **Services** (`lib/data/services/`):
  - `FirebaseService` — all Firestore CRUD operations and real-time streams (`_db.collection(...).snapshots()`)
  - `CacheService` — local caching via `shared_preferences`, used as fallback/optimistic cache by repositories
  - `ExportService` — generates CSV from transactions data and shares via system share dialog (uses `csv`, `path_provider`, `share_plus` packages)
  - `VoiceTransactionService` — voice-to-transaction via `speech_to_text` (local STT) + OpenRouter API (AI parsing). Returns structured `VoiceTransactionResult` with fuzzy-matched subject/entry IDs

- **Repositories** (`lib/data/repositories/`): Wrap `FirebaseService` + `CacheService`. Implement dual-source streaming: return cached data first, then yield Firestore updates. Expose `add()`, `update()`, `delete()`, and `isEntryLinked()` methods.

- **Providers** (`lib/logic/providers/`):
  - `auth_provider.dart` — `authStateProvider` (StreamProvider of Firebase User), `AuthNotifier` for sign in/out. Also defines `firebaseServiceProvider` and `sharedPreferencesProvider` (latter is overridden in `main()` with a real instance)
  - `theme_provider.dart` — `themeModeProvider` (StateNotifierProvider for ThemeMode), persists choice via SharedPreferences. Provides `buildLightTheme()` / `buildDarkTheme()`
  - `subject_provider.dart`, `group_provider.dart`, `entry_provider.dart`, `transaction_provider.dart` — each exposes a `StreamProvider` for real-time Firestore data

- **Utils** (`lib/utils/`):
  - `constants.dart` — `AppColors` (primary, income/expense/transfer/anticipi colors), `AppStrings` (all UI strings), `AppIcons`
  - `icon_helper.dart` — utility for mapping icon names to Flutter `IconData`

- **Router** (`lib/ui/router/app_router.dart`): go_router with auth guard. Redirects unauthenticated users to `/login`. Key routes:
  - `/` — Home screen
  - `/subjects` — Subject list, with sub-route `/subjects/:id` for detail
  - `/all-transactions` — All transactions across all subjects (main transaction view)
  - `/monthly-closing` — Monthly closing calculation between subjects
  - `/transactions` — Legacy transaction list screen (kept for compatibility)
  - `/groups`, `/entries`, `/reports`

### Initialization (`lib/main.dart`)

1. `WidgetsFlutterBinding.ensureInitialized()`
2. `Firebase.initializeApp()` with `DefaultFirebaseOptions.currentPlatform`
3. `initializeDateFormatting('it_IT', null)` — Italian locale for `intl`
4. `SharedPreferences.getInstance()` — stored as override for `sharedPreferencesProvider`
5. `runApp()` with `ProviderScope` wrapping `MyApp` (ConsumerWidget)

### Firestore Schema

| Collection | Model | Key Fields | Notes |
|------------|-------|-------------|-------|
| `subjects` | `Subject` | `id`, `name`, `icon`, `createdAt` | People (Maxim, Francy) |
| `groups` | `Group` | `id`, `name`, `type` (income/expense), `icon`, `createdAt` | Categories grouped by type |
| `entries` | `Entry` | `id`, `groupId`, `name`, `icon`, `createdAt` | Voce - linked to a group |
| `transactions` | `AppTransaction` | `id`, `type`, `amount`, `date`, `subjectId`/`fromSubjectId`/`toSubjectId`, `entryId`, `note`, `createdAt` | 4 types: income, expense, transfer, anticipi |

- All collections use `orderBy('createdAt')` for streams
- `subjectId` is used for income/expense/anticipi; `fromSubjectId`/`toSubjectId` for transfers
- `entryId` links transactions to entries (which belong to groups)

### Provider Dependency Graph

```
firebaseServiceProvider (FirebaseService singleton)
    ↑
sharedPreferencesProvider (SharedPreferences — overridden in main.dart)
    ↑
subjectRepositoryProvider / groupRepositoryProvider / entryRepositoryProvider / transactionRepositoryProvider
    ↑ (each wraps FirebaseService + CacheService)
subjectsProvider / groupsProvider / entriesProvider / transactionsProvider (StreamProvider)
    ↑ (consumed by UI via ref.watch)
```

- `authStateProvider` (StreamProvider of Firebase User) is defined in `auth_provider.dart` alongside `firebaseServiceProvider` and `sharedPreferencesProvider`
- `themeModeProvider` (StateNotifierProvider) persists ThemeMode via SharedPreferences
- All screen widgets are `ConsumerWidget` (or `ConsumerStatefulWidget` for stateful screens like `HomeScreen`) consuming providers via `ref.watch`

### Balance Calculation

```
saldo = income - expense + transferIn - transferOut   (anticipi are excluded from saldo)
```

Balance headers appear in: home screen, subject detail, and all-transactions screen. All show Entrate, Uscite, Trasf, Anticipi, and Saldo.

### Monthly Closing Logic

The monthly closing feature (`lib/ui/screens/monthly_closing/`) calculates who owes whom based on monthly spending:

1. For each subject, calculate: `saldo = income - expense + transferIn - transferOut`
2. Sort subjects by balance (most negative = spent more)
3. `diff = |balance_spent_more| - |balance_spent_less|`
4. `subtotal = diff / 2`
5. `result = subtotal + anticipi_spent_more - anticipi_spent_less`
6. The subject who spent less pays the subject who spent more: `€ result`

Note: anticipi are advance payments. Whoever spent more adds their anticipi (they already paid in advance, so they should receive more), while whoever spent less subtracts their anticipi (they already paid in advance, so they owe less).

### Transaction Form Pattern

Forms for adding/editing transactions (`subject_detail_screen.dart`, `all_transactions_screen.dart`):
- Dropdown with 4 types: Entrata, Uscita, Trasferimento, Anticipo
- Date picker (required): if current month selected → today's date; otherwise → last day of selected month
- For `transfer`: "Da soggetto" + "A soggetto" selectors (both required, must be different)
- For `income`/`expense`/`anticipi`: subject selector + entry (voce) selector using `showEntryPicker()`
- Amount field (required, must be > 0)
- Note field (optional)
- All fields marked with `*` are mandatory; validation shows `SnackBar` with error message on save

### Entry Picker Pattern

The `showEntryPicker()` function (`lib/ui/widgets/entry_picker.dart`) provides a two-level entry selection UI (group → entries) via a modal bottom sheet. Used in transaction forms instead of a flat DropdownButton:
```dart
final entryId = await showEntryPicker(
  context: context,
  groups: groups,
  entries: entries,
  selectedType: selectedType,
  selectedEntryId: selectedEntryId,
);
```
The picker filters entries by group type (income/expense) based on `selectedType`, shows groups with expandable headers, and returns the selected entry ID.

### UI Patterns

- **AppDrawer** (`lib/ui/widgets/app_drawer.dart`): Left drawer with subjects list showing current month balances, voice transaction button (mic icon), CSV export/import, theme toggle, and logout
- **Home Screen** (`lib/ui/screens/home/home_screen.dart`): Grid of subject cards showing current month balance, "Ultime transazioni" card with quick totals, and quick action buttons (Groups, Entries, Voice, Reports)
- **Subject Detail** (`lib/ui/screens/subjects/subject_detail_screen.dart`): Monthly transaction list with `_showAnticipi` switch to show/hide anticipi transactions (anticipi are always included in balance totals)
- **Current Month Filtering**: Home screen and AppDrawer filter transactions using `currentMonthTx()` helper - only show current month data in balances and cards

### Export Feature

The export button is on the "Tutti i movimenti" screen (`all_transactions_screen.dart`). It generates a CSV file with all transactions (resolved names for subjects, entries, groups) and opens the system share dialog. CSV columns: Data, Tipo, Soggetto, Da soggetto, A soggetto, Voce, Gruppo, Importo, Nota.

### Important Patterns

- **go_router 6.x**: Use `state.params['id']` (not `state.pathParameters`) for route params
- **Navigation**: Use `context.go('/path')` or `context.push('/path')` (go_router) for navigation, not `Navigator.push()`
- **intl initialization**: `await initializeDateFormatting('it_IT', null)` in `main()` before running the app
- **Riverpod**: Screens are `ConsumerWidget` or `ConsumerStatefulWidget` (stateful screens like `HomeScreen` for month/year picker state), data consumed via `ref.watch(provider)`
- **Theme**: Material3, seed color from `AppColors.primary`, Poppins font via google_fonts. Dark theme uses `surfaceContainerHighest` for card backgrounds. Use `Theme.of(context).colorScheme.*` for theme-aware colors (not hardcoded `AppColors.primary`)
- **Deprecated APIs**: `withOpacity` → `withValues()`, `surfaceVariant` → `surfaceContainerHighest`
- **Firebase config**: Manual setup in `lib/firebase_options.dart` (not using FlutterFire CLI). Android needs `google-services.json` in `android/app/` for APK builds. Android package name: `com.maxim.cassafamily`
- **Auth**: Anonymous sign-in via `AuthNotifier.signInAnonymously()`. Auth state managed by `authStateProvider` (stream of `User?`). No email/password or social login.

### Voice Input Feature

Users can create transactions by speaking into the microphone. The flow: speech_to_text transcribes audio → OpenRouter API (Gemini Flash) parses text into structured JSON → confirmation dialog with pre-filled fields.

- **Dependencies**: `speech_to_text` (local STT), `http` (OpenRouter API calls)
- **Service**: `VoiceTransactionService` (`lib/data/services/voice_transaction_service.dart`) — transcribes, sends to AI, fuzzy-matches names to IDs
- **Widget**: `VoiceTransactionDialog` (`lib/ui/widgets/voice_transaction_dialog.dart`) — manages recording states (idle/listening/processing/confirm/error)
- **Integration**: Mic button added to AppBars in `subject_detail_screen.dart` and `all_transactions_screen.dart`
- **Environment**: Requires `OPENROUTER_API_KEY` env var: `flutter run -d edge --dart-define=OPENROUTER_API_KEY=your_key`
- **Android**: Requires `RECORD_AUDIO` permission in `AndroidManifest.xml`
- **Voice command example**: "uscita Massimo pranzo 15 euro" → AI returns JSON with type=expense, subjectId, entryId, amount=15.0
