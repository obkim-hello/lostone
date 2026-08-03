import 'package:flutter_test/flutter_test.dart';
import 'package:lostone/models/evidence.dart';
import 'package:lostone/models/persona.dart';
import 'package:lostone/services/persona/persona_builder.dart';
import 'package:lostone/services/persona/persona_codec.dart';
import 'package:lostone/services/persona/prompt_template.dart';

import '../helpers/persona_fixtures.dart';

void main() {
  const DefaultPersonaBuilder builder = DefaultPersonaBuilder();
  const PersonaJsonCodec codec = PersonaJsonCodec();
  const DefaultPromptTemplate template = DefaultPromptTemplate();

  test('全链路：build → encode → decode → render', () async {
    final Persona built = await builder.build(synthConversation());
    final Persona roundTrip = codec.decode(codec.encode(built));
    expect(roundTrip, built);
    final String prompt = template.render(roundTrip);
    expect(prompt, isNotEmpty);
    expect(prompt, contains('妈妈'));
  });

  test('增量链路：v1 → update → v2，硬规则不变、版本递增', () async {
    final Persona v1 = await builder.build(baseConversation());
    final Persona v2 = await builder.update(v1, moreMessages());
    expect(v2.personaVersion, 2);
    expect(v2.id, v1.id);
    expect(v2.hardRules, v1.hardRules);
    expect(
      v2.source.personMessages,
      greaterThan(v1.source.personMessages),
    );
    final Persona roundTrip = codec.decode(codec.encode(v2));
    expect(roundTrip, v2);
  });

  test('幂等：重复并入相同内容不改变统计', () async {
    final Persona v1 = await builder.build(baseConversation());
    final Persona v2 = await builder.update(v1, sameContentDifferentIds());
    expect(v2.source.mergedMessageKeyHashes, v1.source.mergedMessageKeyHashes);
    expect(v2.source.personMessages, v1.source.personMessages);
  });

  test('置信度随样本量提升', () async {
    final Persona small = await builder.build(baseConversation());
    final Persona big = await builder.build(
      baseConversation(),
      options: const PersonaBuildOptions(
        minMessagesForHigh: 2,
        minMessagesForMedium: 1,
      ),
    );
    expect(small.identity.confidence, Confidence.low);
    expect(big.identity.confidence, Confidence.high);
  });
}
