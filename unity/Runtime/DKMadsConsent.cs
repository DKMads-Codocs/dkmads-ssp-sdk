using System;

namespace DKMads.SSP
{
    /// <summary>IAB consent payload for Google exchange policy alignment.</summary>
    [Serializable]
    public class DKMadsConsent
    {
        public bool gdpr;
        public bool ccpa;
        public string consentString;
        public string gppString;
        public string gppSid;
        public string usPrivacyString;
        /// <summary>iOS ATT: 0=notDetermined, 1=restricted, 2=denied, 3=authorized</summary>
        public int attStatus = -1;

        public string ToJson()
        {
            var att = attStatus >= 0 ? $",\"attStatus\":{attStatus}" : "";
            return "{" +
                   $"\"gdpr\":{(gdpr ? "true" : "false")}," +
                   $"\"ccpa\":{(ccpa ? "true" : "false")}," +
                   $"\"consentString\":{Escape(consentString)}," +
                   $"\"gppString\":{Escape(gppString)}," +
                   $"\"gppSid\":{Escape(gppSid)}," +
                   $"\"usPrivacyString\":{Escape(usPrivacyString)}" +
                   att +
                   "}";
        }

        private static string Escape(string value)
        {
            if (string.IsNullOrEmpty(value)) return "null";
            return "\"" + value.Replace("\\", "\\\\").Replace("\"", "\\\"") + "\"";
        }
    }
}
