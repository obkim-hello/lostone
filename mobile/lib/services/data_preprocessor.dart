import '../models/message.dart';

/// 消息预处理管线：清洗 → 去重 → 排序。
class DataPreprocessor {
  /// 创建预处理器。
  const DataPreprocessor();

  static final RegExp _controlChars =
      RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]');

  /// 执行完整预处理并返回结果与统计。
  ///
  /// 步骤：过滤系统消息 → 清洗正文 → 按内容复合键去重 → 按时间稳定升序。
  /// 满足 `input.length == messages.length + skipped`。
  ({List<Message> messages, int skipped}) process(List<Message> input) {
    int skipped = 0;
    final Set<String> seen = <String>{};
    final List<Message> kept = <Message>[];
    for (final Message message in input) {
      if (message.type == MessageType.system) {
        skipped++;
        continue;
      }
      final Message cleaned = _clean(message);
      if (!seen.add(_dedupKey(cleaned))) {
        skipped++;
        continue;
      }
      kept.add(cleaned);
    }
    return (messages: _sortByTimestamp(kept), skipped: skipped);
  }

  /// 去重键（唯一权威定义）：`source | senderId | timestamp.iso | content | type`。
  ///
  /// `Message.id` 不参与去重——它只是引用标识。
  String _dedupKey(Message m) => <String>[
        m.source.name,
        m.senderId,
        m.timestamp.toIso8601String(),
        m.content,
        m.type.name,
      ].join('|');

  Message _clean(Message m) {
    final String content =
        m.content.replaceAll(_controlChars, '').trim();
    if (content == m.content) {
      return m;
    }
    return Message(
      id: m.id,
      source: m.source,
      senderId: m.senderId,
      senderName: m.senderName,
      isFromMe: m.isFromMe,
      timestamp: m.timestamp,
      type: m.type,
      content: content,
      mediaPath: m.mediaPath,
      metadata: m.metadata,
    );
  }

  List<Message> _sortByTimestamp(List<Message> messages) {
    final List<int> order =
        List<int>.generate(messages.length, (int i) => i);
    order.sort((int a, int b) {
      final int byTime =
          messages[a].timestamp.compareTo(messages[b].timestamp);
      return byTime != 0 ? byTime : a.compareTo(b);
    });
    return <Message>[for (final int i in order) messages[i]];
  }
}
