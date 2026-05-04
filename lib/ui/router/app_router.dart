import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cassa1/logic/providers/auth_provider.dart';
import 'package:cassa1/ui/screens/auth/login_screen.dart';
import 'package:cassa1/ui/screens/home/home_screen.dart';
import 'package:cassa1/ui/screens/subjects/subject_list_screen.dart';
import 'package:cassa1/ui/screens/subjects/subject_detail_screen.dart';
import 'package:cassa1/ui/screens/groups/group_list_screen.dart';
import 'package:cassa1/ui/screens/entries/entry_list_screen.dart';
import 'package:cassa1/ui/screens/transactions/transaction_list_screen.dart';
import 'package:cassa1/ui/screens/transactions/all_transactions_screen.dart';
import 'package:cassa1/ui/screens/reports/report_screen.dart';
import 'package:cassa1/ui/screens/monthly_closing/monthly_closing_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isLoggedIn = authState.asData?.value != null;
      final isLoginRoute = state.location == '/login';
      if (!isLoggedIn && !isLoginRoute) return '/login';
      if (isLoggedIn && isLoginRoute) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
        routes: [
          GoRoute(
            path: 'subjects',
            builder: (context, state) => const SubjectListScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) => SubjectDetailScreen(
                  subjectId: state.params['id']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: 'groups',
            builder: (context, state) => const GroupListScreen(),
          ),
          GoRoute(
            path: 'entries',
            builder: (context, state) => const EntryListScreen(),
          ),
          GoRoute(
            path: 'transactions',
            builder: (context, state) => const TransactionListScreen(),
          ),
          GoRoute(
            path: 'all-transactions',
            builder: (context, state) => const AllTransactionsScreen(),
          ),
          GoRoute(
            path: 'reports',
            builder: (context, state) => const ReportScreen(),
          ),
          GoRoute(
            path: 'monthly-closing',
            builder: (context, state) => const MonthlyClosingScreen(),
          ),
        ],
      ),
    ],
  );
});
