import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database.dart';
import '../api/api_client.dart';
import '../sync/sync_service.dart';

// Database provider
final databaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

// API Client provider
final apiClientProvider = Provider<APIClient>((ref) {
  return APIClient();
});

// Connectivity provider
final connectivityProvider = Provider<Connectivity>((ref) {
  return Connectivity();
});

// Sync Service provider
final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(
    ref.read(databaseProvider),
    ref.read(apiClientProvider),
    ref.read(connectivityProvider),
  );
});

// Messages stream provider
final messagesStreamProvider = StreamProvider<List<Message>>((ref) {
  final database = ref.read(databaseProvider);
  return database.watchAllMessages();
});

// User ID provider
final userIdProvider = FutureProvider<String?>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('user_id');
});

// Current User ID provider (synchronous)
final currentUserIdProvider = StateProvider<String?>((ref) {
  // This will be set after enrollment
  return null; // Will be updated via SharedPreferences
});// Helper to get current user ID synchronously
Future<String?> getCurrentUserId() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('user_id');
}
