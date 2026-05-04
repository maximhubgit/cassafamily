import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/models/group.dart';
import '../../data/models/entry.dart';
import '../../data/models/subject.dart';
import '../../data/models/transaction.dart';

class FirebaseService {
  final _db = FirebaseFirestore.instance;

  // ---------- SUBJECTS ----------
  Stream<List<Subject>> getSubjectsStream() =>
      _db.collection('subjects').orderBy('createdAt').snapshots().map(
            (snap) => snap.docs.map((d) => Subject.fromJson(d.data())).toList(),
          );

  Future<void> addSubject(Subject s) async {
    await _db.collection('subjects').doc(s.id).set(s.toJson());
  }

  Future<void> updateSubject(Subject s) async {
    await _db.collection('subjects').doc(s.id).update(s.toJson());
  }

  Future<void> deleteSubject(String id) async {
    await _db.collection('subjects').doc(id).delete();
  }

  // ---------- GROUPS ----------
  Stream<List<Group>> getGroupsStream() =>
      _db.collection('groups').orderBy('createdAt').snapshots().map(
            (snap) => snap.docs.map((d) => Group.fromJson(d.data())).toList(),
          );

  Future<void> addGroup(Group g) async {
    await _db.collection('groups').doc(g.id).set(g.toJson());
  }

  Future<void> updateGroup(Group g) async {
    await _db.collection('groups').doc(g.id).update(g.toJson());
  }

  Future<void> deleteGroup(String id) async {
    await _db.collection('groups').doc(id).delete();
  }

  // ---------- ENTRIES ----------
  Stream<List<Entry>> getEntriesStream() =>
      _db.collection('entries').orderBy('createdAt').snapshots().map(
            (snap) => snap.docs.map((d) => Entry.fromJson(d.data())).toList(),
          );

  Future<void> addEntry(Entry e) async {
    await _db.collection('entries').doc(e.id).set(e.toJson());
  }

  Future<void> updateEntry(Entry e) async {
    await _db.collection('entries').doc(e.id).update(e.toJson());
  }

  Future<void> deleteEntry(String id) async {
    await _db.collection('entries').doc(id).delete();
  }

  // ---------- TRANSACTIONS ----------
  Stream<List<AppTransaction>> getTransactionsStream() =>
      _db.collection('transactions').orderBy('date', descending: true).snapshots().map(
            (snap) => snap.docs.map((d) => AppTransaction.fromJson(d.data())).toList(),
          );

  Future<void> addTransaction(AppTransaction t) async {
    await _db.collection('transactions').doc(t.id).set(t.toJson());
  }

  Future<void> updateTransaction(AppTransaction t) async {
    await _db.collection('transactions').doc(t.id).update(t.toJson());
  }

  Future<void> deleteTransaction(String id) async {
    await _db.collection('transactions').doc(id).delete();
  }

  Future<void> addExampleData() async {
    final subjects = [
      Subject(id: 's1', name: 'Marco', icon: 'person', createdAt: DateTime.now()),
      Subject(id: 's2', name: 'Laura', icon: 'person_outline', createdAt: DateTime.now()),
    ];
    for (final s in subjects) {
      await addSubject(s);
    }

    final groups = [
      Group(id: 'g1', name: 'Stipendio', type: GroupType.income, icon: 'work', createdAt: DateTime.now()),
      Group(id: 'g2', name: 'Affitto', type: GroupType.expense, icon: 'home', createdAt: DateTime.now()),
      Group(id: 'g3', name: 'Spesa', type: GroupType.expense, icon: 'local_grocery_store', createdAt: DateTime.now()),
    ];
    for (final g in groups) {
      await addGroup(g);
    }

    final entries = [
      Entry(id: 'e1', groupId: 'g1', name: 'Mensile', icon: 'payments', createdAt: DateTime.now()),
      Entry(id: 'e2', groupId: 'g2', name: 'Mensile', icon: 'payments', createdAt: DateTime.now()),
      Entry(id: 'e3', groupId: 'g3', name: 'Supermercato', icon: 'shopping_cart', createdAt: DateTime.now()),
    ];
    for (final e in entries) {
      await addEntry(e);
    }

    final txs = [
      AppTransaction(
        id: 't1', type: TransactionType.income, amount: 2500,
        date: DateTime.now().subtract(const Duration(days: 5)),
        subjectId: 's1', entryId: 'e1', createdAt: DateTime.now(),
      ),
      AppTransaction(
        id: 't2', type: TransactionType.expense, amount: 800,
        date: DateTime.now().subtract(const Duration(days: 4)),
        subjectId: 's1', entryId: 'e2', createdAt: DateTime.now(),
      ),
      AppTransaction(
        id: 't3', type: TransactionType.expense, amount: 150,
        date: DateTime.now().subtract(const Duration(days: 3)),
        subjectId: 's1', entryId: 'e3', createdAt: DateTime.now(),
      ),
    ];
    for (final t in txs) {
      await addTransaction(t);
    }
  }
}
