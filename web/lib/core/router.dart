import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/enrollment/screens/enrollment_screen.dart';
import '../features/messaging/screens/user_selection_screen.dart';
import '../features/messaging/screens/conversation_screen.dart';
import '../features/messaging/screens/inbox_screen.dart';
import 'providers.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/users',
        builder: (context, state) => const UserSelectionScreen(),
        redirect: (context, state) {
          if (!authState.isAuthenticated) {
            return '/login';
          }
          return null;
        },
      ),
      GoRoute(
        path: '/enroll',
        builder: (context, state) => const EnrollmentScreen(),
        redirect: (context, state) {
          if (!authState.isAuthenticated) {
            return '/login';
          }
          return null;
        },
      ),
      GoRoute(
        path: '/conversation/:recipientId',
        builder: (context, state) {
          final recipientId = state.pathParameters['recipientId']!;
          return ConversationScreen(recipientId: recipientId);
        },
        redirect: (context, state) {
          if (!authState.isAuthenticated) {
            return '/login';
          }
          return null;
        },
      ),
      GoRoute(
        path: '/inbox',
        builder: (context, state) => const InboxScreen(),
        redirect: (context, state) {
          if (!authState.isAuthenticated) {
            return '/login';
          }
          return null;
        },
      ),
    ],
  );
});

