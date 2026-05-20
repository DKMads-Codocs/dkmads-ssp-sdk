using System;
using System.Text;

namespace DKMads.SSP
{
    /// <summary>
    /// Structured publisher targeting for bid <c>signals</c> and optional FPD sync.
    /// Field names align with <see cref="DKMadsSdk.SetTargetingSignals"/> and docs/TARGETING_SIGNALS.md.
    /// </summary>
    [Serializable]
    public sealed class DKMadsTargetingSignals
    {
        public string UserPid;
        public string DevicePid;
        public string Gender;
        public int? Age;
        public int? Yob;
        public string GeoCountry;
        public string GeoRegion;
        public string ConnectionType;
        public string ContentCategory;
        public string PageType;
        public string[] Interests = Array.Empty<string>();
        public string[] Keywords = Array.Empty<string>();
        public string[] Segments = Array.Empty<string>();

        /// <summary>Serialize to JSON for native bridges (snake_case keys).</summary>
        public string ToJson()
        {
            var sb = new StringBuilder();
            sb.Append('{');
            var first = true;
            void AddString(string key, string value)
            {
                if (string.IsNullOrEmpty(value)) return;
                if (!first) sb.Append(',');
                first = false;
                sb.Append('"').Append(key).Append("\":\"").Append(Escape(value)).Append('"');
            }
            void AddNumber(string key, int value)
            {
                if (!first) sb.Append(',');
                first = false;
                sb.Append('"').Append(key).Append("\":").Append(value);
            }
            void AddStringArray(string key, string[] values)
            {
                if (values == null || values.Length == 0) return;
                if (!first) sb.Append(',');
                first = false;
                sb.Append('"').Append(key).Append("\":[");
                for (var i = 0; i < values.Length; i++)
                {
                    if (i > 0) sb.Append(',');
                    sb.Append('"').Append(Escape(values[i] ?? "")).Append('"');
                }
                sb.Append(']');
            }

            AddString("user_pid", UserPid);
            AddString("device_pid", DevicePid);
            AddString("gender", Gender);
            if (Age.HasValue) AddNumber("age", Age.Value);
            if (Yob.HasValue) AddNumber("yob", Yob.Value);
            AddString("geo_country", GeoCountry);
            AddString("geo_region", GeoRegion);
            AddString("connection_type", ConnectionType);
            AddString("content_category", ContentCategory);
            AddString("page_type", PageType);
            AddStringArray("interests", Interests);
            AddStringArray("keywords", Keywords);
            AddStringArray("segments", Segments);
            sb.Append('}');
            return sb.ToString();
        }

        private static string Escape(string s) =>
            (s ?? "").Replace("\\", "\\\\").Replace("\"", "\\\"");

        /// <summary>Parse loose JSON object from native/editor tools (best-effort).</summary>
        public static DKMadsTargetingSignals FromJson(string json)
        {
            var signals = new DKMadsTargetingSignals();
            if (string.IsNullOrWhiteSpace(json)) return signals;
            // Minimal parser: delegates to SetUserData-compatible flat keys via manual extract
            signals.UserPid = ExtractString(json, "user_pid") ?? ExtractString(json, "userPid");
            signals.DevicePid = ExtractString(json, "device_pid") ?? ExtractString(json, "devicePid");
            signals.Gender = ExtractString(json, "gender");
            signals.GeoCountry = ExtractString(json, "geo_country") ?? ExtractString(json, "geoCountry");
            signals.GeoRegion = ExtractString(json, "geo_region") ?? ExtractString(json, "geoRegion");
            signals.ConnectionType = ExtractString(json, "connection_type") ?? ExtractString(json, "connectionType");
            if (int.TryParse(ExtractString(json, "age"), out var age)) signals.Age = age;
            if (int.TryParse(ExtractString(json, "yob"), out var yob)) signals.Yob = yob;
            return signals;
        }

        private static string ExtractString(string json, string key)
        {
            var needle = "\"" + key + "\":\"";
            var idx = json.IndexOf(needle, StringComparison.Ordinal);
            if (idx < 0) return null;
            idx += needle.Length;
            var end = json.IndexOf('"', idx);
            return end > idx ? json.Substring(idx, end - idx) : null;
        }
    }
}
