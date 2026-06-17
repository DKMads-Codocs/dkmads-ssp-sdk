using System;
using UnityEngine;
using System.Runtime.InteropServices;

namespace DKMads.SSP
{
    /// <summary>JSON result from native load APIs (banner / interstitial).</summary>
    [Serializable]
    public class DKMadsAdLoadResult
    {
        public bool success;
        public string reason;
        public string requestId;
        public string adId;
        public string adm;
        public string creativeUrl;
        public string clickUrl;
        public string videoUrl;
        public string html5EntryUrl;
        public int width;
        public int height;
        public bool isVideo;
        public bool isHtml5;

        /// <summary>Server render hint: image | html5 | video_native | video_web | native_assets | audio.
        /// Primary render fork; falls back to isVideo / isHtml5 heuristics when empty.</summary>
        public string renderMode;
        public string dsp;
        public double price;
        public string campaignId;
        public string creativeId;
        public string videoTemplate;
        public string ctaLabel;
        public string ctaPosition;
        public string companionImageUrl;
        public bool showCompanionClick;
        public bool skippable;
        public double skipAfterSec;
        public string unitFormat;
        public string placementContext;
    }

    public static class DKMadsSdk
    {
        #if UNITY_IOS && !UNITY_EDITOR
        [DllImport("__Internal")] private static extern void dkmads_initialize(string integrationKey, string propertyId, string propertyCode);
        [DllImport("__Internal")] private static extern void dkmads_set_consent(string jsonPayload);
        [DllImport("__Internal")] private static extern void dkmads_set_user_data(string jsonPayload);
        [DllImport("__Internal")] private static extern void dkmads_set_targeting_signals(string jsonPayload);
        [DllImport("__Internal")] private static extern void dkmads_track_user_event(string name, string jsonPayload);
        [DllImport("__Internal")] private static extern void dkmads_emit_video_event(string adUnitId, string eventName, string jsonPayload);
        [DllImport("__Internal")] private static extern IntPtr dkmads_load_ad(string adUnitId, string format, int width, int height);
        [DllImport("__Internal")] private static extern IntPtr dkmads_load_interstitial(string adUnitId, int width, int height);
        [DllImport("__Internal")] private static extern void dkmads_show_interstitial(string adUnitId);
        [DllImport("__Internal")] private static extern IntPtr dkmads_load_app_open(string adUnitId);
        [DllImport("__Internal")] private static extern void dkmads_show_app_open(string adUnitId);
        [DllImport("__Internal")] private static extern void dkmads_present_ad_inspector();
        [DllImport("__Internal")] private static extern IntPtr dkmads_load_rewarded(string adUnitId, int width, int height);
        [DllImport("__Internal")] private static extern IntPtr dkmads_show_rewarded(string adUnitId);
        [DllImport("__Internal")] private static extern void dkmads_free_string(IntPtr ptr);
        [DllImport("__Internal")] private static extern void dkmads_emit_video_event(string adUnitId, string eventName, string jsonPayload);
        [DllImport("__Internal")] private static extern void dkmads_sync_first_party_profile(string appBundle);
        #endif

        public static void Initialize(string integrationKey, string propertyId = null, string propertyCode = null)
        {
            #if UNITY_ANDROID && !UNITY_EDITOR
            using (var sdk = new AndroidJavaClass("com.dkmads.ssp.SSPSDK"))
            using (var config = new AndroidJavaObject(
                "com.dkmads.ssp.Config",
                integrationKey,
                propertyId,
                propertyCode,
                false,
                "https://ssp.dkmads.com"
            ))
            using (var unityPlayer = new AndroidJavaClass("com.unity3d.player.UnityPlayer"))
            {
                var context = unityPlayer.GetStatic<AndroidJavaObject>("currentActivity");
                sdk.CallStatic("initialize", context, config);
            }
            #elif UNITY_IOS && !UNITY_EDITOR
            dkmads_initialize(integrationKey, propertyId, propertyCode);
            #else
            Debug.Log($"[DKMadsSdk] Initialize integrationKey={integrationKey} propertyId={propertyId} propertyCode={propertyCode}");
            #endif
        }

        public static void SetTargetingSignals(DKMadsTargetingSignals signals)
        {
            if (signals == null)
            {
                Debug.LogWarning("[DKMadsSdk] SetTargetingSignals called with null");
                return;
            }
            SetTargetingSignalsJson(signals.ToJson());
        }

