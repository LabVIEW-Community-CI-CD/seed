using System;
using System.IO;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

namespace VipbJsonTool
{
    internal class Program
    {
        static int Main(string[] args)
        {
            if (args.Length < 2)
            {
                Console.Error.WriteLine("Usage: VipbJsonTool <mode> <in> <out> [patchFile] [alwaysPatch] [branchName] [autoPr]");
                return 1;
            }

            string mode = args[0];
            string inPath = args[1];
            string outPath = args.Length > 2 ? args[2] : string.Empty;
            string patchFile = args.Length > 3 ? args[3] : string.Empty;
            string alwaysPatch = args.Length > 4 ? args[4] : string.Empty;
            string branchName = args.Length > 5 ? args[5] : string.Empty;
            bool autoPr = args.Length > 6 && args[6].Equals("true", StringComparison.OrdinalIgnoreCase);

            try
            {
                if (mode == "vipb2json")
                {
                    var xml = File.ReadAllText(inPath);
                    var doc = new System.Xml.XmlDocument();
                    doc.PreserveWhitespace = true;
                    doc.LoadXml(xml);
                    var json = JsonConvert.SerializeXmlNode(doc, Formatting.Indented, true);
                    File.WriteAllText(outPath, json);
                }
                else if (mode == "json2vipb")
                {
                    var json = File.ReadAllText(inPath);
                    var xml = JsonToXmlConverter.Convert(json);
                    File.WriteAllText(outPath, xml);
                }
                else if (mode == "patch2vipb")
                {
                    var json = File.ReadAllText(inPath);
                    var jObj = JObject.Parse(json);

                    if (!string.IsNullOrEmpty(patchFile) && File.Exists(patchFile))
                    {
                        PatchApplier.ApplyYamlPatch(jObj, File.ReadAllText(patchFile));
                    }
                    if (!string.IsNullOrEmpty(alwaysPatch) && File.Exists(alwaysPatch))
                    {
                        PatchApplier.ApplyYamlPatch(jObj, File.ReadAllText(alwaysPatch));
                    }

                    var patchedJson = jObj.ToString(Formatting.Indented);
                    File.WriteAllText(inPath, patchedJson); // overwrite
                    var xml = JsonToXmlConverter.Convert(patchedJson);
                    File.WriteAllText(outPath, xml);
                }
                else
                {
                    Console.Error.WriteLine($"Unknown mode {mode}");
                    return 2;
                }

                if (!string.IsNullOrEmpty(branchName))
                {
                    GitHelper.CommitAndPush(branchName, new[] { inPath, outPath, patchFile }, autoPr);
                }

                return 0;
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine(ex);
                return 99;
            }
        }
    }
}
