using Newtonsoft.Json;
using System.Xml;

namespace VipbJsonTool
{
    public static class JsonToXmlConverter
    {
        public static string Convert(string json)
        {
            var doc = JsonConvert.DeserializeXmlNode(json, "Package", true);
            var settings = new XmlWriterSettings { OmitXmlDeclaration = false, Indent = false };
            using var sw = new System.IO.StringWriter();
            using var xw = XmlWriter.Create(sw, settings);
            doc.WriteTo(xw);
            xw.Flush();
            return sw.ToString();
        }
    }
}
