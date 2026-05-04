import 'dart:convert';
import '../models/subject.dart';
import '../services/firebase_service.dart';
import '../services/cache_service.dart';

class SubjectRepository {
  final FirebaseService firebaseService;
  final CacheService cacheService;

  SubjectRepository(this.firebaseService, this.cacheService);

  Stream<List<Subject>> getSubjects() async* {
    final cached = cacheService.getSubjects();
    if (cached != null) {
      final List<dynamic> decoded = jsonDecode(cached);
      yield decoded.map((json) => Subject.fromJson(json)).toList();
    }
    await for (final subjects in firebaseService.getSubjectsStream()) {
      final json = jsonEncode(subjects.map((s) => s.toJson()).toList());
      await cacheService.saveSubjects(json);
      yield subjects;
    }
  }

  Future<void> add(Subject subject) => firebaseService.addSubject(subject);
  Future<void> update(Subject subject) => firebaseService.updateSubject(subject);
  Future<void> delete(String id) => firebaseService.deleteSubject(id);
}
