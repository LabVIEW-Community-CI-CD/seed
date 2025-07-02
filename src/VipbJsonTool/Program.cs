using System;
using System.IO;
using System.Linq;
using System.Text;
using System.Xml;
using Newtonsoft.Json;

namespace VipbJsonTool
{
    internal static class Program
    {
        private static int Main(string[] args)
        {
            if (args.Length < 3)
            {
                Console.Error.WriteLine("Usage:");
                Console.Error.WriteLine("  VipbJsonTool vipb2json <in.vipb> <out.json>");
                Console.Error.WriteLine("  VipbJsonTool json2vipb <in.json> <out.vipb>");
                Console.Error.WriteLine("  VipbJsonTool patch2vipb <in.json> <out.vipb> <patch.yml>");
                return 1;
            }

            var mode    = args[0].ToLowerInvariant();
            var inFile  = args[1];
            var outFile = args[2];

            try
            {
                switch (mode)
                {
                    // ----------------------------------------------------
                    // VIPB → JSON
                    // ----------------------------------------------------
                    case "vipb2json":
                    {
                        var doc = new XmlDocument { PreserveWhitespace = true };
                        doc.Load(inFile);

                        // Convert to JSON via helper that strips XML prolog
                        var json = JsonToXmlConverter.XmlToJson(doc, omitRootObject: true);

                        File.WriteAllText(outFile, json, Encoding.UTF8);
                        break;
                    }

                    // ----------------------------------------------------
                    // JSON → VIPB
                    // ----------------------------------------------------
                    case "json2vipb":
                    {
                        var json = File.ReadAllText(inFile, Encoding.UTF8);
                        var xml  = JsonConvert.DeserializeXmlNode(json, "Package", true);
                        xml.Save(outFile);
                        break;
                    }

                    // ----------------------------------------------------
                    // JSON → VIPB with patch
                    // ----------------------------------------------------
                    case "patch2vipb":
                    {
                        if (args.Length < 4)
                        {
                            Console.Error.WriteLine("patch2vipb mode requires a patch YAML file.");
                            return 1;
                        }
                        var patchFile = args[3];

                        var json = File.ReadAllText(inFile, Encoding.UTF8);
                        var root = Newtonsoft.Json.Linq.JObject.Parse(json);

                        var patchYaml = File.ReadAllText(patchFile, Encoding.UTF8);
                        PatchApplier.ApplyYamlPatch(root, patchYaml);

                        var patchedDoc = JsonConvert.DeserializeXmlNode(root.ToString(), "Package", true);
                        patchedDoc.Save(outFile);
                        break;
                    }

                    default:
                        Console.Error.WriteLine($"Unknown mode: {mode}");
                        return 1;
                }

                return 0;
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine($"ERROR: {ex.Message}");
                Console.Error.WriteLine(ex);
                return 1;
            }
        }
    }
}
