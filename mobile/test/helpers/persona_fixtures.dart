import 'package:lostone/models/conversation.dart';
import 'package:lostone/models/message.dart';

/// 合成消息构造器（测试专用，非真实数据）。
Message synthMessage({
  required String id,
  required String senderId,
  required String senderName,
  required bool isFromMe,
  required DateTime timestamp,
  String content = '',
  DataSource source = DataSource.wechat,
  MessageType type = MessageType.text,
}) =>
    Message(
      id: id,
      source: source,
      senderId: senderId,
      senderName: senderName,
      isFromMe: isFromMe,
      timestamp: timestamp,
      type: type,
      content: content,
    );

DateTime _t(int day, [int hour = 20]) => DateTime.utc(2024, 1, day, hour);

ImportStats _stats(List<Message> messages) => ImportStats(
      totalParsed: messages.length,
      afterDedup: messages.length,
      skipped: 0,
      earliest: messages.isEmpty ? null : messages.first.timestamp,
      latest: messages.isEmpty ? null : messages.last.timestamp,
    );

Conversation _conversation(
  List<Message> messages, {
  List<String> participants = const <String>['mom', 'me'],
  DataSource source = DataSource.wechat,
}) =>
    Conversation(
      source: source,
      participants: participants,
      messages: messages,
      stats: _stats(messages),
    );

/// 含目标人物 + 用户、中英 emoji 混合。
Conversation synthConversation() => _conversation(<Message>[
      synthMessage(
        id: 'm1',
        senderId: 'mom',
        senderName: '妈妈',
        isFromMe: false,
        timestamp: _t(1),
        content: '早点睡 记得吃饭了吗 😊',
      ),
      synthMessage(
        id: 'm2',
        senderId: 'me',
        senderName: '我',
        isFromMe: true,
        timestamp: _t(1, 21),
        content: '好的 mom love you',
      ),
      synthMessage(
        id: 'm3',
        senderId: 'mom',
        senderName: '妈妈',
        isFromMe: false,
        timestamp: _t(2),
        content: '宝贝 天冷多穿点 别累着 ❤️',
      ),
      synthMessage(
        id: 'm4',
        senderId: 'mom',
        senderName: '妈妈',
        isFromMe: false,
        timestamp: _t(2, 21),
        content: '没事的 有我在 别担心',
      ),
    ]);

/// 空消息列表。
Conversation emptyConversation() => _conversation(const <Message>[]);

/// `isFromMe` true/false 混合，验证默认切分。
Conversation mixedFromMeConversation() => _conversation(<Message>[
      synthMessage(
        id: 'a1',
        senderId: 'mom',
        senderName: '妈妈',
        isFromMe: false,
        timestamp: _t(1),
        content: '吃饭了吗',
      ),
      synthMessage(
        id: 'a2',
        senderId: 'me',
        senderName: '我',
        isFromMe: true,
        timestamp: _t(1, 21),
        content: '吃了',
      ),
      synthMessage(
        id: 'a3',
        senderId: 'mom',
        senderName: '妈妈',
        isFromMe: false,
        timestamp: _t(2),
        content: '早点睡',
      ),
    ]);

/// 所有消息 `isFromMe==false`（parser 未判方向），验证方向分支守卫。
Conversation indeterminateDirectionConversation() => _conversation(<Message>[
      synthMessage(
        id: 'd1',
        senderId: 'mom',
        senderName: '妈妈',
        isFromMe: false,
        timestamp: _t(1),
        content: '早点睡',
      ),
      synthMessage(
        id: 'd2',
        senderId: 'mom',
        senderName: '妈妈',
        isFromMe: false,
        timestamp: _t(2),
        content: '吃饭了吗',
      ),
    ]);

