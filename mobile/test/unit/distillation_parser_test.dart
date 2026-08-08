import 'package:flutter_test/flutter_test.dart';
import 'package:lostone/services/llm/distilled_persona.dart';

void main() {
  const DistillationParser parser = DistillationParser();

  group('DistillationParser.parse', () {
    test('解析规范 JSON 的分层字段', () {
      const String raw = '''
{
  "identity": {"displayName": "妈妈", "relationToUser": "母亲", "aliases": ["老妈"]},
  "coreRules": {"forbiddenTopics": ["病情"], "mustNeverClaim": ["我还活着"], "safetyNotes": ["温柔"]},
  "expression": {"catchphrases": ["记得吃饭"], "emojis": ["🌸"], "punctuation": ["……"], "avgMessageLength": 12},
  "emotion": {"positiveRatio": 0.7, "negativeRatio": 0.1, "comfortPatterns": ["别怕"], "concernPatterns": ["天冷加衣"]},
  "relation": {"termsForUser": ["宝贝"], "initiationRatio": 0.6, "avgResponseGapMinutes": 5.5},
  "exemplars": ["记得吃饭，别累着"],
  "preferences": ["喝茶"],
  "tags": ["关心型"],
  "insufficientLayers": ["relation"]
}
''';
      final DistilledPersona d = parser.parse(raw);

      expect(d.displayName, '妈妈');
      expect(d.relationToUser, '母亲');
      expect(d.aliases, <String>['老妈']);
      expect(d.forbiddenTopics, <String>['病情']);
      expect(d.mustNeverClaim, <String>['我还活着']);
      expect(d.catchphrases, <String>['记得吃饭']);
      expect(d.emojis, <String>['🌸']);
      expect(d.punctuation, <String>['……']);
      expect(d.positiveRatio, 0.7);
      expect(d.negativeRatio, 0.1);
      expect(d.comfortPatterns, <String>['别怕']);
      expect(d.concernPatterns, <String>['天冷加衣']);
      expect(d.termsForUser, <String>['宝贝']);
      expect(d.initiationRatio, 0.6);
      expect(d.avgResponseGapMinutes, 5.5);
      expect(d.exemplars, <String>['记得吃饭，别累着']);
      expect(d.preferences, <String>['喝茶']);
      expect(d.tags, <String>['关心型']);
      expect(d.insufficientLayers, <String>['relation']);
    });

    test('容忍 ```json 代码围栏与前后散文', () {
      const String raw = '好的，分析如下：\n```json\n{"identity": {"displayName": "阿明"}}\n```\n以上。';
      final DistilledPersona d = parser.parse(raw);
      expect(d.displayName, '阿明');
    });

    test('容忍列表/对象末尾多余逗号', () {
      final DistilledPersona d =
          parser.parse('{"tags": ["a", "b",], "preferences": ["x",],}');
      expect(d.tags, <String>['a', 'b']);
      expect(d.preferences, <String>['x']);
    });

    test('容忍模型追加的第二个对象（取首个完整对象）', () {
      const String raw =
          '{"identity": {"displayName": "阿明"}}\n{"note": "ignored"}';
      final DistilledPersona d = parser.parse(raw);
      expect(d.displayName, '阿明');
    });

    test('缺省字段回落默认（不抛错）', () {
      final DistilledPersona d = parser.parse('{"identity": {}}');
      expect(d.displayName, isNull);
      expect(d.catchphrases, isEmpty);
      expect(d.tags, isEmpty);
      expect(d.positiveRatio, isNull);
    });

    test('单字段类型不符从宽处理（aliases 非数组 → 空）', () {
      final DistilledPersona d =
          parser.parse('{"identity": {"displayName": "x", "aliases": "老妈"}}');
      expect(d.displayName, 'x');
      expect(d.aliases, isEmpty);
    });

    test('列表内非字符串/空串被剔除并去空白', () {
      final DistilledPersona d =
          parser.parse('{"tags": ["关心型", "", 42, "  黏人  "]}');
      expect(d.tags, <String>['关心型', '黏人']);
    });

    test('无 JSON 对象 → 抛 DistillationFormatException', () {
      expect(
        () => parser.parse('这里没有花括号'),
        throwsA(isA<DistillationFormatException>()),
      );
    });

    test('花括号内非法 JSON → 抛 DistillationFormatException', () {
      expect(
        () => parser.parse('{ 这不是 json }'),
        throwsA(isA<DistillationFormatException>()),
      );
    });

    test('顶层为 JSON 数组 → 抛 DistillationFormatException', () {
      expect(
        () => parser.parse('[1, 2, 3]'),
        throwsA(isA<DistillationFormatException>()),
      );
    });
  });
}