        public static void SetTargetingSignalsJson(string jsonPayload = "{}")
        {
            #if UNITY_ANDROID && !UNITY_EDITOR
            using (var bridge = new AndroidJavaClass("com.dkmads.ssp.unity.DKMadsUnityBridge"))
            {
                bridge.CallStatic("setTargetingSignals", jsonPayload ?? "{}");
            }
            #elif UNITY_IOS && !UNITY_EDITOR
            dkmads_set_targeting_signals(jsonPayload ?? "{}");
            #else
            Debug.Log($"[DKMadsSdk] SetTargetingSignals {jsonPayload}");
            #endif
        }

        public static void SetConsent(DKMadsConsent consent)
        {
            if (consent == null)
            {
                Debug.LogWarning("[DKMadsSdk] SetConsent called with null");
                return;
            }
            SetConsentJson(consent.ToJson());
        }

        public static void SetConsentJson(string jsonPayload = "{}")
        {
            #if UNITY_ANDROID && !UNITY_EDITOR
            using (var bridge = new AndroidJavaClass("com.dkmads.ssp.unity.DKMadsUnityBridge"))
            {
                bridge.CallStatic("setConsent", jsonPayload ?? "{}");
            }
            #elif UNITY_IOS && !UNITY_EDITOR
            dkmads_set_consent(jsonPayload ?? "{}");
            #else
            Debug.Log($"[DKMadsSdk] SetConsent {jsonPayload}");
            #endif
        }

        public static void SetUserData(string jsonPayload = "{}")
        {
            #if UNITY_ANDROID && !UNITY_EDITOR
            using (var bridge = new AndroidJavaClass("com.dkmads.ssp.unity.DKMadsUnityBridge"))
            {
                bridge.CallStatic("setUserData", jsonPayload);
            }
            #elif UNITY_IOS && !UNITY_EDITOR
            dkmads_set_user_data(jsonPayload ?? "{}");
            #else
            Debug.Log($"[DKMadsSdk] SetUserData {jsonPayload}");
            #endif
        }

        public static void TrackVideoLifecycle(string adUnitId, bool? skippable = null, Action<string, string> onEvent = null)
        {
            var payload = "{\"ad_unit_id\":\"" + adUnitId + "\",\"skippable\":" + (skippable == true ? "true" : "false") + "}";
            #if UNITY_ANDROID && !UNITY_EDITOR
            using (var bridge = new AndroidJavaClass("com.dkmads.ssp.unity.DKMadsUnityBridge"))
            {
                bridge.CallStatic("emitVideoEvent", adUnitId, "video_start", payload);
            }
            #elif UNITY_IOS && !UNITY_EDITOR
            dkmads_emit_video_event(adUnitId, "video_start", payload);
            #else
            Debug.Log($"[DKMadsSdk] TrackVideoLifecycle adUnitId={adUnitId}");
            #endif
            onEvent?.Invoke("video_start", payload);
        }

        public static void SyncFirstPartyProfile(string appBundle = null)
        {
            #if UNITY_ANDROID && !UNITY_EDITOR
            using (var bridge = new AndroidJavaClass("com.dkmads.ssp.unity.DKMadsUnityBridge"))
            using (var unityPlayer = new AndroidJavaClass("com.unity3d.player.UnityPlayer"))
            {
                var activity = unityPlayer.GetStatic<AndroidJavaObject>("currentActivity");
                bridge.CallStatic("syncFirstPartyProfile", activity, appBundle);
            }
            #elif UNITY_IOS && !UNITY_EDITOR
            dkmads_sync_first_party_profile(appBundle);
            #else
            Debug.Log("[DKMadsSdk] SyncFirstPartyProfile");
            #endif
        }

        public static void StopVideoLifecycleTracking(string adUnitId)
        {
            Debug.Log($"[DKMadsSdk] StopVideoLifecycleTracking adUnitId={adUnitId}");
        }

        public static void TrackUserEvent(string name, string jsonPayload = "{}")
        {
            #if UNITY_ANDROID && !UNITY_EDITOR
            using (var bridge = new AndroidJavaClass("com.dkmads.ssp.unity.DKMadsUnityBridge"))
            {
                bridge.CallStatic("trackUserEvent", name, jsonPayload);
            }
            #elif UNITY_IOS && !UNITY_EDITOR
            dkmads_track_user_event(name, jsonPayload);
            #else
            Debug.Log($"[DKMadsSdk] TrackUserEvent {name} payload={jsonPayload}");
            #endif
        }

