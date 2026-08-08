import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lostone/services/llm/cloud_runtime.dart';
import 'package:lostone/services/llm/http_cloud_transport.dart';

http.Response _json(Object body, [int status = 200]) => http.Response(
      body is String ? body : jsonEncode(body),
      status,
      headers: <String, String>{
        'content-type': 'application/json; charset=utf-8',
      },
    );

CloudRequest _request({
  String prompt = '在吗',
  String model = 'test-model',
  String apiKey = 'sk-test',
  double temperature = 0.3,
  int? maxNewTokens,
}) =>
    CloudRequest(
      prompt: prompt,
      model: model,
      apiKey: apiKey,
      temperature: temperature,
      maxNewTokens: maxNewTokens,
    );

void main() {
  group('HttpCloudTransport · OpenAI 线缆', () {
    test('complete 成功 → 命中 /chat/completions，携带 Bearter 头与 body，返回内容',
        () async {
      late http.Request captured;
      final MockClient client = MockClient((http.Request req) async {
        captured = req;
        return _json(<String, dynamic>{
          'choices': <dynamic>[
            <String, dynamic>{
              'message': <String, String>{'content': '在的呀'},
            },
          ],
        });
      });
      final HttpCloudTransport transport = HttpCloudTransport(
        format: CloudProvider.openai,
        client: client,
      );

      final String text = await transport.complete(_request(maxNewTokens: 64));
      expect(text, '在的呀');
      expect(
        captured.url.toString(),
        'https://api.openai.com/v1/chat/completions',
      );
      expect(captured.headers['Authorization'], 'Bearer sk-test');
      final Map<String, dynamic> body =
          jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['model'], 'test-model');
      expect(body['temperature'], 0.3);
      expect(body['max_tokens'], 64);
      final List<dynamic> messages = body['messages'] as List<dynamic>;
      expect((messages.single as Map)['role'], 'user');
      expect((messages.single as Map)['content'], '在吗');
    });

    test('省略 maxNewTokens → body 不含 max_tokens', () async {
      late http.Request captured;
      final MockClient client = MockClient((http.Request req) async {
        captured = req;
        return _json(<String, dynamic>{
          'choices': <dynamic>[
            <String, dynamic>{
              'message': <String, String>{'content': 'ok'},
            },
          ],
        });
      });
      await HttpCloudTransport(format: CloudProvider.openai, client: client)
          .complete(_request());
      final Map<String, dynamic> body =
          jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body.containsKey('max_tokens'), isFalse);
    });

    test('自定义 endpoint（含结尾斜杠）被规整', () async {
      late Uri url;
      final MockClient client = MockClient((http.Request req) async {
        url = req.url;
        return _json(<String, dynamic>{
          'choices': <dynamic>[
            <String, dynamic>{
              'message': <String, String>{'content': 'ok'},
            },
          ],
        });
      });
      await HttpCloudTransport(
        format: CloudProvider.openai,
        endpoint: 'https://gw.example.com/v1/',
        client: client,
      ).complete(_request());
      expect(url.toString(), 'https://gw.example.com/v1/chat/completions');
    });

    test('粘贴完整 completions URL 被去尾（不重复拼接路径）', () async {
      late Uri url;
      final MockClient client = MockClient((http.Request req) async {
        url = req.url;
        return _json(<String, dynamic>{
          'choices': <dynamic>[
            <String, dynamic>{
              'message': <String, String>{'content': 'ok'},
            },
          ],
        });
      });
      await HttpCloudTransport(
        format: CloudProvider.openai,
        endpoint: 'https://api.z.ai/api/paas/v4/chat/completions',
        client: client,
      ).complete(_request());
      expect(
        url.toString(),
        'https://api.z.ai/api/paas/v4/chat/completions',
      );
    });

    test('z.ai 基址（.../paas/v4）拼接为 completions 路径', () async {
      late Uri url;
      final MockClient client = MockClient((http.Request req) async {
        url = req.url;
        return _json(<String, dynamic>{
          'choices': <dynamic>[
            <String, dynamic>{
              'message': <String, String>{'content': 'ok'},
            },
          ],
        });
      });
      await HttpCloudTransport(
        format: CloudProvider.openai,
        endpoint: 'https://api.z.ai/api/paas/v4',
        client: client,
      ).complete(_request());
      expect(
        url.toString(),
        'https://api.z.ai/api/paas/v4/chat/completions',
      );
    });

    test('reasoning_content 兜底（content 缺失的推理模型）', () async {
      final MockClient client = MockClient((http.Request req) async =>
          _json(<String, dynamic>{
            'choices': <dynamic>[
              <String, dynamic>{
                'message': <String, dynamic>{
                  'content': null,
                  'reasoning_content': '想了想',
                },
              },
            ],
          }));
      final String text =
          await HttpCloudTransport(format: CloudProvider.openai, client: client)
              .complete(_request());
      expect(text, '想了想');
    });
  });

  group('HttpCloudTransport · Anthropic 线缆', () {
    test('complete 成功 → 命中 /messages，携带 x-api-key + 版本头，拼接 text 块',
        () async {
      late http.Request captured;
      final MockClient client = MockClient((http.Request req) async {
        captured = req;
        return _json(<String, dynamic>{
          'content': <dynamic>[
            <String, String>{'type': 'text', 'text': '在'},
            <String, String>{'type': 'text', 'text': '的呀'},
          ],
        });
      });
      final HttpCloudTransport transport = HttpCloudTransport(
        format: CloudProvider.anthropic,
        client: client,
      );

      final String text = await transport.complete(_request());
      expect(text, '在的呀');
      expect(captured.url.toString(), 'https://api.anthropic.com/v1/messages');
      expect(captured.headers['x-api-key'], 'sk-test');
      expect(captured.headers['anthropic-version'], '2023-06-01');
      final Map<String, dynamic> body =
          jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['max_tokens'], 4096);
    });
  });

  group('HttpCloudTransport · 错误映射', () {
    test('非 2xx → CloudHttpException 携带状态码与响应体片段', () async {
      final MockClient client = MockClient(
        (http.Request req) async => http.Response('{"error":"bad key"}', 401),
      );
      final HttpCloudTransport transport =
          HttpCloudTransport(format: CloudProvider.openai, client: client);
      await expectLater(
        transport.complete(_request()),
        throwsA(isA<CloudHttpException>()
            .having((CloudHttpException e) => e.statusCode, 'statusCode', 401)
            .having((CloudHttpException e) => e.detail, 'detail',
                contains('bad key'))),
      );
    });

    test('连接失败 → CloudHttpException(isNetworkError)', () async {
      final MockClient client =
          MockClient((http.Request req) async => throw Exception('boom'));
      final HttpCloudTransport transport =
          HttpCloudTransport(format: CloudProvider.openai, client: client);
      await expectLater(
        transport.complete(_request()),
        throwsA(isA<CloudHttpException>()
            .having((CloudHttpException e) => e.isNetworkError, 'network', true)),
      );
    });

    test('响应体缺内容 → CloudHttpException 携带 detail', () async {
      final MockClient client = MockClient((http.Request req) async =>
          _json(<String, dynamic>{'choices': <dynamic>[]}));
      final HttpCloudTransport transport =
          HttpCloudTransport(format: CloudProvider.openai, client: client);
      await expectLater(
        transport.complete(_request()),
        throwsA(isA<CloudHttpException>()
            .having((CloudHttpException e) => e.detail, 'detail', isNotNull)),
      );
    });
  });

  group('HttpCloudTransport · stream 一次性回退', () {
    test('stream 产出单块完整文本', () async {
      final MockClient client = MockClient((http.Request req) async =>
          _json(<String, dynamic>{
            'choices': <dynamic>[
              <String, dynamic>{
                'message': <String, String>{'content': '完整回复'},
              },
            ],
          }));
      final HttpCloudTransport transport =
          HttpCloudTransport(format: CloudProvider.openai, client: client);
      final List<String> out = await transport.stream(_request()).toList();
      expect(out, <String>['完整回复']);
    });
  });
}
