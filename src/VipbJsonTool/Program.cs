
using System;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using System.IO;

namespace VipbJsonTool {
    class Program {
        static int Main(string[] args) {
            if (args.Length < 2) {
                Console.Error.WriteLine("Usage: VipbJsonTool <mode> <inFile> [outFile] [patchFile] [alwaysPatch] [branchName] [autoPr]");
                return 1;
            }
            var mode = args[0];
            var inFile = args[1];
            var outFile = args.Length > 2 ? args[2] : string.Empty;
            var patchFile = args.Length > 3 ? args[3] : string.Empty;
            var alwaysPatchFile = args.Length > 4 ? args[4] : string.Empty;
            var branchName = args.Length > 5 ? args[5] : string.Empty;
            var autoPrStr = args.Length > 6 ? args[6] : "false";
            var autoPr = autoPrStr.Equals("true", StringComparison.OrdinalIgnoreCase);

            try {
                if (mode == "vipb2json") {
                    var xml = File.ReadAllText(inFile);
                    var doc = new System.Xml.XmlDocument();
                    doc.PreserveWhitespace = true;
                    doc.LoadXml(xml);
                    var json = JsonConvert.SerializeXmlNode(doc, Formatting.Indented, true);
                    File.WriteAllText(outFile, json);
                } else if (mode == "json2vipb") {
                    var json = File.ReadAllText(inFile);
                    var xml = JsonToXmlConverter.Convert(json);
                    File.WriteAllText(outFile, xml);
                } else if (mode == "patch2vipb") {
                    var json = File.ReadAllText(inFile);
                    var jObj = JObject.Parse(json);

                    // load patch map
                    if (!string.IsNullOrEmpty(patchFile) && File.Exists(patchFile)) {
                        var patchYaml = File.ReadAllText(patchFile);
                        PatchApplier.ApplyYamlPatch(jObj, patchYaml);
                    }
                    if (!string.IsNullOrEmpty(alwaysPatchFile) && File.Exists(alwaysPatchFile)) {
                        var alwaysYaml = File.ReadAllText(alwaysPatchFile);
                        PatchApplier.ApplyYamlPatch(jObj, alwaysYaml);
                    }

                    var patchedJson = jObj.ToString(Formatting.Indented);
                    File.WriteAllText(inFile, patchedJson); // overwrite source for transparency
                    var xml = JsonToXmlConverter.Convert(patchedJson);
                    File.WriteAllText(outFile, xml);
                } else {
                    Console.Error.WriteLine($"Unknown mode: {mode}");
                    return 2;
                }

                if (!string.IsNullOrEmpty(branchName)) {
                    // Do not commit patch YAML files (always generated dynamically)
                    GitHelper.CommitAndPush(branchName, new[] { inFile, outFile }, autoPr);
                }

                return 0;
            } catch (Exception ex) {
                Console.Error.WriteLine(ex);
                return 99;
            }
        }
    }
}
