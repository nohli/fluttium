import 'package:args/command_runner.dart';
import 'package:fluttium_cli/src/command_runner.dart';
import 'package:fluttium_cli/src/version.dart';
import 'package:mason/mason.dart' hide packageVersion;
import 'package:mocktail/mocktail.dart';
import 'package:pub_updater/pub_updater.dart';
import 'package:test/test.dart';

class MockLogger extends Mock implements Logger {}

class MockPubUpdater extends Mock implements PubUpdater {}

const latestVersion = '0.0.0';

final updatePrompt = '''
${lightYellow.wrap('Update available!')} ${lightCyan.wrap(packageVersion)} \u2192 ${lightCyan.wrap(latestVersion)}
Run ${lightCyan.wrap('fluttium update')} to update''';

void main() {
  group('FluttiumCommandRunner', () {
    late PubUpdater pubUpdater;
    late Logger logger;
    late FluttiumCommandRunner commandRunner;

    setUp(() {
      pubUpdater = MockPubUpdater();

      when(
        () => pubUpdater.getLatestVersion(any()),
      ).thenAnswer((_) async => packageVersion);

      logger = MockLogger();

      commandRunner = FluttiumCommandRunner(
        logger: logger,
        pubUpdater: pubUpdater,
      );
    });

    test('shows update message when newer version exists', () async {
      when(
        () => pubUpdater.getLatestVersion(any()),
      ).thenAnswer((_) async => latestVersion);

      final result = await commandRunner.run(['--version']);
      expect(result, equals(ExitCode.success.code));
      verify(() => logger.info(updatePrompt)).called(1);
    });

    test('can be instantiated without an explicit analytics/logger instance',
        () {
      final commandRunner = FluttiumCommandRunner();
      expect(commandRunner, isNotNull);
    });

    test('handles FormatException', () async {
      const exception = FormatException('oops!');
      var isFirstInvocation = true;
      when(() => logger.info(any())).thenAnswer((_) {
        if (isFirstInvocation) {
          isFirstInvocation = false;
          throw exception;
        }
      });
      final result = await commandRunner.run(['--version']);
      expect(result, equals(ExitCode.usage.code));
      verify(() => logger.err(exception.message)).called(1);
      verify(() => logger.info(commandRunner.usage)).called(1);
    });

    test('handles UsageException', () async {
      final exception = UsageException('oops!', 'exception usage');
      var isFirstInvocation = true;
      when(() => logger.info(any())).thenAnswer((_) {
        if (isFirstInvocation) {
          isFirstInvocation = false;
          throw exception;
        }
      });
      final result = await commandRunner.run(['--version']);
      expect(result, equals(ExitCode.usage.code));
      verify(() => logger.err(exception.message)).called(1);
      verify(() => logger.info('exception usage')).called(1);
    });

    group('--version', () {
      test('outputs current version', () async {
        final result = await commandRunner.run(['--version']);
        expect(result, equals(ExitCode.success.code));
        verify(() => logger.info(packageVersion)).called(1);
      });
    });

    group('--verbose', () {
      test('enables verbose logging', () async {
        final result = await commandRunner.run(['--verbose']);
        expect(result, equals(ExitCode.success.code));

        verify(() => logger.detail('Argument information:')).called(1);
        verify(() => logger.detail('  Top level options:')).called(1);
        verify(() => logger.detail('  - verbose: true')).called(1);
        verifyNever(() => logger.detail('    Command options:'));
      });

      test('enables verbose logging for sub commands', () async {
        final result = await commandRunner.run([
          '--verbose',
          'test',
          '-d macOS',
        ]);
        expect(result, equals(ExitCode.usage.code));

        verify(() => logger.detail('Argument information:')).called(1);
        verify(() => logger.detail('  Top level options:')).called(1);
        verify(() => logger.detail('  - verbose: true')).called(1);
        verify(() => logger.detail('  Command: test')).called(1);
        verify(() => logger.detail('    Command options:')).called(1);
        verify(() => logger.detail('    - device-id:  macOS')).called(1);
      });
    });
  });
}
