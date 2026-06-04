// DKMads SSP iOS — Telemetry Manager with built-in viewability, quartile, and fraud detection.
// POSTs event batches to /v1/events with X-Integration-Key.
// (property key) or fallback user-session bearer.

import Foundation
import UIKit
import AVFoundation

@objc public final class TelemetryManager: NSObject {

    @objc public static let shared = TelemetryManager()

    private let sdkVersion = SDK_VERSION
    private let maxBufferSize = 50
    private let flushIntervalSeconds: TimeInterval = 2.0

    private var config: SSPSDKConfig?
    private var consent: ConsentData = ConsentData()
    private var identityProvider: (() -> [String: String?])?
    private var eventBuffer: [[String: Any]] = []
    private var pendingEvents: [[String: Any]] = []
    private let queue = DispatchQueue(label: "com.dkmads.telemetry", qos: .utility)
    private var flushTimer: Timer?

    private var viewabilityObservers: [String: ViewabilityObserver] = [:]
    private var videoTrackers: [String: VideoTracker] = [:]
    private var audioTrackers: [String: AudioTracker] = [:]

    private override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(onResignActive),
                                               name: UIApplication.willResignActiveNotification, object: nil)
    }

    @objc public func configure(with config: SSPSDKConfig) {
        self.config = config
        flushPendingEvents()
        startFlushTimer()
    }

    public func setConsent(_ consent: ConsentData) {
        self.consent = consent
    }

    public func setIdentityProvider(_ provider: @escaping () -> [String: String?]) {
        identityProvider = provider
    }

    // MARK: - Event tracking

    @objc public func trackEvent(type: String, data: [String: Any] = [:]) {
        queue.async { [weak self] in
            guard let self = self else { return }
            var payload = data
            payload["type"] = type
            payload["timestamp"] = ISO8601DateFormatter().string(from: Date())
            payload["os"] = "ios"
            payload["device_type"] = UIDevice.current.userInterfaceIdiom == .pad ? "tablet" : "mobile"
            payload["sdk_version"] = self.sdkVersion
            payload["consent_string"] = self.consent.consentString
            payload["gpp_string"] = self.consent.gppString
            payload["gpp_sid"] = self.consent.gppSid
            payload["gdpr_applies"] = self.consent.gdpr
            if let usp = self.consent.resolvedUsPrivacyString() {
                payload["us_privacy_string"] = usp
            }
            if let att = self.consent.attStatus ?? AdvertisingIdentifiers.attStatus() {
                payload["att_status"] = att
            }
            if let ids = self.identityProvider?() {
                if let user = ids["user_pid"], !(user ?? "").isEmpty { payload["user_pid"] = user }
                if let device = ids["device_pid"], !(device ?? "").isEmpty { payload["device_pid"] = device }
                if let idfa = ids["idfa"], !(idfa ?? "").isEmpty { payload["idfa"] = idfa }
                if let gaid = ids["gaid"], !(gaid ?? "").isEmpty { payload["gaid"] = gaid }
            }
            if self.config != nil {
                self.eventBuffer.append(payload)
                if self.eventBuffer.count >= self.maxBufferSize { self.flushEvents(sync: false) }
            } else {
                self.pendingEvents.append(payload)
            }
        }
    }

    public func trackEvent(type: EventType, data: [String: Any] = [:]) {
        trackEvent(type: type.rawValue, data: data)
    }

    // MARK: - Built-in Viewability

    @objc public func trackViewability(adUnitId: String,
                                       container: UIView,
                                       threshold: CGFloat = 0.5,
                                       minExposureTime: TimeInterval = 1.0,
                                       extra: [String: Any] = [:],
                                       onViewable: (() -> Void)? = nil) {
        stopViewabilityTracking(adUnitId: adUnitId)

        // Fire fraud detection first (fires its own event if needed).
        _ = detectFraudSignals(adUnitId: adUnitId, view: container, extra: extra)

        let observer = ViewabilityObserver(
            adUnitId: adUnitId,
            container: container,
            threshold: threshold,
            minExposureTime: minExposureTime
        )
        observer.onViewable = { [weak self] data in
            var payload = extra
            payload["ad_unit_id"] = adUnitId
            payload["metadata"] = [
                "visible_percent": data["visible_percent"] ?? 0,
                "exposure_time_ms": data["exposure_time_ms"] ?? 0,
                "viewability_status": "viewable",
                "viewability_bucket": data["viewability_bucket"] ?? "",
                "threshold": "IAB_STANDARD"
            ]
            self?.trackEvent(type: "viewable_impression", data: payload)
            onViewable?()
        }
        viewabilityObservers[adUnitId] = observer
        observer.start()

        // Served impression (`ad_impression`) is emitted once when the ad is displayed — not here.
        var baseExtra = extra
        baseExtra["ad_unit_id"] = adUnitId
        trackEvent(type: "measurable_impression", data: baseExtra)
    }

    @objc public func stopViewabilityTracking(adUnitId: String) {
        viewabilityObservers[adUnitId]?.stop()
        viewabilityObservers.removeValue(forKey: adUnitId)
    }

    // MARK: - Built-in Video

    public func trackVideoAd(adUnitId: String,
                             campaignId: String?,
                             creativeId: String?,
                             player: AVPlayer,
                             containerView: UIView,
                             skippable: Bool? = nil,
                             eventListener: ((String, [String: Any]) -> Void)? = nil) {
        stopVideoTracking(adUnitId: adUnitId)
        let tracker = VideoTracker(
            adUnitId: adUnitId,
            campaignId: campaignId,
            creativeId: creativeId,
            player: player,
            containerView: containerView,
            skippable: skippable
        )
        tracker.onVideoStart = { [weak self] meta in
            self?.trackEvent(type: "video_start", data: meta)
            eventListener?("video_start", meta)
        }
        tracker.onQuartileReached = { [weak self] quartile, meta in
            self?.trackEvent(type: "video_\(quartile)", data: meta)
            eventListener?("video_\(quartile)", meta)
        }
        tracker.onVideoComplete = { [weak self] meta in
            self?.trackEvent(type: "video_100", data: meta)
            eventListener?("video_100", meta)
        }
        tracker.onVideoViewable = { [weak self] meta in
            self?.trackEvent(type: "video_viewable", data: meta)
            eventListener?("video_viewable", meta)
        }
        tracker.onVideoPaused = { [weak self] meta in
            self?.trackEvent(type: "video_pause", data: meta)
            eventListener?("video_pause", meta)
        }
        tracker.onVideoResumed = { [weak self] meta in
            self?.trackEvent(type: "video_resume", data: meta)
            eventListener?("video_resume", meta)
        }
        tracker.onVideoSkipped = { [weak self] meta in
            self?.trackEvent(type: "video_skip", data: meta)
            eventListener?("video_skip", meta)
        }
        tracker.onVideoMuted = { [weak self] meta in
            self?.trackEvent(type: "video_mute", data: meta)
            eventListener?("video_mute", meta)
        }
        tracker.onVideoUnmuted = { [weak self] meta in
            self?.trackEvent(type: "video_unmute", data: meta)
            eventListener?("video_unmute", meta)
        }
        tracker.onVideoPlaybackError = { [weak self] meta in
            self?.trackEvent(type: "video_error", data: meta)
            eventListener?("video_error", meta)
        }
        videoTrackers[adUnitId] = tracker
        tracker.start()
    }

    public func stopVideoTracking(adUnitId: String) {
        videoTrackers[adUnitId]?.stop()
        videoTrackers.removeValue(forKey: adUnitId)
    }

    public func markVideoUserSkipped(adUnitId: String) {
        videoTrackers[adUnitId]?.markUserSkipped()
    }

    // MARK: - Built-in Audio

    public func trackAudioAd(
        adUnitId: String,
        campaignId: String?,
        creativeId: String?,
        player: AVPlayer,
        eventListener: ((String, [String: Any]) -> Void)? = nil
    ) {
        stopAudioTracking(adUnitId: adUnitId)
        let tracker = AudioTracker(
            adUnitId: adUnitId,
            campaignId: campaignId,
            creativeId: creativeId,
            player: player
        )
        tracker.onAudioStart = { [weak self] meta in
            self?.trackEvent(type: "audio_start", data: meta)
            eventListener?("audio_start", meta)
        }
        tracker.onQuartileReached = { [weak self] q, meta in
            self?.trackEvent(type: "audio_\(q)", data: meta)
            eventListener?("audio_\(q)", meta)
        }
        tracker.onAudioComplete = { [weak self] meta in
            self?.trackEvent(type: "audio_100", data: meta)
            eventListener?("audio_100", meta)
        }
        audioTrackers[adUnitId] = tracker
        tracker.start()
    }

    public func stopAudioTracking(adUnitId: String) {
        audioTrackers[adUnitId]?.stop()
        audioTrackers.removeValue(forKey: adUnitId)
    }

    // MARK: - Built-in Fraud detection

    @discardableResult
    public func detectFraudSignals(adUnitId: String, view: UIView, extra: [String: Any] = [:]) -> [FraudSignal] {
        var signals: [FraudSignal] = []
        let frame = view.frame
        if frame.size.width < 50 || frame.size.height < 50 {
            signals.append(FraudSignal(type: "tiny_container", severity: .medium, confidence: 0.8,
                                       details: ["width": frame.width, "height": frame.height]))
        }
        if view.isHidden || view.alpha < 0.1 {
            signals.append(FraudSignal(type: "hidden_placement", severity: .high, confidence: 0.9))
        }
        if view.alpha == 0 {
            signals.append(FraudSignal(type: "zero_opacity", severity: .high, confidence: 0.95))
        }
        let screen = UIScreen.main.bounds
        let absolute = view.superview?.convert(view.frame, to: nil) ?? view.frame
        if absolute.origin.x < -1000 || absolute.origin.y < -1000 ||
           absolute.origin.x > screen.width + 1000 || absolute.origin.y > screen.height + 1000 {
            signals.append(FraudSignal(type: "offscreen_placement", severity: .high, confidence: 0.85))
        }
        if !signals.isEmpty {
            var payload = extra
            payload["ad_unit_id"] = adUnitId
            payload["metadata"] = [
                "signals": signals.map { $0.toDictionary() },
                "severity": signals.map { $0.severity.rawValue }.max() ?? "low"
            ]
            trackEvent(type: "fraud_detection", data: payload)
        }
        return signals
    }

    // MARK: - Flushing

    @objc public func flushEventsNow() {
        queue.async { [weak self] in self?.flushEvents(sync: false) }
    }

    @objc private func onResignActive() {
        queue.async { [weak self] in self?.flushEvents(sync: true) }
    }

    private func startFlushTimer() {
        DispatchQueue.main.async {
            self.flushTimer?.invalidate()
            self.flushTimer = Timer.scheduledTimer(withTimeInterval: self.flushIntervalSeconds, repeats: true) { [weak self] _ in
                self?.queue.async { self?.flushEvents(sync: false) }
            }
        }
    }

    private func flushEvents(sync: Bool) {
        guard let config = self.config else { return }
        guard !eventBuffer.isEmpty else { return }
        let batch = eventBuffer
        eventBuffer.removeAll()

        guard let url = URL(string: PublicAPIPaths.eventsURL(baseURL: config.baseURL)) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(config.integrationKey, forHTTPHeaderField: "X-Integration-Key")

        let body: [String: Any] = ["events": batch]
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.fragmentsAllowed])
        } catch {
            return
        }
        let task = URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
            if let http = response as? HTTPURLResponse {
                PlatformIdentity.saveFromHeader(http.value(forHTTPHeaderField: "X-DKMads-Platform-Uid"))
            }
            if error != nil || (response as? HTTPURLResponse).map({ $0.statusCode >= 400 }) == true {
                self?.queue.async { self?.eventBuffer.append(contentsOf: batch) }
            }
        }
        task.resume()
    }

    private func flushPendingEvents() {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.eventBuffer.append(contentsOf: self.pendingEvents)
            self.pendingEvents.removeAll()
            self.flushEvents(sync: false)
        }
    }
}

