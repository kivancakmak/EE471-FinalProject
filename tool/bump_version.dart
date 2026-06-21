import 'dart:io';

final _versionLinePattern = RegExp(
  r'^version:\s*(\d+)\.(\d+)\.(\d+)(?:\+(\d+))?\s*$',
);

void main(List<String> args) {
  if (args.length != 1 || !{'patch', 'minor', 'major'}.contains(args.single)) {
    stderr.writeln(
      'Usage: dart run tool/bump_version.dart <patch|minor|major>',
    );
    exitCode = 64;
    return;
  }

  final pubspec = File('pubspec.yaml');
  if (!pubspec.existsSync()) {
    stderr.writeln(
      'pubspec.yaml not found. Run this command from the project root.',
    );
    exitCode = 66;
    return;
  }

  final lines = pubspec.readAsLinesSync();
  final versionLineIndex = lines.indexWhere(
    (line) => _versionLinePattern.hasMatch(line),
  );

  if (versionLineIndex == -1) {
    stderr.writeln('No valid x.y.z version line found in pubspec.yaml.');
    exitCode = 65;
    return;
  }

  final match = _versionLinePattern.firstMatch(lines[versionLineIndex])!;
  var major = int.parse(match.group(1)!);
  var minor = int.parse(match.group(2)!);
  var patch = int.parse(match.group(3)!);
  final currentBuild = int.tryParse(match.group(4) ?? '0') ?? 0;

  switch (args.single) {
    case 'major':
      major += 1;
      minor = 0;
      patch = 0;
      break;
    case 'minor':
      minor += 1;
      patch = 0;
      break;
    case 'patch':
      patch += 1;
      break;
  }

  final nextBuild = currentBuild + 1;
  final nextVersion = '$major.$minor.$patch+$nextBuild';
  lines[versionLineIndex] = 'version: $nextVersion';
  pubspec.writeAsStringSync('${lines.join('\n')}\n');

  stdout.writeln(nextVersion);
}
