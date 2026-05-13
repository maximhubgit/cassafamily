# Manuale Flutter/Dart: Cassa1 come Caso di Studio

> **Versione**: 1.0 - Guida completa all'architettura Flutter con progetto reale
> **Target**: Sviluppatori che vogliono imparare Flutter attraverso un'applicazione reale

---

## INDICE

1. [Fondamenti di Dart](#parte-1-fondamenti-di-dart)
2. [Architettura Flutter](#parte-2-architettura-flutter)
3. [Riverpod State Management](#parte-3-riverpod-state-management)
4. [Firebase Integration](#parte-4-firebase-integration)
5. [Pattern di Design e UI](#parte-5-pattern-di-design-e-ui)
6. [Features Avanzate di Cassa1](#parte-6-features-avanzate-di-cassa1)
7. [Build, Deploy e Testing](#parte-7-build-deploy-e-testing)

---

## PARTE 1: FONDAMENTI DI DART

### 1.1 Sistema di Tipi e Null Safety

Dart ha un sistema di tipi statico con **sound null safety**. Da Flutter 2+ questa è la default behavior.

```dart
// Prima di Null Safety (Dart < 2.12)
String name;           // potrebbe essere null
name = null;           // OK

// Dopo Null Safety (Dart 2.12+)
String name;           // NON può essere null
String? nullableName;  // può essere null

// Late initialization
late String initializedLater;  // deve essere inizializzata prima dell'uso
```

### 1.2 Classi Immutable Pattern

Cassa1 utilizza classi immutabili per dati - una best practice in Flutter:

```dart
class AppTransaction {
  final String id;
  final TransactionType type;
  final double amount;
  final DateTime date;

  // Costruttore con parametri nominati
  AppTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.date,
  });

  // Factory constructor per deserializzazione
  factory AppTransaction.fromJson(Map<String, dynamic> json) => AppTransaction(
    id: json['id'] as String,
    type: TransactionType.values.byName(json['type'] as String),
    amount: (json['amount'] as num).toDouble(),
    date: DateTime.parse(json['date'] as String),
  );

  // Per aggiornamenti immutabili
  AppTransaction copyWith({
    String? id,
    TransactionType? type,
    double? amount,
    DateTime? date,
  }) => AppTransaction(
    id: id ?? this.id,
    type: type ?? this.type,
    amount: amount ?? this.amount,
    date: date ?? this.date,
  );
}
```

**Perché Immutable?**
- Predicibilità: dati che non cambiano = meno bug
- Performance: Flutter può ottimizzare rebuild
- Thread-safe per garantito

### 1.3 Enums e Pattern Matching

```dart
enum TransactionType { income, expense, transfer, anticipi }

// Conversione enum ↔ stringa
String typeName = transaction.type.name;  // "income"
TransactionType type = TransactionType.values.byName(typeName);

// Pattern matching con when
String getIconForType(TransactionType type) => switch(type) {
  TransactionType.income => Icons.trending_up,
  TransactionType.expense => Icons.trending_down,
  TransactionType.transfer => Icons.swap_horiz,
  TransactionType.anticipi => Icons.payment,
};
```

---

## PARTE 2: ARCHITETTURA FLUTTER

### 2.1 Declarative UI Pattern

Flutter costruisce interfacce con **declarative programming**:

```dart
// Imperativo (React, jQuery)
// document.getElementById('button').onClick = function() { element.innerHTML = 'Clicked' }

// Declarative (Flutter)
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        setState(() { /* triggers rebuild */ });
      },
      child: Text('Click me'),
    );
  }
}
```

### 2.2 Widget Lifecycle

```dart
class MyScreen extends StatefulWidget {
  @override
  _MyScreenState createState() => _MyScreenState();
}

class _MyScreenState extends State<MyScreen> with RouteAware {
  @override
  void initState() {
    // Chiamato una volta quando lo stato viene creato
    super.initState();
    _loadInitialData();
  }

  @override
  void didChangeDependencies() {
    // Dopo initState, prima del primo build
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    // Chiamato ogni volta che lo stato cambia
    return Container();
  }

  @override
  void dispose() {
    // Pulizia risorse
    _controller.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    // Quando torni a questa schermata da un push
    super.didPopNext();
    _refreshData();
  }
}
```

### 2.3 Context e InheritedWidget

```dart
// Accesso a theme, media query, navigator
Widget build(BuildContext context) {
  final theme = Theme.of(context);
  final size = MediaQuery.of(context).size;
  final navigator = Navigator.of(context);

  // GoRouter navigation
  context.go('/home');        // Replace
  context.push('/details');   // Push
}
```

---

## PARTE 3: RIVERPOD STATE MANAGEMENT

### 3.1 Provider Dependencies Graph

L'architettura Riverpod di Cassa1:

```
firebaseServiceProvider (singleton)
    ↑
sharedPreferencesProvider (singleton, overriden in main)
    ↑
subjectRepositoryProvider / transactionRepositoryProvider
    ↑ (wrap Firebase + Cache)
subjectsProvider / transactionsProvider (StreamProvider)
    ↑ (async stream to UI)
UI Widgets (ConsumerWidget)
```

### 3.2 StreamProvider per Dati Real-time

```dart
// repository
Stream<List<Subject>> getSubjects() async* {
  // 1. Prima emetti cached data (optimistic)
  final cached = cacheService.getSubjects();
  if (cached != null) {
    yield subjectsFromCache;
  }

  // 2. Poi stream da Firebase
  await for (final subjects in firebaseService.subjectsStream) {
    await cacheService.save(subjects);
    yield subjects;
  }
}

// provider
final subjectsProvider = StreamProvider<List<Subject>>((ref) {
  return ref.watch(subjectRepositoryProvider).getSubjects();
});

// UI consumo
class SubjectList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjectsAsync = ref.watch(subjectsProvider);

    return subjectsAsync.when(
      loading: () => CircularProgressIndicator(),
      error: (e, st) => ErrorWidget(e),
      data: (subjects) => ListView.builder(
        itemCount: subjects.length,
        itemBuilder: (_, i) => ListTile(title: Text(subjects[i].name)),
      ),
    );
  }
}
```

### 3.3 StateNotifier per State Mutabile

```dart
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier(ref);
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final Ref ref;

  ThemeModeNotifier(this.ref) : super(ThemeMode.system) {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = ref.read(sharedPreferencesProvider);
    final index = prefs.getInt('theme') ?? 0;
    state = ThemeMode.values[index];
  }

  Future<void> toggleTheme() async {
    final newMode = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setInt('theme', newMode.index);
    state = newMode;
  }
}
```

### 3.4 Provider Scoping e Override

```dart
// main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  runApp(ProviderScope(
    overrides: [
      // Override il provider invece di passare dipendenze
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
    child: MyApp(),
  ));
}

// In un widget figlio
final repository = ref.watch(subjectRepositoryProvider);
```

---

## PARTE 4: FIREBASE INTEGRATION

### 4.1 FirebaseService - Architettura

```dart
class FirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // STREAM - Real-time listener
  // Nota: orderBy required per stream consistency
  Stream<List<Subject>> getSubjectsStream() {
    return _db
      .collection('subjects')
      .orderBy('createdAt')  // Ordering required in Firestore
      .snapshots()
      .map((snapshot) => snapshot.docs
        .map((doc) => Subject.fromJson(doc.data()))
        .toList());
  }

  // CREATE with auto-ID
  Future<String> addSubject(Subject subject) async {
    final docRef = _db.collection('subjects').doc();
    await docRef.set(subject.toJson()..['id'] = docRef.id);
    return docRef.id;
  }

  // UPDATE
  Future<void> updateSubject(Subject subject) async {
    await _db.collection('subjects').doc(subject.id).update(subject.toJson());
  }

  // DELETE
  Future<void> deleteSubject(String id) async {
    await _db.collection('subjects').doc(id).delete();
  }
}
```

### 4.2 Transaction con Batch Operations

```dart
Future<void> deleteSubjectWithTransactions(String subjectId) async {
  final batch = _db.batch();

  // 1. Elimina il soggetto
  batch.delete(_db.collection('subjects').doc(subjectId));

  // 2. Elimina le sue transazioni
  final transactions = await _db
    .collection('transactions')
    .where('subjectId', isEqualTo: subjectId)
    .get();

  for (final doc in transactions.docs) {
    batch.delete(doc.reference);
  }

  // 3. Esegui tutto in un unico write
  await batch.commit();
}
```

### 4.3 Firestore Schema Design

```
subjects/{subjectId}
  - id: string
  - name: string
  - icon: string
  - createdAt: timestamp

groups/{groupId}
  - id: string
  - name: string
  - type: "income" | "expense"
  - icon: string
  - createdAt: timestamp

entries/{entryId}
  - id: string
  - groupId: reference -> groups/{groupId}
  - name: string
  - icon: string
  - createdAt: timestamp

transactions/{transactionId}
  - id: string
  - type: "income" | "expense" | "transfer" | "anticipi"
  - amount: number
  - date: timestamp
  - subjectId?: reference (income/expense/anticipi)
  - fromSubjectId?: reference (solo transfer)
  - toSubjectId?: reference (solo transfer)
  - entryId: reference -> entries/{entryId}
  - note?: string
  - createdAt: timestamp
```

---

## PARTE 5: PATTERN DI DESIGN E UI

### 5.1 Entry Picker Pattern

Modal bottom sheet con selezione a due livelli (gruppo → voce):

```dart
Future<String?> showEntryPicker({
  required BuildContext context,
  required List<Group> groups,
  required List<Entry> entries,
  required TransactionType selectedType,
  String? selectedEntryId,
}) {
  return showModalBottomSheet<String?>(
    context: context,
    isScrollControlled: true,  // Permette scroll
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (ctx, scrollController) => CustomScrollView(
        controller: scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Seleziona voce', style: Theme.of(ctx).textTheme.titleMedium),
            ),
          ),
          ...groups.where((g) => 
            selectedType == TransactionType.income 
              ? g.type == GroupType.income 
              : g.type == GroupType.expense
          ).map((group) => SliverExpansionTile(
            title: Text(group.name),
            children: entries.where((e) => e.groupId == group.id).map((entry) => 
              ListTile(
                title: Text(entry.name),
                selected: entry.id == selectedEntryId,
                onTap: () => Navigator.pop(ctx, entry.id),
              )
            ).toList(),
          )),
        ],
      ),
    ),
  );
}
```

### 5.2 Staggered Animation Pattern

Usato nella home screen per le card dei soggetti:

```dart
GridView.builder(
  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2),
  itemCount: subjects.length,
  itemBuilder: (context, index) {
    final delay = (index * 100).clamp(0, 500);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.8 + (0.2 * value),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: SubjectCard(subjects[index]),
    );
  },
);
```

### 5.3 Animated Balance Counter

Contatore animato per i saldi:

```dart
TweenAnimationBuilder<double>(
  tween: Tween(begin: 0, end: totalBalance),
  duration: Duration(milliseconds: 800),
  curve: Curves.easeOutCubic,
  builder: (context, value, child) {
    return Text(
      '€ ${value.toStringAsFixed(2)}',
      style: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: value >= 0 ? Colors.green : Colors.red,
      ),
    );
  },
),
```

---

## PARTE 6: FEATURES AVANZATE DI CASSA1

### 6.1 Voice Transaction Processing Pipeline

```dart
class VoiceTransactionService {
  final stt.SpeechToText _speech = stt.SpeechToText();

  // STEP 1: Speech-to-Text locale
  Future<String> transcribe() async {
    await _speech.initialize();
    await _speech.listen(onResult: callback);
    return recognizedText;
  }

  // STEP 2: AI Parsing con OpenRouter
  Future<VoiceTransactionResult> process(String text) async {
    final prompt = '''
    Analizza: "$text"
    Restituisci JSON con: type, amount, entryName, confidence
    ''';

    final response = await http.post(
      Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
      headers: {'Authorization': 'Bearer $apiKey'},
      body: jsonEncode({'model': 'gpt-4', 'messages': [...]}),
    );

    // L'AI restituisce: {"type": "expense", "amount": 15.0, "entryName": "Pranzo"}
  }

  // STEP 3: Fuzzy Matching
  Entry? fuzzyMatchEntry(String name, List<Entry> entries) {
    final lower = name.toLowerCase();
    return entries.where((e) =>
      e.name.toLowerCase() == lower ||
      e.name.toLowerCase().contains(lower)
    ).firstOrNull;
  }
}
```

### 6.2 Monthly Closing Algorithm

```dart
class MonthlyClosingCalculator {
  CalculationResult calculate({
    required List<Subject> subjects,
    required List<AppTransaction> transactions,
    required int year,
    required int month,
  }) {
    final monthTx = transactions.where((t) =>
      t.date.year == year && t.date.month == month
    ).toList();

    // 1. Calcola saldo per ogni soggetto
    final balances = <Subject, double>{};
    for (final subject in subjects) {
      final income = monthTx.where((t) => 
        t.type == TransactionType.income && t.subjectId == subject.id
      ).fold(0.0, (a, t) => a + t.amount);

      final expense = monthTx.where((t) => 
        t.type == TransactionType.expense && t.subjectId == subject.id
      ).fold(0.0, (a, t) => a + t.amount);

      balances[subject] = income - expense;
    }

    // 2. Ordina per saldo (chi ha speso di più in fondo)
    final sorted = subjects..sort((a, b) => balances[a]!.compareTo(balances[b]!));

    // 3. Chiarezza: il soggetto con saldo più basso ha speso di più
    final spenderMore = sorted.last;
    final spenderLess = sorted.first;

    // 4. Calcolo importo da trasferire
    final netDiff = balances[spenderMore]!.abs() - balances[spenderLess]!.abs();
    final amount = netDiff / 2;

    return CalculationResult(
      from: spenderLess,
      to: spenderMore,
      amount: amount,
    );
  }
}
```

### 6.3 Dual-Source Streaming Pattern

```dart
class SubjectRepository {
  Stream<List<Subject>> getSubjects() async* {
    // Prima emetti cache (instantanea)
    final cached = cache.get('subjects');
    if (cached != null) {
      yield Subject.fromJsonList(jsonDecode(cached));
    }

    // Poi stream dalle modifiche Firebase
    await for (final snapshot in firebase.subjectsStream) {
      final subjects = snapshot;
      await cache.save('subjects', jsonEncode(subjects));
      yield subjects;
    }
  }
}
```

---

## PARTE 7: BUILD DEPLOY E TESTING

### 7.1 Firebase Options Setup

```dart
// lib/firebase_options.dart (manual, non FlutterFire CLI)
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return const FirebaseOptions(
      apiKey: 'YOUR_API_KEY',
      appId: 'com.maxim.cassafamily',
      messagingSenderId: 'XXXXXX',
      projectId: 'cassa-family',
      storageBucket: 'cassa-family.appspot.com',
    );
  }
}
```

### 7.2 Environment Variables per Voice Feature

```bash
# Web build
flutter run -d edge --dart-define=OPENROUTER_API_KEY=your_key

# Android
flutter run --dart-define=OPENROUTER_API_KEY=your_key

# Accesso nel codice
const apiKey = String.fromEnvironment('OPENROUTER_API_KEY');
```

### 7.3 Performance Optimizations in Cassa1

```dart
// 1. const constructors dove possibile
const MyApp({super.key});

// 2. Keys per liste
ListView.builder(
  key: ValueKey('subject-list'),
  itemCount: subjects.length,
  itemBuilder: (ctx, i) => SubjectCard(key: ValueKey(subjects[i].id), subjects[i]),
);

// 3. RepaintBoundary per evitare rebuild inutili
RepaintBoundary(
  child: ExpensiveWidget(),
);

// 4. ListView.separated invece di Column con Divider
ListView.separated(
  itemCount: items.length,
  separatorBuilder: (_, __) => const Divider(height: 1),
  itemBuilder: (_, i) => ItemWidget(items[i]),
);
```

---

## CONCLUSIONI

Cassa1 rappresenta un'applicazione Flutter completa con:

| Layer | Tecnologie |
|-------|------------|
| State Management | Riverpod (StreamProvider, StateNotifier) |
| Backend | Firebase Firestore + Auth |
| UI | Material 3, Custom Animations |
| Features | Voice Input, Monthly Closing, CSV Export |
| Patterns | Repository, Dual-Source Streaming, Immutable Models |

Questo manuale fornisce una mappa completa per:
- Capire ogni singola riga di codice
- Estendere l'app con nuove features
- Applicare gli stessi pattern ad altri progetti

---

**Prossimi passi consigliati:**
1. Leggi `lib/main.dart` per l'entry point
2. Segui il flusso `subject_provider.dart` → `subject_repository.dart` → `firebase_service.dart`
3. Apri `home_screen.dart` per comprendere l'UI pattern
4. Studia `voice_transaction_service.dart` per AI integration