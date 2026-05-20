using UnityEngine;
using DKMads.SSP;

namespace DKMads.SSP.Samples
{
    public class VideoLifecycleSample : MonoBehaviour
    {
        [SerializeField] private string integrationKey = "int_xxx";
        [SerializeField] private string propertyId = "property_uuid";
        [SerializeField] private string adUnitId = "ad_unit_uuid";
        [SerializeField] private bool skippable = true;

        private void Start()
        {
            DKMadsSdk.Initialize(integrationKey, propertyId);
            DKMadsSdk.TrackVideoLifecycle(adUnitId, skippable, (eventName, payload) =>
            {
                Debug.Log($"[DKMadsUnitySample] callback event={eventName} payload={payload}");
            });
            Debug.Log("[DKMadsUnitySample] Initialized and tracking lifecycle.");
        }

        [ContextMenu("EmitSampleVideoSequence")]
        public void EmitSampleVideoSequence()
        {
            DKMadsSdk.EmitVideoEvent(adUnitId, "video_start", "{\"position_ms\":0,\"source\":\"unity_sample\"}");
            DKMadsSdk.EmitVideoEvent(adUnitId, "video_25", "{\"position_ms\":2500}");
            DKMadsSdk.EmitVideoEvent(adUnitId, "video_50", "{\"position_ms\":5000}");
            DKMadsSdk.EmitVideoEvent(adUnitId, "video_pause", "{\"position_ms\":6500}");
            DKMadsSdk.EmitVideoEvent(adUnitId, "video_resume", "{\"position_ms\":6500}");
            DKMadsSdk.EmitVideoEvent(adUnitId, "video_75", "{\"position_ms\":7500}");
            DKMadsSdk.EmitVideoEvent(adUnitId, "video_100", "{\"position_ms\":10000}");
            Debug.Log("[DKMadsUnitySample] Emitted sample video event sequence.");
        }

        [ContextMenu("TrackCustomEvent")]
        public void TrackCustomEvent()
        {
            DKMadsSdk.TrackUserEvent("level_complete", "{\"level\":12,\"source\":\"unity_sample\"}");
        }

        private void OnDestroy()
        {
            DKMadsSdk.StopVideoLifecycleTracking(adUnitId);
        }
    }
}
