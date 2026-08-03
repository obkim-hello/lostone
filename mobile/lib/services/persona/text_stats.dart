import 'dart:convert';

import 'package:characters/characters.dart';
import 'package:crypto/crypto.dart';

import '../../models/evidence.dart';
import '../../models/message.dart';

/// `sampleExcerpt` 允许的最大字素簇长度。
const int kMaxExcerptGraphemes = 60;

/// 计算 [input] 的 SHA-256 十六进制哈希（纯本地、无网络）。
String sha256Hex(String input) => sha256.convert(utf8.encode(input)).toString();

/// 计算消息键的 SHA-256 十六进制哈希。
///
/// 消息键 = `source|senderId|timestamp.iso8601(UTC)|content|type`，逐字段对齐
/// 模块 002 `DataPreprocessor` 去重键（时间戳统一归一到 UTC 以保证确定性）。
/// 取 SHA-256 后不可逆，用于去重/幂等/回溯而不落原文。
String messageKeyHash(Message m) {
  final String key = <String>[
    m.source.name,
    m.senderId,
    m.timestamp.toUtc().toIso8601String(),
    m.content,
    m.type.name,
  ].join('|');
  return sha256Hex(key);
}

/// 把 [text] 按字素簇安全截断到 [max]（默认 [kMaxExcerptGraphemes]）。
String truncateExcerpt(String text, [int max = kMaxExcerptGraphemes]) {
  final Characters chars = text.characters;
  if (chars.length <= max) {
    return text;
  }
  return chars.take(max).toString();
}

/// 内置中文停用词（初版轻量表，可按需扩展）。
const Set<String> kDefaultStopwords = <String>{
  '的', '了', '是', '我', '你', '他', '她', '在', '和', '就', '都', '也',
  '吧', '啊', '呢', '吗', '哦', '嗯', '这', '那', '有', '没', '不', '要',
  'the', 'a', 'an', 'is', 'to', 'of', 'and', 'you', 'i', 'me', 'it',
};

/// 内置正向情感词表。
const Set<String> kPositiveLexicon = <String>{
  '开心', '高兴', '喜欢', '爱', '棒', '谢谢', '感谢', '加油', '放心',
  '乖', '宝贝', '想你', '好', '幸福', '哈哈', '嘻嘻',
  'happy', 'good', 'love', 'thanks', 'great',
};

/// 内置负向情感词表。
const Set<String> kNegativeLexicon = <String>{
  '难过', '生气', '讨厌', '累', '烦', '担心', '害怕', '哭', '对不起',
  '抱歉', '伤心', '痛', '难受',
  'sad', 'angry', 'tired', 'sorry', 'hate',
};

/// 内置安慰类话语模式。
const List<String> kComfortPatterns = <String>[
  '没事的', '没事', '别担心', '会好的', '慢慢来', '不哭', '有我在',
  '别怕', '放轻松', '别难过',
];

/// 内置关心/叮嘱类话语模式。
const List<String> kConcernPatterns = <String>[
  '吃饭了吗', '吃饭没', '早点睡', '多穿点', '注意身体', '路上小心',
  '记得', '按时', '喝水', '加衣服', '别累着',
];

/// 内置对用户的称呼词表。
const List<String> kAddressTerms = <String>[
  '宝贝', '宝', '乖', '亲爱的', '儿子', '女儿', '老公', '老婆', '孩子',
];

/// 内置纪念性关键词（触发关键事件）。
const List<String> kMemorialKeywords = <String>[
  '生日', '新年', '春节', '中秋', '结婚', '毕业', '搬家', '过年',
];

bool _isCjk(int rune) =>
    (rune >= 0x4E00 && rune <= 0x9FFF) ||
    (rune >= 0x3400 && rune <= 0x4DBF) ||
    (rune >= 0xF900 && rune <= 0xFAFF);

bool _isWordChar(int rune) =>
    (rune >= 0x30 && rune <= 0x39) ||
    (rune >= 0x41 && rune <= 0x5A) ||
    (rune >= 0x61 && rune <= 0x7A);

bool _isEmojiRune(int r) =>
    (r >= 0x1F300 && r <= 0x1FAFF) ||
    (r >= 0x2600 && r <= 0x27BF) ||
    (r >= 0x1F1E6 && r <= 0x1F1FF) ||
    r == 0x2764;

class _Token {
  const _Token(this.text, {required this.isCjk});
  final String text;
  final bool isCjk;
}

