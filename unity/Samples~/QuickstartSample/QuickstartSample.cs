using UnityEngine;
using DKMads.SSP;

/// <summary>
/// Mirrors docs/integration/QUICKSTART.md — attach to an active GameObject.
/// Set integration key and ad unit UUIDs in the Inspector.
/// </summary>
public class QuickstartSample : MonoBehaviour
{
    [SerializeField] private string integrationKey = "YOUR_INTEGRATION_KEY";
    [SerializeField] private string interstitialAdUnitId = "YOUR_INTERSTITIAL_AD_UNIT_UUID";
    [SerializeField] private string splashAdUnitId = "YOUR_SPLASH_AD_UNIT_UUID";

    private void Start()
    {
        DKMadsSdk.Initialize(integrationKey);
        Debug.Log("[DKMads] SDK initialized. Use UI buttons or context menu.");
    }

    [ContextMenu("Load and show interstitial")]
    public void LoadAndShowInterstitial()
    {
        var json = DKMadsSdk.LoadInterstitial(interstitialAdUnitId);
        Debug.Log($"[DKMads] LoadInterstitial: {json}");
        if (json.Contains("\"success\":true"))
            DKMadsSdk.ShowInterstitial(interstitialAdUnitId);
    }

    [ContextMenu("Load and show app open")]
    public void LoadAndShowAppOpen()
    {
        var json = DKMadsSdk.LoadAppOpen(splashAdUnitId);
        Debug.Log($"[DKMads] LoadAppOpen: {json}");
        if (json.Contains("\"success\":true"))
            DKMadsSdk.ShowAppOpen(splashAdUnitId);
    }

    [ContextMenu("Present Ad Inspector")]
    public void OpenInspector()
    {
        DKMadsSdk.PresentAdInspector();
    }

    [ContextMenu("Load banner (JSON)")]
    public void LoadBannerJson()
    {
        Debug.Log($"[DKMads] LoadAd banner: {DKMadsSdk.LoadAd("YOUR_BANNER_AD_UNIT_UUID", 300, 250)}");
    }
}
