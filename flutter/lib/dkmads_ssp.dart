import 'package:flutter/services.dart';

typedef DkmadsVideoEventHandler = void Function(String eventName, Map<String, dynamic> payload);

/// Result from native `loadBanner` / `loadInterstitial` (aligned with iOS/Android `Ad`).
class DkmadsAdResult {
  const DkmadsAdResult({
    required this.success,
    this.reason,
    this.requestId,
    this.adId,
    this.adm,
    this.creativeUrl,
    this.clickUrl,
    this.videoUrl,
    this.html5EntryUrl,
    this.width = 0,
    this.height = 0,
    this.isVideo = false,
    this.isHtml5 = false,
    this.dsp,
    this.price,
    this.campaignId,
    this.creativeId,
  });

  final bool success;
  final String? reason;
  final String? requestId;
  final String? adId;
  final String? adm;
  final String? creativeUrl;
  final String? clickUrl;
  final String? videoUrl;
  final String? html5EntryUrl;
  final int width;
  final int height;
  final bool isVideo;
  final bool isHtml5;
  final String? dsp;
  final double? price;
  final String? campaignId;
  final String? creativeId;

  bool get hasFill => success;

  factory DkmadsAdResult.fromMap(Map<dynamic, dynamic>? raw) {
    final map = Map<String, dynamic>.from(raw ?? const {});
    return DkmadsAdResult(
      success: map['success'] == true,
      reason: map['reason'] as String?,
      requestId: map['requestId'] as String?,
      adId: map['adId'] as String?,
      adm: map['adm'] as String?,
      creativeUrl: map['creativeUrl'] as String?,
      clickUrl: map['clickUrl'] as String?,
      videoUrl: map['videoUrl'] as String?,
      html5EntryUrl: map['html5EntryUrl'] as String?,
      width: (map['width'] as num?)?.toInt() ?? 0,
      height: (map['height'] as num?)?.toInt() ?? 0,
      isVideo: map['isVideo'] == true,
      isHtml5: map['isHtml5'] == true,
      dsp: map['dsp'] as String?,
      price: (map['price'] as num?)?.toDouble(),
      campaignId: map['campaignId'] as String?,
      creativeId: map['creativeId'] as String?,
    );
  }
}

/// @deprecated Use [DkmadsAdResult].
typedef DkmadsBannerResult = DkmadsAdResult;

class DkmadsSsp {
  static const MethodChannel _channel = MethodChannel('dkmads_ssp');
  static final Map<String, DkmadsVideoEventHandler> _videoHandlers = {};
  static bool _channelHandlerBound = false;