        /// <summary>Loads a banner via native SDK. Returns JSON (parse with JsonUtility or your JSON lib).</summary>
        public static string LoadAd(string adUnitId, int width = 300, int height = 250) =>
            LoadAdWithFormat(adUnitId, "banner", width, height);

        public static string LoadNative(string adUnitId, int width = 320, int height = 50) =>
            LoadAdWithFormat(adUnitId, "native", width, height);

        /// <summary>Loads with format: banner, interstitial, video, native, rewarded, audio.</summary>
        public static string LoadAdWithFormat(string adUnitId, string format, int width = 300, int height = 250)
        {
            #if UNITY_ANDROID && !UNITY_EDITOR
            using (var bridge = new AndroidJavaClass("com.dkmads.ssp.unity.DKMadsUnityBridge"))
            using (var unityPlayer = new AndroidJavaClass("com.unity3d.player.UnityPlayer"))
            {
                var activity = unityPlayer.GetStatic<AndroidJavaObject>("currentActivity");
                return bridge.CallStatic<string>("loadAdWithFormat", activity, adUnitId, format, width, height);
            }
            #elif UNITY_IOS && !UNITY_EDITOR
            var ptr = dkmads_load_ad(adUnitId, format, width, height);
            return PtrToStringAndFree(ptr);
            #else
            Debug.Log($"[DKMadsSdk] LoadAdWithFormat adUnitId={adUnitId} format={format} size={width}x{height}");
            return "{\"success\":false,\"reason\":\"unsupported_platform\"}";
            #endif
        }

        /// <summary>Loads interstitial (IAB sizes). Call <see cref="ShowInterstitial"/> to present native fullscreen UI.</summary>
        public static string LoadInterstitial(string adUnitId, int width = 320, int height = 480)
        {
            #if UNITY_ANDROID && !UNITY_EDITOR
            using (var bridge = new AndroidJavaClass("com.dkmads.ssp.unity.DKMadsUnityBridge"))
            using (var unityPlayer = new AndroidJavaClass("com.unity3d.player.UnityPlayer"))
            {
                var activity = unityPlayer.GetStatic<AndroidJavaObject>("currentActivity");
                return bridge.CallStatic<string>("loadInterstitial", activity, adUnitId, width, height);
            }
            #elif UNITY_IOS && !UNITY_EDITOR
            var ptr = dkmads_load_interstitial(adUnitId, width, height);
            return PtrToStringAndFree(ptr);
            #else
            Debug.Log($"[DKMadsSdk] LoadInterstitial adUnitId={adUnitId} size={width}x{height}");
            return "{\"success\":false,\"reason\":\"unsupported_platform\"}";
            #endif
        }

        /// <summary>Presents native fullscreen interstitial (after successful <see cref="LoadInterstitial"/>).</summary>
        public static void ShowInterstitial(string adUnitId)
        {
            #if UNITY_ANDROID && !UNITY_EDITOR
            using (var bridge = new AndroidJavaClass("com.dkmads.ssp.unity.DKMadsUnityBridge"))
            using (var unityPlayer = new AndroidJavaClass("com.unity3d.player.UnityPlayer"))
            {
                var activity = unityPlayer.GetStatic<AndroidJavaObject>("currentActivity");
                bridge.CallStatic("showInterstitial", activity, adUnitId);
            }
            #elif UNITY_IOS && !UNITY_EDITOR
            dkmads_show_interstitial(adUnitId);
            #else
            Debug.Log($"[DKMadsSdk] ShowInterstitial adUnitId={adUnitId}");
            #endif
        }

        /// <summary>Loads app open / splash (dashboard format splash).</summary>
        public static string LoadAppOpen(string adUnitId)
        {
            #if UNITY_ANDROID && !UNITY_EDITOR
            using (var bridge = new AndroidJavaClass("com.dkmads.ssp.unity.DKMadsUnityBridge"))
            using (var unityPlayer = new AndroidJavaClass("com.unity3d.player.UnityPlayer"))
            {
                var activity = unityPlayer.GetStatic<AndroidJavaObject>("currentActivity");
                return bridge.CallStatic<string>("loadAppOpen", activity, adUnitId);
            }
            #elif UNITY_IOS && !UNITY_EDITOR
            var ptr = dkmads_load_app_open(adUnitId);
            return PtrToStringAndFree(ptr);
            #else
            return "{\"success\":false,\"reason\":\"unsupported_platform\"}";
            #endif
        }

