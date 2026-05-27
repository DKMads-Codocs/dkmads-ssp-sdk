import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

typedef DkmadsVideoEventHandler = void Function(String eventName, Map<String, dynamic> payload);
typedef DkmadsRewardedEventHandler = void Function(String eventName, Map<String, dynamic> payload);
typedef DkmadsInstreamEventHandler = void Function(String event, Map<String, dynamic> payload);

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
    this.videoTemplate,
    this.ctaLabel,
    this.ctaPosition,
    this.companionImageUrl,
    this.showCompanionClick,
    this.skippable,
    this.skipAfterSec,
    this.unitFormat,
    this.placementContext,
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
  final String? videoTemplate;
  final String? ctaLabel;
  final String? ctaPosition;
  final String? companionImageUrl;
  final bool? showCompanionClick;
  final bool? skippable;
  final double? skipAfterSec;
  final String? unitFormat;
  final String? placementContext;

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
      videoTemplate: map['videoTemplate'] as String?,
      ctaLabel: map['ctaLabel'] as String?,
      ctaPosition: map['ctaPosition'] as String?,
      companionImageUrl: map['companionImageUrl'] as String?,
      showCompanionClick: map['showCompanionClick'] as bool?,
      skippable: map['skippable'] as bool?,
      skipAfterSec: (map['skipAfterSec'] as num?)?.toDouble(),
      unitFormat: map['unitFormat'] as String?,
      placementContext: map['placementContext'] as String?,
    );
  }
}

/// @deprecated Use [DkmadsAdResult].
typedef DkmadsBannerResult = DkmadsAdResult;

class DkmadsSsp {
  static const MethodChannel _channel = MethodChannel('dkmads_ssp');
  static final Map<String, DkmadsVideoEventHandler> _videoHandlers = {};
  static final Map<String, DkmadsRewardedEventHandler> _rewardedHandlers = {};
  static final Map<int, DkmadsInstreamEventHandler> _instreamHandlers = {};
  static bool _channelHandlerBound = false;