// MARK: - Viewability Observer (continuous exposure)

public final class ViewabilityObserver {
    public let adUnitId: String
    public weak var container: UIView?
    public let threshold: CGFloat
    public let minExposureTime: TimeInterval

    private var runStart: CFTimeInterval = 0
    private var accumExposure: TimeInterval = 0
    private var isViewable = false
    private var displayLink: CADisplayLink?

    public var onViewable: (([String: Any]) -> Void)?

    public init(adUnitId: String, container: UIView, threshold: CGFloat = 0.5, minExposureTime: TimeInterval = 1.0) {
        self.adUnitId = adUnitId
        self.container = container
        self.threshold = threshold
        self.minExposureTime = minExposureTime
    }

    public func start() {
        stop()
        displayLink = CADisplayLink(target: self, selector: #selector(tick))
        displayLink?.add(to: .main, forMode: .common)
    }

    public func stop() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func tick() {
        guard let container = container, let window = container.window else {
            runStart = 0
            return
        }
        // Compute the visible area ratio in screen coords.
        let frameInWindow = container.convert(container.bounds, to: window)
        let screen = UIScreen.main.bounds
        let visible = frameInWindow.intersection(screen)
        let visibleArea = max(0, visible.width) * max(0, visible.height)
        let totalArea = container.bounds.width * container.bounds.height
        let ratio = totalArea > 0 ? visibleArea / totalArea : 0

        let now = CACurrentMediaTime()
        if ratio >= threshold && !container.isHidden && container.alpha > 0.1 {
            if runStart == 0 { runStart = now }
            accumExposure += now - runStart
            runStart = now
            if !isViewable && accumExposure >= minExposureTime {
                isViewable = true
                let bucket = bucketFor(ratio: ratio)
                onViewable?([
                    "visible_percent": Double(ratio * 100),
                    "exposure_time_ms": Int(accumExposure * 1000),
                    "viewability_bucket": bucket
                ])
                stop()
            }
        } else {
            runStart = 0
        }
    }

    private func bucketFor(ratio: CGFloat) -> String {
        let p = ratio * 100
        if p < 25 { return "0_25" }
        if p < 50 { return "25_50" }
        if p < 75 { return "50_75" }
        return "75_100"
    }
}

// MARK: - Video Tracker (quartiles + viewability)

public final class VideoTracker {
    public let adUnitId: String
    public let campaignId: String?
    public let creativeId: String?
    public weak var container: UIView?
    public let player: AVPlayer
    public let skippable: Bool?

    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var quartileFired: Set<Int> = []
    private var started = false
    private var completed = false
    private var skipped = false
    private var totalViewTime: TimeInterval = 0
    private var lastPlayAt: TimeInterval?
    private var wasPlaying = false
    private var wasMuted = false
    private var lastPositionSeconds: Double = 0

