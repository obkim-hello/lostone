import 'dart:convert';

import '../../models/evidence.dart';
import '../../models/memories.dart';
import '../../models/message.dart';
import '../../models/persona.dart';
import '../../models/persona_layers.dart';
import 'text_stats.dart';

/// `.persona` schema 版本不受支持（通常是高于当前版本）时抛出。
class PersonaSchemaException implements Exception {
  /// 创建异常。
  const PersonaSchemaException(this.message);

  /// 说明信息。
  final String message;

  @override
  String toString() => 'PersonaSchemaException: $message';
}

/// Persona 序列化 / 反序列化契约。
abstract class PersonaCodec {
  /// 序列化为字节（无损）。
  List<int> encode(Persona persona);

  /// 反序列化；遇非法数据抛 [FormatException]，schema 过高抛
  /// [PersonaSchemaException]。
  Persona decode(List<int> bytes);
}

/// 基于 UTF-8 JSON 的默认编解码器。
class PersonaJsonCodec implements PersonaCodec {
  /// 创建编解码器。
  const PersonaJsonCodec();

  @override
  List<int> encode(Persona persona) =>
      utf8.encode(json.encode(_persona(persona)));

  @override
  Persona decode(List<int> bytes) {
    final Object? decoded;
    try {
      decoded = json.decode(utf8.decode(bytes));
    } on FormatException {
      rethrow;
    }
    final Map<String, dynamic> root = _map(decoded, 'root');

    final int schemaVersion = _int(root['schemaVersion'], 'schemaVersion');
    if (schemaVersion > kPersonaSchemaVersion) {
      throw PersonaSchemaException(
        'schemaVersion $schemaVersion > $kPersonaSchemaVersion',
      );
    }

    final int personaVersion = _int(root['personaVersion'], 'personaVersion');
    if (personaVersion < 1) {
      throw const FormatException('personaVersion 必须 ≥ 1');
    }

    return Persona(
      id: _string(root['id'], 'id'),
      schemaVersion: schemaVersion,
      personaVersion: personaVersion,
      generatedAt: _dateTime(root['generatedAt'], 'generatedAt'),
      identity: _identity(_map(root['identity'], 'identity')),
      hardRules: _hardRules(_map(root['hardRules'], 'hardRules')),
      expressionStyle:
          _expression(_map(root['expressionStyle'], 'expressionStyle')),
      emotionalLogic:
          _emotion(_map(root['emotionalLogic'], 'emotionalLogic')),
      relationalBehavior:
          _relation(_map(root['relationalBehavior'], 'relationalBehavior')),
      tags: <PersonaTag>[
        for (final Object? t in _list(root['tags'], 'tags'))
          _tag(_map(t, 'tags[]')),
      ],
      memories: _memories(_map(root['memories'], 'memories')),
      source: _source(_map(root['source'], 'source'), personaVersion),
    );
  }