/// 我方 + >1 个非我方发送者（群聊），验证多方分支守卫。
Conversation multiPartyConversation() => _conversation(
      <Message>[
        synthMessage(
          id: 'p1',
          senderId: 'me',
          senderName: '我',
          isFromMe: true,
          timestamp: _t(1),
          content: '大家好',
        ),
        synthMessage(
          id: 'p2',
          senderId: 'mom',
          senderName: '妈妈',
          isFromMe: false,
          timestamp: _t(1, 21),
          content: '早点睡',
        ),
        synthMessage(
          id: 'p3',
          senderId: 'dad',
          senderName: '爸爸',
          isFromMe: false,
          timestamp: _t(2),
          content: '注意身体',
        ),
      ],
      participants: const <String>['me', 'mom', 'dad'],
    );

/// 高频口头禅，验证计数/截断。
Conversation repeatedPhraseConversation() => _conversation(<Message>[
      for (int i = 0; i < 6; i++)
        synthMessage(
          id: 'r$i',
          senderId: 'mom',
          senderName: '妈妈',
          isFromMe: false,
          timestamp: _t(i + 1),
          content: '早点睡',
        ),
      synthMessage(
        id: 'ru',
        senderId: 'me',
        senderName: '我',
        isFromMe: true,
        timestamp: _t(8),
        content: '好',
      ),
    ]);

/// 增量测试基线会话。
Conversation baseConversation() => _conversation(<Message>[
      synthMessage(
        id: 'b1',
        senderId: 'mom',
        senderName: '妈妈',
        isFromMe: false,
        timestamp: _t(1),
        content: '早点睡',
      ),
      synthMessage(
        id: 'b2',
        senderId: 'me',
        senderName: '我',
        isFromMe: true,
        timestamp: _t(1, 21),
        content: '好',
      ),
      synthMessage(
        id: 'b3',
        senderId: 'mom',
        senderName: '妈妈',
        isFromMe: false,
        timestamp: _t(2),
        content: '吃饭了吗',
      ),
    ]);

/// 与 [baseConversation] 内容键相同但 `Message.id` 不同。
Conversation sameContentDifferentIds() => _conversation(<Message>[
      synthMessage(
        id: 'x1',
        senderId: 'mom',
        senderName: '妈妈',
        isFromMe: false,
        timestamp: _t(1),
        content: '早点睡',
      ),
      synthMessage(
        id: 'x2',
        senderId: 'me',
        senderName: '我',
        isFromMe: true,
        timestamp: _t(1, 21),
        content: '好',
      ),
      synthMessage(
        id: 'x3',
        senderId: 'mom',
        senderName: '妈妈',
        isFromMe: false,
        timestamp: _t(2),
        content: '吃饭了吗',
      ),
    ]);

/// 增量新增消息（第一批）。
Conversation moreMessages() => _conversation(<Message>[
      synthMessage(
        id: 'c1',
        senderId: 'mom',
        senderName: '妈妈',
        isFromMe: false,
        timestamp: _t(3),
        content: '多穿点',
      ),
      synthMessage(
        id: 'c2',
        senderId: 'me',
        senderName: '我',
        isFromMe: true,
        timestamp: _t(3, 21),
        content: '好的',
      ),
    ]);

/// 增量新增消息（第二批）。
Conversation evenMoreMessages() => _conversation(<Message>[
      synthMessage(
        id: 'e1',
        senderId: 'mom',
        senderName: '妈妈',
        isFromMe: false,
        timestamp: _t(4),
        content: '别累着',
      ),
      synthMessage(
        id: 'e2',
        senderId: 'me',
        senderName: '我',
        isFromMe: true,
        timestamp: _t(4, 21),
        content: '嗯',
      ),
    ]);

/// [baseConversation] 的超集（更多消息，参与者/目标发送者不变）。
Conversation supersetConversation() => _conversation(<Message>[
      ...baseConversation().messages,
      synthMessage(
        id: 's1',
        senderId: 'mom',
        senderName: '妈妈',
        isFromMe: false,
        timestamp: _t(5),
        content: '路上小心',
      ),
    ]);
