
using Newtonsoft.Json;
using System.Xml;

namespace VipbJsonTool {
    public static class JsonToXmlConverter {
        public static string Convert(string json) {
            var doc = JsonConvert.DeserializeXmlNode(json, "Package", true);
            using var sw = new System.IO.StringWriter();
            using var xw = XmlWriter.Create(sw, new XmlWriterSettings{ OmitXmlDeclaration = false, Indent=false });
            doc.WriteTo(xw);
            xw.Flush();
            return sw.ToString();
        }
    }
}
