import 'package:dkmads_ssp/dkmads_ssp.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('dkmads_ssp');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  test('video lifecycle callback is delivered to ad-unit handler', () async {
    final received = <String>[];
    await DkmadsSsp.trackVideoLifecycle(
      adUnitId: 'ad_1',
      onEvent: (eventName, payload) {
        received.add('$eventName:${payload['ad_unit_id']}');
      },
    );

    const codec = StandardMethodCodec();
    final envelope = codec.encodeMethodCall(const MethodCall('videoEvent', {
      'adUnitId': 'ad_1',
      'eventName': 'video_50',
      'payload': {'ad_unit_id': 'ad_1'},
    }));

    await ServicesBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
      'dkmads_ssp',
      envelope,
      (_) {},
    );

    expect(received, ['video_50:ad_1']);
  });

  test('stop lifecycle removes event handler and calls platform', () async {
    await DkmadsSsp.trackVideoLifecycle(adUnitId: 'ad_2', onEvent: (_, __) {});
    await DkmadsSsp.stopVideoLifecycleTracking('ad_2');

    expect(calls.where((c) => c.method == 'stopVideoLifecycleTracking').length, 1);
    expect(
      calls.where((c) => c.method == 'stopVideoLifecycleTracking').single.arguments,
      {'adUnitId': 'ad_2'},
    );
  });
}
