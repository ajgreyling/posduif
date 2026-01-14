import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

class Messages extends Table {
  TextColumn get id => text()();
  TextColumn get senderId => text()();
  TextColumn get recipientId => text()();
  TextColumn get content => text()();
  TextColumn get status => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get syncedAt => dateTime().nullable()();
  DateTimeColumn get readAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Users extends Table {
  TextColumn get id => text()();
  TextColumn get username => text()();
  TextColumn get userType => text()();
  TextColumn get deviceId => text().nullable()();
  BoolColumn get onlineStatus => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastSeen => dateTime().nullable()();
  TextColumn get lastMessageSent => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Messages, Users])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          await m.createTable(users);
        }
      },
    );
  }

  Future<List<Message>> getPendingMessages() {
    return (select(messages)..where((m) => m.status.equals('pending_sync'))).get();
  }

  Future<List<Message>> getAllMessages() {
    return (select(messages)
          ..orderBy([(m) => OrderingTerm.desc(m.createdAt)]))
        .get();
  }

  Future<List<Message>> getMessagesForUser(String userId) {
    return (select(messages)
          ..where((m) => m.recipientId.equals(userId) | m.senderId.equals(userId))
          ..orderBy([(m) => OrderingTerm.desc(m.createdAt)]))
        .get();
  }

  Future<Message?> getMessageById(String id) {
    return (select(messages)..where((m) => m.id.equals(id))).getSingleOrNull();
  }

  Future<void> insertMessage(Message message) {
    return into(messages).insert(message, mode: InsertMode.replace);
  }

  Future<void> updateMessageStatus(String id, String status) {
    return (update(messages)..where((m) => m.id.equals(id)))
        .write(MessagesCompanion(status: Value(status)));
  }

  Future<void> markMessageAsRead(String id) {
    return (update(messages)..where((m) => m.id.equals(id)))
        .write(MessagesCompanion(readAt: Value(DateTime.now())));
  }

  Stream<List<Message>> watchAllMessages() {
    return (select(messages)
          ..orderBy([(m) => OrderingTerm.desc(m.createdAt)]))
        .watch();
  }

  Stream<List<Message>> watchMessagesForConversation(String otherUserId, String currentUserId) {
    return (select(messages)
          ..where((m) => 
            (m.senderId.equals(currentUserId) & m.recipientId.equals(otherUserId)) |
            (m.senderId.equals(otherUserId) & m.recipientId.equals(currentUserId))
          )
          ..orderBy([(m) => OrderingTerm.asc(m.createdAt)]))
        .watch();
  }

  // User queries
  Future<List<User>> getAllUsers() {
    return (select(users)..orderBy([(u) => OrderingTerm.desc(u.updatedAt)])).get();
  }

  Future<User?> getUserById(String id) {
    return (select(users)..where((u) => u.id.equals(id))).getSingleOrNull();
  }

  Future<void> insertUser(User user) {
    return into(users).insert(user, mode: InsertMode.replace);
  }

  Future<void> insertUsers(List<User> usersList) {
    return batch((batch) {
      batch.insertAll(users, usersList, mode: InsertMode.replace);
    });
  }

  Future<void> updateUser(User user) {
    return (update(users)..where((u) => u.id.equals(user.id)))
        .write(UsersCompanion(
          username: Value(user.username),
          userType: Value(user.userType),
          deviceId: Value(user.deviceId),
          onlineStatus: Value(user.onlineStatus),
          lastSeen: Value(user.lastSeen),
          lastMessageSent: Value(user.lastMessageSent),
          updatedAt: Value(DateTime.now()),
        ));
  }

  Stream<List<User>> watchAllUsers() {
    return (select(users)..orderBy([(u) => OrderingTerm.desc(u.updatedAt)])).watch();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'posduif.db'));
    return NativeDatabase(file);
  });
}