List<_Token> _tokenize(String text) {
  final List<_Token> tokens = <_Token>[];
  final StringBuffer word = StringBuffer();
  void flushWord() {
    if (word.isNotEmpty) {
      tokens.add(_Token(word.toString().toLowerCase(), isCjk: false));
      word.clear();
    }
  }

  for (final int rune in text.runes) {
    if (_isCjk(rune)) {
      flushWord();
      tokens.add(_Token(String.fromCharCode(rune), isCjk: true));
    } else if (_isWordChar(rune)) {
      word.writeCharCode(rune);
    } else {
      flushWord();
    }
  }
  flushWord();
  return tokens;
}

String _joinTokens(List<_Token> tokens) {
  final StringBuffer buffer = StringBuffer();
  for (int i = 0; i < tokens.length; i++) {
    if (i > 0 && (!tokens[i].isCjk || !tokens[i - 1].isCjk)) {
      buffer.write(' ');
    }
    buffer.write(tokens[i].text);
  }
  return buffer.toString();
}

List<TermStat> _rankCounts(Map<String, int> counts, int topN) {
  final List<MapEntry<String, int>> entries = counts.entries.toList()
    ..sort((MapEntry<String, int> a, MapEntry<String, int> b) {
      final int byCount = b.value.compareTo(a.value);
      return byCount != 0 ? byCount : a.key.compareTo(b.key);
    });
  return <TermStat>[
    for (final MapEntry<String, int> e in entries.take(topN))
      TermStat(term: e.key, count: e.value),
  ];
}

/// 统计 [texts] 内 [minN]..[maxN] 元的高频短语，返回按计数降序的 Top-N。
///
/// n-gram 不跨消息边界；一元词会剔除 [stopwords]。
List<TermStat> topNgrams(
  Iterable<String> texts, {
  int topN = 20,
  int minN = 2,
  int maxN = 3,
  Set<String> stopwords = kDefaultStopwords,
}) {
  final Map<String, int> counts = <String, int>{};
  for (final String text in texts) {
    final List<_Token> tokens = _tokenize(text);
    for (int n = minN; n <= maxN; n++) {
      for (int i = 0; i + n <= tokens.length; i++) {
        final List<_Token> window = tokens.sublist(i, i + n);
        final String term = _joinTokens(window);
        if (term.isEmpty) {
          continue;
        }
        if (n == 1 && stopwords.contains(term)) {
          continue;
        }
        counts[term] = (counts[term] ?? 0) + 1;
      }
    }
  }
  return _rankCounts(counts, topN);
}

/// 统计标点习惯，返回按计数降序的 Top-N。
List<TermStat> punctuationStats(Iterable<String> texts, {int topN = 20}) {
  const Set<String> marks = <String>{
    '…', '!', '！', '?', '？', '。', '，', '、', '~', '～', ';', '；',
    ':', '：', '.',
  };
  final Map<String, int> counts = <String, int>{};
  for (final String raw in texts) {
    final String text = raw.replaceAll('...', '…').replaceAll('。。。', '…');
    for (final String ch in text.characters) {
      if (marks.contains(ch)) {
        counts[ch] = (counts[ch] ?? 0) + 1;
      }
    }
  }
  return _rankCounts(counts, topN);
}

/// 统计 emoji 使用，返回按计数降序的 Top-N。
List<TermStat> emojiStats(Iterable<String> texts, {int topN = 20}) {
  final Map<String, int> counts = <String, int>{};
  for (final String text in texts) {
    for (final String grapheme in text.characters) {
      final bool isEmoji =
          grapheme.runes.any((int r) => _isEmojiRune(r));
      if (isEmoji) {
        counts[grapheme] = (counts[grapheme] ?? 0) + 1;
      }
    }
  }
  return _rankCounts(counts, topN);
}

/// 命中 [keywords] 的消息模式统计，返回按计数降序的 Top-N。
List<TermStat> keywordStats(
  Iterable<String> texts,
  List<String> keywords, {
  int topN = 20,
}) {
  final Map<String, int> counts = <String, int>{};
  for (final String text in texts) {
    for (final String keyword in keywords) {
      if (keyword.isEmpty) {
        continue;
      }
      int index = text.indexOf(keyword);
      while (index != -1) {
        counts[keyword] = (counts[keyword] ?? 0) + 1;
        index = text.indexOf(keyword, index + keyword.length);
      }
    }
  }
  return _rankCounts(counts, topN);
}

/// 情感比率：含 [lexicon] 任一词的消息数 / 总消息数，落在 [0,1]。
double sentimentRatio(Iterable<String> texts, Set<String> lexicon) {
  int total = 0;
  int hits = 0;
  for (final String text in texts) {
    total++;
    final String lower = text.toLowerCase();
    if (lexicon.any(lower.contains)) {
      hits++;
    }
  }
  if (total == 0) {
    return 0;
  }
  return hits / total;
}
