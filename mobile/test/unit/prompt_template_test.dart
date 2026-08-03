import 'package:characters/characters.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lostone/models/persona.dart';
import 'package:lostone/services/persona/persona_builder.dart';
import 'package:lostone/services/persona/prompt_template.dart';

import '../helpers/persona_fixtures.dart';

void main() {
  const DefaultPromptTemplate template = DefaultPromptTemplate();
  const DefaultPersonaBuilder builder = DefaultPersonaBuilder();

  group('PromptTemplate', () {
    test('同输入同输出（确定性）', () async {
      final Persona p = await builder.build(synthConversation());
      expect(template.render(p), template.render(p));
    });

    test('包含 displayName 且不含内部字段', () async {
      final Persona p = await builder.build(synthConversation());
      final String prompt = template.render(p);
      expect(prompt, contains(p.identity.displayName));
      expect(prompt, isNot(contains('messageKeyHashes')));
      expect(prompt, isNot(contains('schemaVersion')));
    });

    test('maxChars 限制输出长度', () async {
      final Persona p = await builder.build(synthConversation());
      final String prompt = template.render(
        p,
        options: const PromptOptions(maxChars: 20),
      );
      expect(prompt.characters.length, lessThanOrEqualTo(20));
    });

    test('detailed 比 concise 更长', () async {
      final Persona p = await builder.build(synthConversation());
      final String concise = template.render(
        p,
        options: const PromptOptions(
          tone: PromptTone.concise,
          maxChars: 100000,
        ),
      );
      final String detailed = template.render(
        p,
        options: const PromptOptions(
          tone: PromptTone.detailed,
          maxChars: 100000,
        ),
      );
      expect(detailed.length, greaterThanOrEqualTo(concise.length));
    });
  });
}
