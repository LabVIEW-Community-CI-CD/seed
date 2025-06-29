using System;
using System.IO;
using System.Collections.Generic;
using System.Text.Json;
using System.Xml;

if (args.Length != 3)
{
    Console.Error.WriteLine("Usage: VipbJsonTool vipb2json|json2vipb <input> <output>");
    return 1;
}

var mode   = args[0].ToLowerInvariant();
var input  = args[1];
var output = args[2];

if (mode == "vipb2json")
{
    VipbSerializer.ToJson(input, output);
}
else if (mode == "json2vipb")
{
    VipbSerializer.FromJson(input, output);
}
else
{
    Console.Error.WriteLine("Mode must be vipb2json or json2vipb");
    return 1;
}

return 0;

static class VipbSerializer
{
    public static void ToJson(string vipbPath, string jsonPath)
    {
        using var fs   = File.Create(jsonPath);
        using var json = new Utf8JsonWriter(fs, new JsonWriterOptions {
            Encoder    = System.Text.Encodings.Web.JavaScriptEncoder.UnsafeRelaxedJsonEscaping,
            Indented   = true,
            SkipValidation = false
        });
        using var xr = XmlReader.Create(vipbPath, new XmlReaderSettings { IgnoreWhitespace = false });

        var elemStack = new Stack<ElementFrame>();
        json.WriteStartObject();               // root

        while (xr.Read())
        {
            switch (xr.NodeType)
            {
                case XmlNodeType.Element:
                    var frame = new ElementFrame(xr.Name);
                    elemStack.Push(frame);

                    json.WritePropertyName(xr.Name);
                    json.WriteStartObject();

                    if (xr.HasAttributes)
                    {
                        while (xr.MoveToNextAttribute())
                        {
                            json.WriteString($"@{xr.Name}", xr.Value);
                        }
                        xr.MoveToElement();
                    }

                    if (xr.IsEmptyElement)
                    {
                        json.WriteEndObject();
                        elemStack.Pop();
                    }
                    break;

                case XmlNodeType.Text:
                    json.WriteString("__text", xr.Value);
                    break;

                case XmlNodeType.EndElement:
                    json.WriteEndObject();
                    elemStack.Pop();
                    break;
            }
        }
        json.WriteEndObject();                 // root
    }

    public static void FromJson(string jsonPath, string vipbPath)
    {
        var doc = new XmlDocument(); 
        using var jf = File.OpenRead(jsonPath);
        using var jd = JsonDocument.Parse(jf);

        var firstProp = jd.RootElement.EnumerateObject().First();
        var root      = doc.CreateElement(firstProp.Name);
        doc.AppendChild(root);
        BuildXml(root, firstProp.Value);    // << delegate into existing method

    var xws = new XmlWriterSettings {
        Indent = true,
        IndentChars = "  ",
        NewLineChars = "\r\n",
        OmitXmlDeclaration = true,
        Encoding = new System.Text.UTF8Encoding(false)   // no BOM
};

// write to memory first
using var ms = new MemoryStream();
using (var xw = XmlWriter.Create(ms, xws))
{
    doc.Save(xw);
}
ms.Position = 0;

// remove the space before '/>'
string xml = new StreamReader(ms, xws.Encoding).ReadToEnd()
                  .Replace(" />", "/>");

File.WriteAllText(vipbPath, xml, xws.Encoding);


        static void BuildXml(XmlElement parent, JsonElement src)
        {
            foreach (var prop in src.EnumerateObject())
            {
                if (prop.Name.StartsWith("@"))
                {
                    parent.SetAttribute(prop.Name.Substring(1), prop.Value.GetString() ?? "");
                    continue;
                }

                if (prop.NameEquals("__text"))
                {
                    parent.InnerText = prop.Value.GetString() ?? "";
                    continue;
                }

                XmlElement child = parent.OwnerDocument!.CreateElement(prop.Name);
                parent.AppendChild(child);

                if (prop.Value.ValueKind == JsonValueKind.Object)
                {
                    BuildXml(child, prop.Value);
                }
                else
                {
                    child.InnerText = prop.Value.GetString() ?? prop.Value.GetRawText();
                }
            }
        }
    }

    private sealed record ElementFrame(string Name);
}
