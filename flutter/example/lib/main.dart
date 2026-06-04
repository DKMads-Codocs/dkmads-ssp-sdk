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
  final TextEditingController _integrationKeyCtrl = TextEditingController(text: 'YOUR_INTEGRATION_KEY');
  final TextEditingController _bannerUnitCtrl = TextEditingController(text: 'YOUR_BANNER_AD_UNIT_UUID');
  final TextEditingController _interstitialUnitCtrl = TextEditingController(text: 'YOUR_INTERSTITIAL_AD_UNIT_UUID');
  bool _initialized = false;

  void _log(String line) {
    setState(() => _logs.insert(0, '${DateTime.now().toIso8601String()}  $line'));
  }

  Future<void> _initialize() async {
    await DkmadsSsp.initialize(
      integrationKey: _integrationKeyCtrl.text.trim(),
      baseUrl: 'https://ssp.dkmads.com',
      debug: true,
    );
    setState(() => _initialized = true);
    _log('SDK initialized.');
  }

  Future<void> _loadAndShowInterstitial() async {
    final adUnitId = _interstitialUnitCtrl.text.trim();
    final result = await DkmadsSsp.loadInterstitial(adUnitId: adUnitId, width: 320, height: 480);
    if (!result.hasFill) {
      _log('interstitial no-fill: ${result.reason ?? "unknown"}');
      return;
    }
    _log('interstitial loaded dsp=${result.dsp}');
    await DkmadsSsp.showInterstitial(adUnitId: adUnitId);
    _log('showInterstitial called');
  }

  Future<void> _openInspector() async {
    await DkmadsSsp.presentAdInspector();
    _log('Ad Inspector opened');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DKMads Quickstart')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _integrationKeyCtrl,
            decoration: const InputDecoration(labelText: 'Integration key'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _bannerUnitCtrl,
            decoration: const InputDecoration(labelText: 'Banner ad unit UUID'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _interstitialUnitCtrl,
            decoration: const InputDecoration(labelText: 'Interstitial ad unit UUID'),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(onPressed: _initialize, child: const Text('1. Initialize')),
              FilledButton(
                onPressed: _initialized ? _loadAndShowInterstitial : null,
                child: const Text('3. Interstitial'),
              ),
              OutlinedButton(
                onPressed: _initialized ? _openInspector : null,
                child: const Text('Ad Inspector'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('2. Banner (native view)', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (_initialized)
            Center(
              child: DkmadsBannerAd(
                adUnitId: _bannerUnitCtrl.text.trim(),
                width: 300,
                height: 250,
              ),
            )
          else
            const Text('Initialize SDK to show banner.', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          const Text('Log', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ..._logs.take(12).map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(e, style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
            ),
          ),
        ],
      ),
    );
  }
}
