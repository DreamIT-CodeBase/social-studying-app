import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:social_study_app/features/auth/data/auth_repository.dart';
import 'package:social_study_app/shared/models/user.dart';
import 'package:social_study_app/shared/widgets/delete_account_dialog.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

final _fakeUser = User(
  id: 'usr_test123',
  tenantId: 'tenant_1',
  email: 'test@example.com',
  displayName: 'Test User',
  role: UserRole.student,
  gradeLevel: 10,
  workspaceMemberships: [],
  createdAt: DateTime(2026, 1, 1),
);

Widget _buildSubject({
  required AuthRepository repo,
  required Widget Function(BuildContext, WidgetRef) builder,
}) {
  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp(
      home: Consumer(
        builder: (context, ref, _) {
          return Scaffold(
            body: Center(
              child: builder(context, ref),
            ),
          );
        },
      ),
    ),
  );
}

void main() {
  late _MockAuthRepository mockRepo;

  setUp(() {
    mockRepo = _MockAuthRepository();
    when(() => mockRepo.getStoredUser()).thenAnswer((_) async => _fakeUser);
    when(() => mockRepo.deleteAccount(any())).thenAnswer((_) async {});
    when(() => mockRepo.signOut()).thenAnswer((_) async {});
  });

  testWidgets('renders delete account dialog details and actions',
      (tester) async {
    await tester.pumpWidget(
      _buildSubject(
        repo: mockRepo,
        builder: (context, ref) => ElevatedButton(
          onPressed: () => showDeleteAccountDialog(context, ref),
          child: const Text('Open'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Delete Account & Data'), findsOneWidget);
    expect(
      find.text('Are you sure you want to permanently delete your account?'),
      findsOneWidget,
    );
    expect(find.text('View Account & Data Deletion Page'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Permanently Delete'), findsOneWidget);
  });

  testWidgets('Cancel button dismisses dialog without deleting',
      (tester) async {
    await tester.pumpWidget(
      _buildSubject(
        repo: mockRepo,
        builder: (context, ref) => ElevatedButton(
          onPressed: () => showDeleteAccountDialog(context, ref),
          child: const Text('Open'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Delete Account & Data'), findsNothing);
    verifyNever(() => mockRepo.deleteAccount(any()));
  });

  testWidgets('Permanently Delete button triggers deleteAccount and dismisses',
      (tester) async {
    await tester.pumpWidget(
      _buildSubject(
        repo: mockRepo,
        builder: (context, ref) => ElevatedButton(
          onPressed: () => showDeleteAccountDialog(context, ref),
          child: const Text('Open'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Permanently Delete'));
    await tester.pumpAndSettle();

    verify(() => mockRepo.deleteAccount('usr_test123')).called(1);
    expect(find.text('Delete Account & Data'), findsNothing);
  });
}