  Map<String, dynamic> _persona(Persona p) => <String, dynamic>{
        'schemaVersion': p.schemaVersion,
        'personaVersion': p.personaVersion,
        'id': p.id,
        'generatedAt': p.generatedAt.toUtc().toIso8601String(),
        'identity': <String, dynamic>{
          'displayName': p.identity.displayName,
          'relationToUser': p.identity.relationToUser,
          'aliases': p.identity.aliases,
          'confidence': p.identity.confidence.name,
        },
        'hardRules': <String, dynamic>{
          'forbiddenTopics': p.hardRules.forbiddenTopics,
          'mustNeverClaim': p.hardRules.mustNeverClaim,
          'safetyNotes': p.hardRules.safetyNotes,
        },
        'expressionStyle': <String, dynamic>{
          'catchphrases': _terms(p.expressionStyle.catchphrases),
          'emojiUsage': _terms(p.expressionStyle.emojiUsage),
          'punctuation': _terms(p.expressionStyle.punctuation),
          'avgMessageLength': p.expressionStyle.avgMessageLength,
          'confidence': p.expressionStyle.confidence.name,
        },
        'emotionalLogic': <String, dynamic>{
          'positiveRatio': p.emotionalLogic.positiveRatio,
          'negativeRatio': p.emotionalLogic.negativeRatio,
          'comfortPatterns': _terms(p.emotionalLogic.comfortPatterns),
          'concernPatterns': _terms(p.emotionalLogic.concernPatterns),
          'confidence': p.emotionalLogic.confidence.name,
        },
        'relationalBehavior': <String, dynamic>{
          'termsForUser': _terms(p.relationalBehavior.termsForUser),
          'initiationRatio': p.relationalBehavior.initiationRatio,
          'avgResponseGapMinutes':
              p.relationalBehavior.avgResponseGapMinutes,
          'confidence': p.relationalBehavior.confidence.name,
        },
        'tags': <Map<String, dynamic>>[
          for (final PersonaTag t in p.tags)
            <String, dynamic>{
              'label': t.label,
              'confidence': t.confidence.name,
              'evidence': _evidence(t.evidence),
            },
        ],
        'memories': <String, dynamic>{
          'timeline': <String, dynamic>{
            'start': p.memories.timeline.start?.toUtc().toIso8601String(),
            'end': p.memories.timeline.end?.toUtc().toIso8601String(),
            'messageCount': p.memories.timeline.messageCount,
            'activeHours': <String, int>{
              for (final MapEntry<int, int> e
                  in p.memories.timeline.activeHours.entries)
                e.key.toString(): e.value,
            },
          },
          'keyEvents': <Map<String, dynamic>>[
            for (final KeyEvent e in p.memories.keyEvents)
              <String, dynamic>{
                'at': e.at.toUtc().toIso8601String(),
                'summary': e.summary,
                'evidence': _evidence(e.evidence),
              },
          ],
          'preferences': <Map<String, dynamic>>[
            for (final Preference pref in p.memories.preferences)
              <String, dynamic>{
                'term': pref.term,
                'count': pref.count,
                'evidence': _evidence(pref.evidence),
              },
          ],
        },
        'source': <String, dynamic>{
          'sources': <String>[
            for (final DataSource s in p.source.sources) s.name,
          ],
          'totalMessages': p.source.totalMessages,
          'personMessages': p.source.personMessages,
          'mergedMessageKeyHashes':
              p.source.mergedMessageKeyHashes.toList(),
          'segmentationResolved': p.source.segmentationResolved,
          'revisions': <Map<String, dynamic>>[
            for (final SourceRevision r in p.source.revisions)
              <String, dynamic>{
                'personaVersion': r.personaVersion,
                'personMessages': r.personMessages,
                'totalMessages': r.totalMessages,
              },
          ],
        },
      };

  List<Map<String, dynamic>> _terms(List<TermStat> stats) =>
      <Map<String, dynamic>>[
        for (final TermStat s in stats)
          <String, dynamic>{'term': s.term, 'count': s.count},
      ];

  Map<String, dynamic> _evidence(Evidence e) => <String, dynamic>{
        'messageKeyHashes': e.messageKeyHashes,
        'sampleExcerpt':
            e.sampleExcerpt == null ? null : truncateExcerpt(e.sampleExcerpt!),
        'occurrences': e.occurrences,
      };

  Identity _identity(Map<String, dynamic> m) => Identity(
        displayName: _string(m['displayName'], 'identity.displayName'),
        relationToUser: m['relationToUser'] == null
            ? null
            : _string(m['relationToUser'], 'identity.relationToUser'),
        aliases: _strings(m['aliases'], 'identity.aliases'),
        confidence: _confidence(m['confidence'], 'identity.confidence'),
      );

  HardRules _hardRules(Map<String, dynamic> m) => HardRules(
        forbiddenTopics:
            _strings(m['forbiddenTopics'], 'hardRules.forbiddenTopics'),
        mustNeverClaim:
            _strings(m['mustNeverClaim'], 'hardRules.mustNeverClaim'),
        safetyNotes: _strings(m['safetyNotes'], 'hardRules.safetyNotes'),
      );

  ExpressionStyle _expression(Map<String, dynamic> m) => ExpressionStyle(
        catchphrases: _termList(m['catchphrases'], 'catchphrases'),
        emojiUsage: _termList(m['emojiUsage'], 'emojiUsage'),
        punctuation: _termList(m['punctuation'], 'punctuation'),
        avgMessageLength: _int(m['avgMessageLength'], 'avgMessageLength'),
        confidence:
            _confidence(m['confidence'], 'expressionStyle.confidence'),
      );