  static void _bindChannelHandlerOnce() {
    if (_channelHandlerBound) return;
    _channelHandlerBound = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'videoEvent') return;
      final args = Map<String, dynamic>.from(call.arguments as Map? ?? const {});
      final adUnitId = args['adUnitId'] as String? ?? '';
      final eventName = args['eventName'] as String? ?? 'unknown';
      final payload = Map<String, dynamic>.from(args['payload'] as Map? ?? const {});
      final listener = _videoHandlers[adUnitId];
      listener?.call(eventName, payload);
    });
  }

  static Future<void> initialize({
    required String integrationKey,
    String? propertyId,
    String? propertyCode,
    String? baseUrl,
    bool debug = false,
  }) async {
    await _channel.invokeMethod('initialize', {
      'integrationKey': integrationKey,
      'propertyId': propertyId,
      'propertyCode': propertyCode,
      'baseUrl': baseUrl,
      'debug': debug,
    });
  }

  /// Register IAB sizes for an ad unit (used when load calls omit explicit dimensions).
  static Future<void> registerAdUnit({
    required String adUnitId,
    required String format,
    List<List<int>> sizes = const [],
  }) async {
    await _channel.invokeMethod('registerAdUnit', {
      'adUnitId': adUnitId,
      'format': format,
      'sizes': sizes.map((s) => {'width': s[0], 'height': s[1]}).toList(),
    });
  }

  static Future<void> setUserData(Map<String, dynamic> userData) async {
    await _channel.invokeMethod('setUserData', {'userData': userData});
  }

  /// Structured targeting aligned with native [TargetingSignals] (see docs/TARGETING_SIGNALS.md).
  static Future<void> setTargetingSignals(Map<String, dynamic> signals) async {
    await _channel.invokeMethod('setTargetingSignals', {'signals': signals});
  }

  static Future<void> syncFirstPartyProfile({String? appBundle}) async {
    await _channel.invokeMethod('syncFirstPartyProfile', {'appBundle': appBundle});
  }

  static Future<void> setConsent({
    bool gdpr = false,
    bool ccpa = false,
    String? consentString,
    String? gppString,
    String? gppSid,
  }) async {
    await _channel.invokeMethod('setConsent', {
      'gdpr': gdpr,
      'ccpa': ccpa,
      'consentString': consentString,
      'gppString': gppString,
      'gppSid': gppSid,
    });
  }

  static Future<void> clearIdentifiers() async {
    await _channel.invokeMethod('clearIdentifiers');
  }

  /// Loads a banner via native SDK (`/api/public/v1/bid`).
  static Future<DkmadsAdResult> loadBanner({
    required String adUnitId,
    int width = 300,
    int height = 250,
    String? placementCode,
    String? placementContext,
  }) async {
    final raw = await _channel.invokeMethod<dynamic>('loadBanner', {
      'adUnitId': adUnitId,
      'width': width,
      'height': height,
      'placementCode': placementCode,
      'placementContext': placementContext,
    });
    return DkmadsAdResult.fromMap(raw as Map<dynamic, dynamic>?);
  }

  /// Loads an interstitial via native `DKMadsInterstitialAd` (IAB sizes, not screen pixels).
  static Future<DkmadsAdResult> loadInterstitial({
    required String adUnitId,
    int width = 320,
    int height = 480,
    String? placementCode,
    String? placementContext,
  }) async {
    final raw = await _channel.invokeMethod<dynamic>('loadInterstitial', {
      'adUnitId': adUnitId,
      'width': width,
      'height': height,
      'placementCode': placementCode,
      'placementContext': placementContext,
    });
    return DkmadsAdResult.fromMap(raw as Map<dynamic, dynamic>?);
  }

  /// Presents a loaded interstitial using native fullscreen UI (call after [loadInterstitial] success).
  static Future<void> showInterstitial({required String adUnitId}) async {
    await _channel.invokeMethod('showInterstitial', {'adUnitId': adUnitId});
  }

  static Future<void> trackUserEvent(String name, {Map<String, dynamic> attributes = const {}}) async {
    await _channel.invokeMethod('trackUserEvent', {
      'name': name,
      'attributes': attributes,
    });
  }

  static Future<void> trackVideoLifecycle({
    required String adUnitId,
    bool? skippable,
    DkmadsVideoEventHandler? onEvent,
  }) async {
    _bindChannelHandlerOnce();
    if (onEvent != null) _videoHandlers[adUnitId] = onEvent;
    await _channel.invokeMethod('trackVideoLifecycle', {
      'adUnitId': adUnitId,
      'skippable': skippable,
    });
  }

  /// Bridge helper for Flutter video players to forward runtime events.
  static Future<void> emitVideoEvent({
    required String adUnitId,
    required String eventName,
    Map<String, dynamic> payload = const {},
  }) async {
    await _channel.invokeMethod('emitVideoEvent', {
      'adUnitId': adUnitId,
      'eventName': eventName,
      'payload': payload,
    });
  }

  static Future<void> stopVideoLifecycleTracking(String adUnitId) async {
    _videoHandlers.remove(adUnitId);
    await _channel.invokeMethod('stopVideoLifecycleTracking', {'adUnitId': adUnitId});
  }
}
