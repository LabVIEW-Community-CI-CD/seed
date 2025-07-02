using System.Linq;
using System.Xml;
using Newtonsoft.Json;

namespace VipbJsonTool
{
    /// <summary>
    /// Central helper that converts between XML (.vipb) and JSON,
    /// guaranteeing that the resulting JSON never contains an
    /// XML‑declaration node (<?xml …?>) at top level.  This prevents
    /// PowerShell’s ConvertFrom‑Json from throwing the
    /// “Additional text encountered after finished reading JSON content”
    /// error during round‑trip tests.
    /// </summary>
    public static class JsonToXmlConverter
    {
        /// <summary>
        /// Serialise an XmlDocument to JSON, omitting the XML declaration
        /// and optionally omitting the root wrapper (default = true).
        /// </summary>
        public static string XmlToJson(
            XmlDocument doc,
            bool omitRootObject = true,
            Formatting formatting = Formatting.Indented)
        {
            // --- Strip XML declaration ----------------------------------
            // Newtonsoft’s SerializeXmlNode includes the declaration
            // (< ?xml …?>) as a “?xml” property in JSON if we don’t remove it.
            // That leads to two top‑level keys, confusing some parsers.
            foreach (XmlNode node in doc.ChildNodes.Cast<XmlNode>().ToList())
            {
                if (node.NodeType == XmlNodeType.XmlDeclaration)
                {
                    doc.RemoveChild(node);
                }
            }

            // --- Serialise to JSON --------------------------------------
            return JsonConvert.SerializeXmlNode(doc, formatting, omitRootObject);
        }
    }
}