    private var videoViewAccum: TimeInterval = 0
    private var videoRunStart: CFTimeInterval = 0
    private var videoViewableFired = false
    private var displayLink: CADisplayLink?

    public var onVideoStart: (([String: Any]) -> Void)?
    public var onQuartileReached: ((Int, [String: Any]) -> Void)?
    public var onVideoComplete: (([String: Any]) -> Void)?
    public var onVideoViewable: (([String: Any]) -> Void)?
    public var onVideoPaused: (([String: Any]) -> Void)?
    public var onVideoResumed: (([String: Any]) -> Void)?
    public var onVideoSkipped: (([String: Any]) -> Void)?
    public var onVideoMuted: (([String: Any]) -> Void)?
    public var onVideoUnmuted: (([String: Any]) -> Void)?
    public var onVideoPlaybackError: (([String: Any]) -> Void)?

    public init(adUnitId: String, campaignId: String?, creativeId: String?,
                player: AVPlayer, containerView: UIView, skippable: Bool?) {
        self.adUnitId = adUnitId
        self.campaignId = campaignId
        self.creativeId = creativeId
        self.container = containerView
        self.player = player
        self.skippable = skippable
    }

    public func start() {
        stop()
        let interval = CMTime(seconds: 0.25, preferredTimescale: 1000)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] t in
            self?.onTimeUpdate(time: t)
        }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: .main
        ) { [weak self] _ in
            self?.onEnded()
        }
        displayLink = CADisplayLink(target: self, selector: #selector(viewabilityTick))
        displayLink?.add(to: .main, forMode: .common)
    }

    public func stop() {
        if let obs = timeObserver { player.removeTimeObserver(obs); timeObserver = nil }
        if let obs = endObserver { NotificationCenter.default.removeObserver(obs); endObserver = nil }
        displayLink?.invalidate(); displayLink = nil
    }

    /// User tapped Skip — do not count completion or further quartiles.
    public func markUserSkipped() {
        skipped = true
        completed = true
        player.pause()
    }

    private func durationSeconds() -> Double {
        let d = player.currentItem?.duration.seconds ?? 0
        return d.isFinite ? d : 0
    }

    private func baseMeta() -> [String: Any] {
        var meta: [String: Any] = [
            "video_duration_ms": Int(durationSeconds() * 1000),
            "video_current_time_ms": Int((player.currentTime().seconds).isFinite ? player.currentTime().seconds * 1000 : 0),
            "autoplay": (player.rate > 0),
            "muted": player.isMuted
        ]
        if let skippable = skippable { meta["skippable"] = skippable }
        return [
            "ad_unit_id": adUnitId,
            "campaign_id": campaignId ?? NSNull(),
            "creative_id": creativeId ?? NSNull(),
            "metadata": meta
        ]
    }

    private func onTimeUpdate(time: CMTime) {
        let dur = durationSeconds()
        guard dur > 0 else {
            var meta = baseMeta()
            if var m = meta["metadata"] as? [String: Any] {
                m["error_message"] = "invalid_duration"
                meta["metadata"] = m
            }
            onVideoPlaybackError?(meta)
            return
        }
        let pct = min(1.0, max(0.0, time.seconds / dur))
        let currentPosition = max(0, time.seconds)
        if !started && player.rate > 0 && videoViewableFired {
            started = true
            lastPlayAt = CACurrentMediaTime()
            onVideoStart?(baseMeta())
        }
        if wasPlaying && player.rate <= 0 && !completed {
            onVideoPaused?(baseMeta())
        } else if !wasPlaying && player.rate > 0 && started && !completed {
            onVideoResumed?(baseMeta())
        }
        if wasMuted != player.isMuted && started && !completed {
            if player.isMuted {
                onVideoMuted?(baseMeta())
            } else {
                onVideoUnmuted?(baseMeta())
            }
        }
        if skippable == true && started && !completed && !skipped {
            let jumpedToEnd = (currentPosition - lastPositionSeconds) > 3.0 && pct >= 0.9
            if jumpedToEnd {
                skipped = true
                completed = true
                onVideoSkipped?(baseMeta())
            }
        }
        if player.rate > 0, let last = lastPlayAt {
            let now = CACurrentMediaTime()
            totalViewTime += now - last
            lastPlayAt = now
        } else {
            lastPlayAt = nil
        }
        if videoViewableFired && !skipped {
            for q in [25, 50, 75] where pct >= Double(q) / 100.0 && !quartileFired.contains(q) {
                quartileFired.insert(q)
                onQuartileReached?(q, baseMeta())
            }
            if pct >= 0.99 && !completed {
                completed = true
                onVideoComplete?(baseMeta())
            }
        }
        wasPlaying = player.rate > 0
        wasMuted = player.isMuted
        lastPositionSeconds = currentPosition
    }

    private func onEnded() {
        guard !completed, !skipped else { return }
        completed = true
        onVideoComplete?(baseMeta())
    }

    @objc private func viewabilityTick() {
        guard let container = container, let window = container.window else { videoRunStart = 0; return }
        let frameInWindow = container.convert(container.bounds, to: window)
        let screen = UIScreen.main.bounds
        let visible = frameInWindow.intersection(screen)
        let visibleArea = max(0, visible.width) * max(0, visible.height)
        let totalArea = container.bounds.width * container.bounds.height
        let ratio = totalArea > 0 ? visibleArea / totalArea : 0

        let now = CACurrentMediaTime()
        let playing = player.rate > 0 && !completed
        if playing && ratio >= 0.5 {
            if videoRunStart == 0 { videoRunStart = now }
            videoViewAccum += now - videoRunStart
            videoRunStart = now
            if !videoViewableFired && videoViewAccum >= 2.0 {
                videoViewableFired = true
                var meta = baseMeta()
                if var m = meta["metadata"] as? [String: Any] {
                    m["is_video"] = true
                    m["visible_percent"] = Double(ratio * 100)
                    m["exposure_time_ms"] = Int(videoViewAccum * 1000)
                    m["viewability_status"] = "video_viewable"
                    meta["metadata"] = m
                }
                onVideoViewable?(meta)
                if !started && playing {
                    started = true
                    onVideoStart?(baseMeta())
                }
            }
        } else {
            videoRunStart = 0
        }
    }
}

