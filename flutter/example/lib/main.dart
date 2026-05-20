import 'package:dkmads_ssp/dkmads_ssp.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const DkmadsExampleApp());
}

class DkmadsExampleApp extends StatelessWidget {
  const DkmadsExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DKMads SSP Example',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      home: const ExampleHomePage(),
    );
  }
}

class ExampleHomePage extends StatefulWidget {
  const ExampleHomePage({super.key});

  @override
  State<ExampleHomePage> createState() => _ExampleHomePageState();
}

class _ExampleHomePageState extends State<ExampleHomePage> {
  final List<String> _logs = <String>[];
  final TextEditingController _integrationKeyCtrl = TextEditingController(text: 'int_xxx');
  final TextEditingController _propertyIdCtrl = TextEditingController(text: 'property_uuid');
  final TextEditingController _adUnitCtrl = TextEditingController(text: 'ad_unit_uuid');

  void _log(String line) {
    setState(() => _logs.insert(0, '${DateTime.now().toIso8601String()}  $line'));
  }

  Future<void> _initialize() async {
    await DkmadsSsp.initialize(
      integrationKey: _integrationKeyCtrl.text.trim(),
      propertyId: _propertyIdCtrl.text.trim(),
      debug: true,
    );
    await DkmadsSsp.setConsent(
      gdpr: false,
      ccpa: false,
    );
    await DkmadsSsp.setUserData({
      'device_pid': 'flutter_device_123',
      'user_pid': 'flutter_user_abc',
    });
    _log('Initialized SDK and consent/user data.');
  }

  Future<void> _startVideoLifecycle() async {
    final adUnitId = _adUnitCtrl.text.trim();
    await DkmadsSsp.trackVideoLifecycle(
      adUnitId: adUnitId,
      skippable: true,
      onEvent: (eventName, payload) {
        _log('callback $eventName payload=$payload');
      },
    );
    _log('Started lifecycle tracking for $adUnitId');
  }

  Future<void> _emitSampleSequence() async {
    final adUnitId = _adUnitCtrl.text.trim();
    const events = <String>[
      'video_start',
      'video_25',
      'video_50',
      'video_pause',
      'video_resume',
      'video_75',
      'video_unmute',
      'video_100',
    ];
    for (final event in events) {
      await DkmadsSsp.emitVideoEvent(
        adUnitId: adUnitId,
        eventName: event,
        payload: {
          'position_ms': events.indexOf(event) * 1000,
          'source': 'flutter_example',
        },
      );
      _log('emitted $event');
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  }

  Future<void> _stopTracking() async {
    final adUnitId = _adUnitCtrl.text.trim();
    await DkmadsSsp.stopVideoLifecycleTracking(adUnitId);
    _log('Stopped lifecycle tracking for $adUnitId');
  }

  Future<void> _trackCustomEvent() async {
    await DkmadsSsp.trackUserEvent('level_complete', attributes: {'level': 12, 'source': 'flutter_example'});
    _log('Tracked first-party event.');
  }

  Future<void> _loadBanner() async {
    final result = await DkmadsSsp.loadBanner(
      adUnitId: _adUnitCtrl.text.trim(),
      width: 300,
      height: 250,
    );
    if (result.success) {
      _log('banner fill reason=${result.reason} adId=${result.adId} dsp=${result.dsp}');
    } else {
      _log('banner no-fill reason=${result.reason ?? "unknown"} requestId=${result.requestId ?? "-"}');
    }
  }

  Future<void> _loadAndShowInterstitial() async {
    final adUnitId = _adUnitCtrl.text.trim();
    final result = await DkmadsSsp.loadInterstitial(
      adUnitId: adUnitId,
      width: 320,
      height: 480,
    );
    if (!result.hasFill) {
      _log('interstitial no-fill reason=${result.reason ?? "unknown"}');
      return;
    }
    _log('interstitial loaded isVideo=${result.isVideo} videoUrl=${result.videoUrl ?? "-"}');
    await DkmadsSsp.showInterstitial(adUnitId: adUnitId);
    _log('showInterstitial called');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DKMads SSP Flutter Example')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _integrationKeyCtrl, decoration: const InputDecoration(labelText: 'Integration key')),
            const SizedBox(height: 8),
            TextField(controller: _propertyIdCtrl, decoration: const InputDecoration(labelText: 'Property ID')),
            const SizedBox(height: 8),
            TextField(controller: _adUnitCtrl, decoration: const InputDecoration(labelText: 'Ad Unit ID')),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(onPressed: _initialize, child: const Text('Initialize')),
                ElevatedButton(onPressed: _loadBanner, child: const Text('Load banner')),
                ElevatedButton(onPressed: _loadAndShowInterstitial, child: const Text('Interstitial')),
                ElevatedButton(onPressed: _startVideoLifecycle, child: const Text('Start lifecycle')),
                ElevatedButton(onPressed: _emitSampleSequence, child: const Text('Emit sample events')),
                ElevatedButton(onPressed: _trackCustomEvent, child: const Text('Track custom event')),
                OutlinedButton(onPressed: _stopTracking, child: const Text('Stop lifecycle')),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                child: ListView.builder(
                  itemCount: _logs.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(_logs[index], style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
