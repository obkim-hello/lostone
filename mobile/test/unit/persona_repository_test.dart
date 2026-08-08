import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lostone/models/evidence.dart';
import 'package:lostone/models/memories.dart';
import 'package:lostone/models/message.dart';
import 'package:lostone/models/persona.dart';
import 'package:lostone/models/persona_layers.dart';
import 'package:lostone/models/persona_summary.dart';
import 'package:lostone/services/persona/persona_codec.dart';
import 'package:lostone/services/persona_library/persona_bytes_transform.dart';
import 'package:lostone/services/persona_library/persona_directory.dart';
import 'package:lostone/services/persona_library/persona_repository.dart';

Persona _persona({
  String id = 'persona-a',
  String displayName = '妈妈',
  DateTime? generatedAt,
  Confidence identityConfidence = Confidence.high,
  Confidence emotionConfidence = Confidence.medium,
  List<String> notes = const <String>[],
}) =>
    Persona(
      id: id,
      schemaVersion: kPersonaSchemaVersion,
      personaVersion: 1,
      generatedAt: generatedAt ?? DateTime.utc(2026, 8, 2, 10),
      notes: notes,
      identity: Identity(
        displayName: displayName,
        relationToUser: 'mother',
        confidence: identityConfidence,
      ),
      hardRules: const HardRules(),
      expressionStyle: const ExpressionStyle(confidence: Confidence.high),
      emotionalLogic: EmotionalLogic(
        positiveRatio: 0.5,
        negativeRatio: 0.1,
        confidence: emotionConfidence,
      ),
      relationalBehavior:
          const RelationalBehavior(confidence: Confidence.medium),
      tags: const <PersonaTag>[],
      memories: const Memories(timeline: TimelineSpan(start: null, end: null, messageCount: 0)),
      source: const PersonaSource(
        sources: <DataSource>{DataSource.wechat},
        totalMessages: 10,
        personMessages: 5,
        mergedMessageKeyHashes: <String>{},
        revisions: <SourceRevision>[
          SourceRevision(
            personaVersion: 1,
            personMessages: 5,
            totalMessages: 10,
          ),
        ],
      ),
    );

