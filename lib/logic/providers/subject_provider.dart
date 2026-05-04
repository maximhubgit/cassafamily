import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cassa1/logic/providers/auth_provider.dart';
import 'package:cassa1/data/repositories/subject_repository.dart';
import 'package:cassa1/data/services/cache_service.dart';
import 'package:cassa1/data/models/subject.dart';

final subjectRepositoryProvider = Provider<SubjectRepository>((ref) {
  return SubjectRepository(
    ref.watch(firebaseServiceProvider),
    CacheService(ref.watch(sharedPreferencesProvider)),
  );
});

final subjectsProvider = StreamProvider<List<Subject>>((ref) {
  return ref.watch(subjectRepositoryProvider).getSubjects();
});