  EmotionalLogic _emotion(Map<String, dynamic> m) => EmotionalLogic(
        positiveRatio: _ratio(m['positiveRatio'], 'positiveRatio'),
        negativeRatio: _ratio(m['negativeRatio'], 'negativeRatio'),
        comfortPatterns: _termList(m['comfortPatterns'], 'comfortPatterns'),
        concernPatterns: _termList(m['concernPatterns'], 'concernPatterns'),
        confidence: _confidence(m['confidence'], 'emotionalLogic.confidence'),
      );

  RelationalBehavior _relation(Map<String, dynamic> m) => RelationalBehavior(
        termsForUser: _termList(m['termsForUser'], 'termsForUser'),
        initiationRatio: _ratio(m['initiationRatio'], 'initiationRatio'),
        avgResponseGapMinutes:
            _double(m['avgResponseGapMinutes'], 'avgResponseGapMinutes'),
        confidence:
            _confidence(m['confidence'], 'relationalBehavior.confidence'),
      );

  PersonaTag _tag(Map<String, dynamic> m) {
    final String label = _string(m['label'], 'tags[].label');
    if (label.isEmpty) {
      throw const FormatException('tags[].label 不能为空');
    }
    return PersonaTag(
      label: label,
      confidence: _confidence(m['confidence'], 'tags[].confidence'),
      evidence: _evidenceOf(_map(m['evidence'], 'tags[].evidence')),
    );
  }

  Memories _memories(Map<String, dynamic> m) {
    final Map<String, dynamic> timeline = _map(m['timeline'], 'timeline');
    return Memories(
      timeline: TimelineSpan(
        start: _optionalDateTime(timeline['start'], 'timeline.start'),
        end: _optionalDateTime(timeline['end'], 'timeline.end'),
        messageCount: _int(timeline['messageCount'], 'timeline.messageCount'),
        activeHours: _activeHours(timeline['activeHours']),
      ),
      keyEvents: <KeyEvent>[
        for (final Object? e in _list(m['keyEvents'], 'keyEvents'))
          _keyEvent(_map(e, 'keyEvents[]')),
      ],
      preferences: <Preference>[
        for (final Object? p in _list(m['preferences'], 'preferences'))
          _preference(_map(p, 'preferences[]')),
      ],
    );
  }

  KeyEvent _keyEvent(Map<String, dynamic> m) => KeyEvent(
        at: _dateTime(m['at'], 'keyEvents[].at'),
        summary: _string(m['summary'], 'keyEvents[].summary'),
        evidence: _evidenceOf(_map(m['evidence'], 'keyEvents[].evidence')),
      );

  Preference _preference(Map<String, dynamic> m) => Preference(
        term: _string(m['term'], 'preferences[].term'),
        count: _int(m['count'], 'preferences[].count'),
        evidence: _evidenceOf(_map(m['evidence'], 'preferences[].evidence')),
      );

  PersonaSource _source(Map<String, dynamic> m, int personaVersion) {
    final List<SourceRevision> revisions = <SourceRevision>[
      for (final Object? r in _list(m['revisions'], 'source.revisions'))
        _revision(_map(r, 'revisions[]')),
    ];
    for (int i = 0; i < revisions.length; i++) {
      if (revisions[i].personaVersion != i + 1) {
        throw FormatException(
          'source.revisions 非连续：期望 ${i + 1}，实为 '
          '${revisions[i].personaVersion}',
        );
      }
    }
    if (revisions.isEmpty || revisions.last.personaVersion != personaVersion) {
      throw const FormatException('source.revisions 末条须等于 personaVersion');
    }

    final Object? segRaw = m['segmentationResolved'];
    final bool segmentationResolved;
    if (segRaw == null) {
      segmentationResolved = true;
    } else if (segRaw is bool) {
      segmentationResolved = segRaw;
    } else {
      throw const FormatException('source.segmentationResolved 须为布尔');
    }

    return PersonaSource(
      sources: <DataSource>{
        for (final Object? s in _list(m['sources'], 'source.sources'))
          _dataSource(s),
      },
      totalMessages: _int(m['totalMessages'], 'source.totalMessages'),
      personMessages: _int(m['personMessages'], 'source.personMessages'),
      mergedMessageKeyHashes: <String>{
        for (final Object? h in _list(
          m['mergedMessageKeyHashes'],
          'source.mergedMessageKeyHashes',
        ))
          _hash(h, 'source.mergedMessageKeyHashes[]'),
      },
      revisions: revisions,
      segmentationResolved: segmentationResolved,
    );
  }