void main() {
  const PersonaJsonCodec codec = PersonaJsonCodec();

  late MemoryPersonaDirectory directory;
  late FilePersonaRepository repo;

  setUp(() {
    directory = MemoryPersonaDirectory();
    repo = FilePersonaRepository(directory: directory);
  });

  group('FilePersonaRepository.save', () {
    test('C1 持久化字节恰为 PersonaJsonCodec.encode（identity 变换）', () async {
      final Persona p = _persona();
      await repo.save(p);
      final List<int>? stored = await directory.readBytes(p.id);
      expect(stored, isNotNull);
      expect(stored, codec.encode(p));
    });

    test('C2 save 覆盖同 id 既有文件', () async {
      await repo.save(_persona(displayName: '旧'));
      await repo.save(_persona(displayName: '新'));
      final Persona loaded = await repo.load('persona-a');
      expect(loaded.identity.displayName, '新');
    });

    test('C3 schemaVersion 不匹配抛 PersonaStoreException', () async {
      final Persona bad = Persona(
        id: 'persona-b',
        schemaVersion: kPersonaSchemaVersion + 1,
        personaVersion: 1,
        generatedAt: DateTime.utc(2026),
        identity: const Identity(displayName: 'x'),
        hardRules: const HardRules(),
        expressionStyle: const ExpressionStyle(),
        emotionalLogic:
            const EmotionalLogic(positiveRatio: 0, negativeRatio: 0),
        relationalBehavior: const RelationalBehavior(),
        tags: const <PersonaTag>[],
        memories: const Memories(timeline: TimelineSpan(start: null, end: null, messageCount: 0)),
        source: const PersonaSource(
          sources: <DataSource>{DataSource.wechat},
          totalMessages: 0,
          personMessages: 0,
          mergedMessageKeyHashes: <String>{},
          revisions: <SourceRevision>[
            SourceRevision(
              personaVersion: 1,
              personMessages: 0,
              totalMessages: 0,
            ),
          ],
        ),
      );
      await expectLater(
        repo.save(bad),
        throwsA(isA<PersonaStoreException>()),
      );
    });

    test('C4 空 id 抛 PersonaStoreException', () async {
      await expectLater(
        repo.save(_persona(id: '')),
        throwsA(isA<PersonaStoreException>()),
      );
    });

    test('C5 底层写入失败包装为 PersonaStoreException', () async {
      final _ThrowingDirectory throwing = _ThrowingDirectory(onWrite: true);
      final FilePersonaRepository r =
          FilePersonaRepository(directory: throwing);
      await expectLater(
        r.save(_persona()),
        throwsA(isA<PersonaStoreException>()),
      );
    });
  });

  group('FilePersonaRepository.list', () {
    test('C6 空目录返回空结果', () async {
      final PersonaListResult result = await repo.list();
      expect(result.summaries, isEmpty);
      expect(result.skippedCount, 0);
    });

    test('C7 按 generatedAt 倒序，同刻按 id 升序', () async {
      await repo.save(_persona(
        id: 'persona-old',
        generatedAt: DateTime.utc(2026, 1, 1),
      ));
      await repo.save(_persona(
        id: 'persona-b',
        generatedAt: DateTime.utc(2026, 8, 2),
      ));
      await repo.save(_persona(
        id: 'persona-a',
        generatedAt: DateTime.utc(2026, 8, 2),
      ));
      final PersonaListResult result = await repo.list();
      expect(
        result.summaries.map((PersonaSummary s) => s.id).toList(),
        <String>['persona-a', 'persona-b', 'persona-old'],
      );
    });

    test('C8 跳过损坏文件并计数，其余正常返回', () async {
      await repo.save(_persona(id: 'persona-ok'));
      await directory.writeBytes('persona-bad', utf8.encode('{corrupt'));
      final PersonaListResult result = await repo.list();
      expect(result.summaries.map((PersonaSummary s) => s.id).toList(),
          <String>['persona-ok']);
      expect(result.skippedCount, 1);
    });

    test('C9 跳过 schema 过高的文件并计数', () async {
      await repo.save(_persona(id: 'persona-ok'));
      await directory.writeBytes(
        'persona-future',
        utf8.encode(json.encode(<String, dynamic>{'schemaVersion': 99})),
      );
      final PersonaListResult result = await repo.list();
      expect(result.summaries.map((PersonaSummary s) => s.id).toList(),
          <String>['persona-ok']);
      expect(result.skippedCount, 1);
    });

    test('C10 目录不可读抛 PersonaStoreException', () async {
      final _ThrowingDirectory throwing = _ThrowingDirectory(onList: true);
      final FilePersonaRepository r =
          FilePersonaRepository(directory: throwing);
      await expectLater(r.list(), throwsA(isA<PersonaStoreException>()));
    });

    test('C11 summary 投影携带最低层置信度与素材不足标记', () async {
      await repo.save(_persona(
        id: 'persona-low',
        emotionConfidence: Confidence.low,
        notes: <String>['原材料不足：情感逻辑层样本过少'],
      ));
      final PersonaListResult result = await repo.list();
      final PersonaSummary s = result.summaries.single;
      expect(s.lowestLayerConfidence, Confidence.low);
      expect(s.hasInsufficientMaterial, isTrue);
    });
  });

  group('FilePersonaRepository.load / delete', () {
    test('load 返回等值 Persona', () async {
      final Persona p = _persona();
      await repo.save(p);
      expect(await repo.load(p.id), p);
    });

    test('load 缺失抛 PersonaStoreException', () async {
      await expectLater(
        repo.load('missing'),
        throwsA(isA<PersonaStoreException>()),
      );
    });

    test('load schema 过高透传 PersonaSchemaException', () async {
      await directory.writeBytes(
        'persona-future',
        utf8.encode(json.encode(<String, dynamic>{'schemaVersion': 99})),
      );
      await expectLater(
        repo.load('persona-future'),
        throwsA(isA<PersonaSchemaException>()),
      );
    });

    test('load 损坏字节抛 PersonaStoreException', () async {
      await directory.writeBytes('persona-bad', utf8.encode('{corrupt'));
      await expectLater(
        repo.load('persona-bad'),
        throwsA(isA<PersonaStoreException>()),
      );
    });

    test('delete 幂等：删除不存在的 persona 不抛错', () async {
      await repo.delete('missing');
    });

    test('delete 后 load 抛 PersonaStoreException', () async {
      final Persona p = _persona();
      await repo.save(p);
      await repo.delete(p.id);
      await expectLater(
        repo.load(p.id),
        throwsA(isA<PersonaStoreException>()),
      );
    });

    test('identity 变换下 load 与 encode 往返相等', () async {
      const IdentityPersonaBytesTransform transform =
          IdentityPersonaBytesTransform();
      final FilePersonaRepository r = FilePersonaRepository(
        directory: directory,
        transform: transform,
      );
      final Persona p = _persona();
      await r.save(p);
      expect(await r.load(p.id), p);
    });
  });
}

class _ThrowingDirectory implements PersonaDirectory {
  _ThrowingDirectory({
    this.onList = false,
    this.onWrite = false,
  });

  final bool onList;
  final bool onWrite;

  @override
  Future<void> delete(String id) async {}

  @override
  Future<List<String>> listIds() async {
    if (onList) {
      throw const FileSystemException('boom');
    }
    return <String>[];
  }

  @override
  Future<List<int>?> readBytes(String id) async => null;

  @override
  Future<void> writeBytes(String id, List<int> bytes) async {
    if (onWrite) {
      throw const FileSystemException('boom');
    }
  }
}

class FileSystemException implements Exception {
  const FileSystemException(this.message);
  final String message;
}