// MARK: - Audio quartile tracker

private final class AudioTracker {
    let adUnitId: String
    let campaignId: String?
    let creativeId: String?
    weak var player: AVPlayer?
    var onAudioStart: (([String: Any]) -> Void)?
    var onQuartileReached: ((Int, [String: Any]) -> Void)?
    var onAudioComplete: (([String: Any]) -> Void)?

    private var timer: Timer?
    private var started = false
    private var completed = false
    private var reached = Set<Int>()

    init(adUnitId: String, campaignId: String?, creativeId: String?, player: AVPlayer) {
        self.adUnitId = adUnitId
        self.campaignId = campaignId
        self.creativeId = creativeId
        self.player = player
    }

    func start() {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func baseMeta() -> [String: Any] {
        let item = player?.currentItem
        let dur = CMTimeGetSeconds(item?.duration ?? .zero)
        let pos = CMTimeGetSeconds(item?.currentTime() ?? .zero)
        return [
            "ad_unit_id": adUnitId,
            "campaign_id": campaignId as Any,
            "creative_id": creativeId as Any,
            "metadata": [
                "audio_duration_ms": Int(max(0, dur) * 1000),
                "audio_current_time_ms": Int(max(0, pos) * 1000),
            ],
        ]
    }

    private func tick() {
        guard let player else { return }
        let dur = CMTimeGetSeconds(player.currentItem?.duration ?? .zero)
        guard dur > 0 else { return }
        let pos = CMTimeGetSeconds(player.currentTime())
        let pct = pos / dur
        let playing = player.rate > 0
        if !started && playing {
            started = true
            onAudioStart?(baseMeta())
        }
        for q in [25, 50, 75] where !reached.contains(q) && pct >= Double(q) / 100.0 {
            reached.insert(q)
            onQuartileReached?(q, baseMeta())
        }
        if !completed && pct >= 0.99 {
            completed = true
            onAudioComplete?(baseMeta())
        }
    }
}

// MARK: - Fraud Signal

public struct FraudSignal {
    public enum Severity: String { case low, medium, high, critical }
    public let type: String
    public let severity: Severity
    public let confidence: Double
    public let details: [String: Any]