        public static void ShowAppOpen(string adUnitId)
        {
            #if UNITY_ANDROID && !UNITY_EDITOR
            using (var bridge = new AndroidJavaClass("com.dkmads.ssp.unity.DKMadsUnityBridge"))
            using (var unityPlayer = new AndroidJavaClass("com.unity3d.player.UnityPlayer"))
            {
                var activity = unityPlayer.GetStatic<AndroidJavaObject>("currentActivity");
                bridge.CallStatic("showAppOpen", activity, adUnitId);
            }
            #elif UNITY_IOS && !UNITY_EDITOR
            dkmads_show_app_open(adUnitId);
            #else
            Debug.Log($"[DKMadsSdk] ShowAppOpen adUnitId={adUnitId}");
            #endif
        }

        public static void PresentAdInspector()
        {
            #if UNITY_ANDROID && !UNITY_EDITOR
            using (var bridge = new AndroidJavaClass("com.dkmads.ssp.unity.DKMadsUnityBridge"))
            using (var unityPlayer = new AndroidJavaClass("com.unity3d.player.UnityPlayer"))
            {
                var activity = unityPlayer.GetStatic<AndroidJavaObject>("currentActivity");
                bridge.CallStatic("presentAdInspector", activity);
            }
            #elif UNITY_IOS && !UNITY_EDITOR
            dkmads_present_ad_inspector();
            #else
            Debug.Log("[DKMadsSdk] PresentAdInspector");
            #endif
        }

        public static string LoadRewarded(string adUnitId, int width = 320, int height = 480)
        {
            #if UNITY_ANDROID && !UNITY_EDITOR
            using (var bridge = new AndroidJavaClass("com.dkmads.ssp.unity.DKMadsUnityBridge"))
            using (var unityPlayer = new AndroidJavaClass("com.unity3d.player.UnityPlayer"))
            {
                var activity = unityPlayer.GetStatic<AndroidJavaObject>("currentActivity");
                return bridge.CallStatic<string>("loadRewarded", activity, adUnitId, width, height);
            }
            #elif UNITY_IOS && !UNITY_EDITOR
            var ptr = dkmads_load_rewarded(adUnitId, width, height);
            return PtrToStringAndFree(ptr);
            #else
            return "{\"success\":false,\"reason\":\"unsupported_platform\"}";
            #endif
        }

        public static string ShowRewarded(string adUnitId)
        {
            #if UNITY_ANDROID && !UNITY_EDITOR
            using (var bridge = new AndroidJavaClass("com.dkmads.ssp.unity.DKMadsUnityBridge"))
            using (var unityPlayer = new AndroidJavaClass("com.unity3d.player.UnityPlayer"))
            {
                var activity = unityPlayer.GetStatic<AndroidJavaObject>("currentActivity");
                return bridge.CallStatic<string>("showRewarded", activity, adUnitId);
            }
            #elif UNITY_IOS && !UNITY_EDITOR
            var ptr = dkmads_show_rewarded(adUnitId);
            return PtrToStringAndFree(ptr);
            #else
            return "{\"success\":false,\"reason\":\"unsupported_platform\"}";
            #endif
        }

        public static void EmitVideoEvent(string adUnitId, string eventName, string jsonPayload = "{}")
        {
            #if UNITY_ANDROID && !UNITY_EDITOR
            using (var bridge = new AndroidJavaClass("com.dkmads.ssp.unity.DKMadsUnityBridge"))
            {
                bridge.CallStatic("emitVideoEvent", adUnitId, eventName, jsonPayload);
            }
            #elif UNITY_IOS && !UNITY_EDITOR
            dkmads_emit_video_event(adUnitId, eventName, jsonPayload);
            #else
            Debug.Log($"[DKMadsSdk] EmitVideoEvent adUnitId={adUnitId} event={eventName} payload={jsonPayload}");
            #endif
        }

        #if UNITY_IOS && !UNITY_EDITOR
        private static string PtrToStringAndFree(IntPtr ptr)
        {
            if (ptr == IntPtr.Zero) return "{}";
            var s = Marshal.PtrToStringAnsi(ptr) ?? "{}";
            dkmads_free_string(ptr);
            return s;
        }
        #endif
    }
}