  static void _bindChannelHandlerOnce() {
    if (_channelHandlerBound) return;
    _channelHandlerBound = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'videoEvent') {
        final args = Map<String, dynamic>.from(call.arguments as Map? ?? const {});
        final adUnitId = args['adUnitId'] as String? ?? '';
        final eventName = args['eventName'] as String? ?? 'unknown';
        final payload = Map<String, dynamic>.from(args['payload'] as Map? ?? const {});
        final listener = _videoHandlers[adUnitId];
        listener?.call(eventName, payload);
        return;
      }
      if (call.method == 'rewardedEvent') {
        final args = Map<String, dynamic>.from(call.arguments as Map? ?? const {});
        final adUnitId = args['adUnitId'] as String? ?? '';
        final eventName = args['event'] as String? ?? 'unknown';
        final listener = _rewardedHandlers[adUnitId];
        listener?.call(eventName, args);
      }
      if (call.method == 'instreamEvent') {
        final args = Map<String, dynamic>.from(call.arguments as Map? ?? const {});
        final viewId = (args['viewId'] as num?)?.toInt();
        final event = args['event'] as String? ?? 'unknown';
        if (viewId != null) {
          final listener = _instreamHandlers[viewId];
          listener?.call(event, args);
        }
      }
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
    String? usPrivacyString,
    int? attStatus,
  }) async {
    await _channel.invokeMethod('setConsent', {
      'gdpr': gdpr,
      'ccpa': ccpa,
      'consentString': consentString,
      'gppString': gppString,
      'gppSid': gppSid,
      'usPrivacyString': usPrivacyString,
      'attStatus': attStatus,
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

  static Future<DkmadsAdResult> loadRewarded({
    required String adUnitId,
    int width = 320,
    int height = 480,
    String? placementCode,
    String? placementContext,
  }) async {
    final raw = await _channel.invokeMethod<dynamic>('loadRewarded', {
      'adUnitId': adUnitId,
      'width': width,
      'height': height,
      'placementCode': placementCode,
      'placementContext': placementContext,
    });
    return DkmadsAdResult.fromMap(raw as Map<dynamic, dynamic>?);
  }

  static Future<void> showRewarded({
    required String adUnitId,
    DkmadsRewardedEventHandler? onEvent,
  }) async {
    _bindChannelHandlerOnce();
    if (onEvent != null) _rewardedHandlers[adUnitId] = onEvent;
    await _channel.invokeMethod('showRewarded', {'adUnitId': adUnitId});
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

  static void registerInstreamHandler(int viewId, DkmadsInstreamEventHandler? handler) {
    _bindChannelHandlerOnce();
    if (handler == null) {
      _instreamHandlers.remove(viewId);
    } else {
      _instreamHandlers[viewId] = handler;
    }
  }

  static Future<void> requestInstreamAds({
    required int viewId,
    required String adUnitId,
    int width = 640,
    int height = 360,
    String? placementContext,
  }) async {
    await _channel.invokeMethod('requestInstreamAds', {
      'viewId': viewId,
      'adUnitId': adUnitId,
      'width': width,
      'height': height,
      'placementContext': placementContext,
    });
  }

  static Future<void> destroyInstream(int viewId) async {
    _instreamHandlers.remove(viewId);
    await _channel.invokeMethod('destroyInstream', {'viewId': viewId});
  }
}

/// Native instream ad overlay (Android/iOS [DKMadsInstreamAdsLoader]).
class DkmadsInstreamAd extends StatefulWidget {
  const DkmadsInstreamAd({
    super.key,
    required this.adUnitId,
    this.width = 640,
    this.height = 360,
    this.placementContext,
    this.autoRequest = false,
    this.onPauseContent,
    this.onResumeContent,
    this.onAdStarted,
    this.onAdFinished,
    this.onAdFailed,
  });

  final String adUnitId;
  final int width;
  final int height;
  final String? placementContext;
  final bool autoRequest;
  final VoidCallback? onPauseContent;
  final VoidCallback? onResumeContent;
  final VoidCallback? onAdStarted;
  final VoidCallback? onAdFinished;
  final void Function(String message)? onAdFailed;

  @override
  State<DkmadsInstreamAd> createState() => _DkmadsInstreamAdState();
}

class _DkmadsInstreamAdState extends State<DkmadsInstreamAd> {
  int? _viewId;

  void _onPlatformViewCreated(int id) {
    _viewId = id;
    DkmadsSsp.registerInstreamHandler(id, (event, payload) {
      switch (event) {
        case 'pause_content':
          widget.onPauseContent?.call();
          break;
        case 'resume_content':
          widget.onResumeContent?.call();
          break;
        case 'ad_started':
          widget.onAdStarted?.call();
          break;
        case 'ad_finished':
          widget.onAdFinished?.call();
          break;
        case 'ad_failed':
          widget.onAdFailed?.call(payload['message'] as String? ?? 'failed');
          break;
      }
    });
    if (widget.autoRequest) {
      DkmadsSsp.requestInstreamAds(
        viewId: id,
        adUnitId: widget.adUnitId,
        width: widget.width,
        height: widget.height,
        placementContext: widget.placementContext,
      );
    }
  }

  Future<void> requestAds() async {
    final id = _viewId;
    if (id == null) return;
    await DkmadsSsp.requestInstreamAds(
      viewId: id,
      adUnitId: widget.adUnitId,
      width: widget.width,
      height: widget.height,
      placementContext: widget.placementContext,
    );
  }

  @override
  void dispose() {
    final id = _viewId;
    if (id != null) {
      DkmadsSsp.destroyInstream(id);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const params = <String, dynamic>{};
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      if (Platform.isAndroid) {
        return AndroidView(
          viewType: 'dkmads_instream',
          creationParams: params,
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: _onPlatformViewCreated,
        );
      }
      return UiKitView(
        viewType: 'dkmads_instream',
        creationParams: params,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _onPlatformViewCreated,
      );
    }
    return const SizedBox.shrink();
  }
}