    public init(type: String, severity: Severity, confidence: Double, details: [String: Any] = [:]) {
        self.type = type
        self.severity = severity
        self.confidence = confidence
        self.details = details
    }

    public func toDictionary() -> [String: Any] {
        return [
            "type": type,
            "severity": severity.rawValue,
            "confidence": confidence,
            "details": details
        ]
    }
}

// MARK: - Event type enum (kept for source compatibility)

@objc public enum EventType: Int, RawRepresentable {
    case sdk_init
    case impression
    case viewable_impression
    case measurable_impression
    case click
    case conversion
    case video_start
    case video_25
    case video_50
    case video_75
    case video_100
    case video_viewable
    case video_volume_change
    case engagement_dwell
    case fraud_detection

    public typealias RawValue = String
    public init?(rawValue: String) {
        switch rawValue {
        case "sdk_init": self = .sdk_init
        case "impression": self = .impression
        case "viewable_impression": self = .viewable_impression
        case "measurable_impression": self = .measurable_impression
        case "click": self = .click
        case "conversion": self = .conversion
        case "video_start": self = .video_start
        case "video_25": self = .video_25
        case "video_50": self = .video_50
        case "video_75": self = .video_75
        case "video_100": self = .video_100
        case "video_viewable": self = .video_viewable
        case "video_volume_change": self = .video_volume_change
        case "engagement_dwell": self = .engagement_dwell
        case "fraud_detection": self = .fraud_detection
        default: return nil
        }
    }

    public var rawValue: String {
        switch self {
        case .sdk_init: return "sdk_init"
        case .impression: return "impression"
        case .viewable_impression: return "viewable_impression"
        case .measurable_impression: return "measurable_impression"
        case .click: return "click"
        case .conversion: return "conversion"
        case .video_start: return "video_start"
        case .video_25: return "video_25"
        case .video_50: return "video_50"
        case .video_75: return "video_75"
        case .video_100: return "video_100"
        case .video_viewable: return "video_viewable"
        case .video_volume_change: return "video_volume_change"
        case .engagement_dwell: return "engagement_dwell"
        case .fraud_detection: return "fraud_detection"
        }
    }
}