  SourceRevision _revision(Map<String, dynamic> m) => SourceRevision(
        personaVersion:
            _int(m['personaVersion'], 'revisions[].personaVersion'),
        personMessages:
            _int(m['personMessages'], 'revisions[].personMessages'),
        totalMessages: _int(m['totalMessages'], 'revisions[].totalMessages'),
      );

  DataSource _dataSource(Object? v) {
    final String name = _string(v, 'source.sources[]');
    for (final DataSource s in DataSource.values) {
      if (s.name == name) {
        return s;
      }
    }
    throw FormatException('未知数据源：$name');
  }

  Evidence _evidenceOf(Map<String, dynamic> m) {
    final Object? excerpt = m['sampleExcerpt'];
    return Evidence(
      messageKeyHashes: <String>[
        for (final Object? h in _list(
          m['messageKeyHashes'],
          'evidence.messageKeyHashes',
        ))
          _hash(h, 'evidence.messageKeyHashes[]'),
      ],
      sampleExcerpt: excerpt == null
          ? null
          : truncateExcerpt(_string(excerpt, 'evidence.sampleExcerpt')),
      occurrences: _int(m['occurrences'], 'evidence.occurrences'),
    );
  }

  List<TermStat> _termList(Object? v, String field) => <TermStat>[
        for (final Object? e in _list(v, field))
          () {
            final Map<String, dynamic> m = _map(e, '$field[]');
            return TermStat(
              term: _string(m['term'], '$field[].term'),
              count: _int(m['count'], '$field[].count'),
            );
          }(),
      ];

  Map<int, int> _activeHours(Object? v) {
    if (v == null) {
      return const <int, int>{};
    }
    final Map<String, dynamic> m = _map(v, 'timeline.activeHours');
    final Map<int, int> out = <int, int>{};
    for (final MapEntry<String, dynamic> e in m.entries) {
      final int? hour = int.tryParse(e.key);
      if (hour == null) {
        throw FormatException('timeline.activeHours 键非整数：${e.key}');
      }
      out[hour] = _int(e.value, 'timeline.activeHours[${e.key}]');
    }
    final List<int> sorted = out.keys.toList()..sort();
    return <int, int>{for (final int h in sorted) h: out[h]!};
  }

  String _hash(Object? v, String field) {
    final String s = _string(v, field);
    if (s.contains('|')) {
      throw FormatException('$field 含原文分隔符 "|"');
    }
    return s;
  }

  Map<String, dynamic> _map(Object? v, String field) {
    if (v is Map<String, dynamic>) {
      return v;
    }
    if (v is Map) {
      return v.cast<String, dynamic>();
    }
    throw FormatException('$field 须为对象');
  }

  List<Object?> _list(Object? v, String field) {
    if (v is List) {
      return v;
    }
    throw FormatException('$field 须为数组');
  }

  String _string(Object? v, String field) {
    if (v is String) {
      return v;
    }
    throw FormatException('$field 须为字符串');
  }

  List<String> _strings(Object? v, String field) => <String>[
        for (final Object? e in _list(v, field)) _string(e, '$field[]'),
      ];

  int _int(Object? v, String field) {
    if (v is int) {
      return v;
    }
    throw FormatException('$field 须为整数');
  }

  double _double(Object? v, String field) {
    if (v is num) {
      return v.toDouble();
    }
    throw FormatException('$field 须为数值');
  }

  double _ratio(Object? v, String field) {
    final double d = _double(v, field);
    const double eps = 1e-6;
    if (d < -eps || d > 1 + eps) {
      throw FormatException('$field 越界 [0,1]：$d');
    }
    return d.clamp(0.0, 1.0);
  }

  Confidence _confidence(Object? v, String field) {
    switch (_string(v, field)) {
      case 'low':
        return Confidence.low;
      case 'medium':
        return Confidence.medium;
      case 'high':
        return Confidence.high;
      default:
        throw FormatException('$field 非法置信度');
    }
  }

  DateTime _dateTime(Object? v, String field) {
    final DateTime? d = DateTime.tryParse(_string(v, field));
    if (d == null) {
      throw FormatException('$field 时间不可解析');
    }
    return d.toUtc();
  }

  DateTime? _optionalDateTime(Object? v, String field) {
    if (v == null) {
      return null;
    }
    return _dateTime(v, field);
  }
}
