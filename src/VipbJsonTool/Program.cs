using System;
using System.IO;
using System.Linq;
using System.Diagnostics;
using System.Collections.Generic;
using System.Text.Json;
using System.Text.Json.Nodes;
using YamlDotNet.Serialization;
using Newtonsoft.Json;
using XmlDocument = System.Xml.XmlDocument;
using XmlWriter = System.Xml.XmlWriter;
using XmlWriterSettings = System.Xml.XmlWriterSettings;

namespace VipbJsonTool
{
    internal static class Program
    {
        static int Main(string[] args)
        {
            if (args.Length < 1)
            {
                Console.Error.WriteLine("Usage: vipb2json|json2vipb|patchjson|patch2vipb ...");
                return 1;
            }

            try
            {
                switch (args[0].ToLowerInvariant())
                {
                    case "vipb2json":
                        Vipb2Json(args[1], args[2]);
                        break;

                    case "json2vipb":
                        Json2Vipb(args[1], args[2]);
                        break;

                    case "patchjson":
                        PatchJson(args[1], args[2], args[3]);
                        break;

                    case "patch2vipb":
                        PatchJson(args[1], "patched.json", args[3]);
                        ApplyAlwaysPatch("patched.json", args[4]);
                        Json2Vipb("patched.json", args[2]);
                        File.Delete("patched.json");
                        if (!string.IsNullOrWhiteSpace(args[5]))
                            CommitAndPush(args[5], args[2], args[1]);
                        if (args.Length > 6 && args[6].Equals("true", StringComparison.OrdinalIgnoreCase))
                            OpenPullRequest(args[5]);
                        break;

                    default:
                        Console.Error.WriteLine($"Unknown cmd {args[0]}");
                        return 1;
                }
                return 0;
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine(ex);
                return 1;
            }
        }

        // ------------------------------------------------------------------
        // VIPB ↔ JSON conversion (using Newtonsoft for XML-JSON bridge)
        // ------------------------------------------------------------------
        static void Vipb2Json(string vipbIn, string jsonOut)
        {
            var doc = new XmlDocument();
            doc.Load(vipbIn);
            var json = JsonConvert.SerializeXmlNode(doc, Formatting.Indented, true);
            File.WriteAllText(jsonOut, json);
        }

        static void Json2Vipb(string jsonIn, string vipbOut)
        {
            var json = File.ReadAllText(jsonIn);
            var doc = JsonConvert.DeserializeXmlNode(json, "VI_Package_Builder_Settings", true);
            var settings = new XmlWriterSettings
            {
                Indent = true,
                IndentChars = "  ",
                NewLineChars = "\r\n",
                OmitXmlDeclaration = true,
                Encoding = new System.Text.UTF8Encoding(false)
            };
            using var xw = XmlWriter.Create(vipbOut, settings);
            doc.Save(xw);
        }

        // ------------------------------------------------------------------
        // Patch helpers
        // ------------------------------------------------------------------
        static void PatchJson(string inJson, string outJson, string patchYaml)
        {
            var catalog = new DeserializerBuilder().Build()
                .Deserialize<AliasCatalog>(File.ReadAllText(".vipb-alias-map.yml"));
            if (catalog.schema_version != 1)
                throw new Exception($"Unsupported alias map schema: {catalog.schema_version}");

            var patches = new DeserializerBuilder().Build()
                .Deserialize<Dictionary<string, object>>(File.ReadAllText(patchYaml));

            var root = JsonNode.Parse(File.ReadAllText(inJson))
                       ?? throw new InvalidOperationException("Invalid JSON");

            foreach (var kvp in patches)
            {
                if (!catalog.aliases.TryGetValue(kvp.Key, out var jqPath))
                    throw new Exception($"Unknown alias '{kvp.Key}'");

                ApplyPath(root, jqPath.Trim('.').Split('.'), 0, kvp.Value);
            }

            File.WriteAllText(outJson,
                root.ToJsonString(new System.Text.Json.JsonSerializerOptions { WriteIndented = true }));
        }

        static void ApplyAlwaysPatch(string jsonPath, string alwaysPatchYaml)
        {
            if (string.IsNullOrWhiteSpace(alwaysPatchYaml)) return;
            if (new FileInfo(alwaysPatchYaml).Length == 0) return;
            PatchJson(jsonPath, jsonPath, alwaysPatchYaml);
        }

        static void ApplyPath(JsonNode node, string[] parts, int index, object value)
        {
            var key = parts[index];
            if (index == parts.Length - 1)
            {
                node[key] = System.Text.Json.JsonSerializer.SerializeToNode(value);
                return;
            }
            if (node[key] is not JsonNode child)
            {
                child = new JsonObject();
                node[key] = child;
            }
            ApplyPath(child, parts, index + 1, value);
        }

        // ------------------------------------------------------------------
        // Git / PR helpers
        // ------------------------------------------------------------------
        static void CommitAndPush(string branch, string vipbFile, string jsonFile)
        {
            Run("git", "config user.name github-actions[bot]");
            Run("git", "config user.email github-actions[bot]@users.noreply.github.com");
            Run("git", $"checkout -B \"{branch}\"");
            Run("git", $"add \"{vipbFile}\" \"{jsonFile}\"");
            Run("git", $"commit -m \"json-vipb: seed & patch\"");
            Run("git", $"push -u origin \"{branch}\"");
        }

        static void OpenPullRequest(string branch)
        {
            var token = Environment.GetEnvironmentVariable("GITHUB_TOKEN");
            if (string.IsNullOrWhiteSpace(token)) return;
            var repo = Environment.GetEnvironmentVariable("GITHUB_REPOSITORY");
            var api = $"https://api.github.com/repos/{repo}/pulls";
            var body = $"{{\"title\":\"Seed JSON-VIPB {branch}\",\"head\":\"{branch}\",\"base\":\"main\"}}";
            Run("curl", $"-s -X POST -H \"Authorization: Bearer {token}\" -H \"Accept: application/vnd.github+json\" -H \"User-Agent: json-vipb\" {api} -d '{body}'");
        }

        static void Run(string exe, string args)
        {
            var p = Process.Start(new ProcessStartInfo(exe, args)
            {
                RedirectStandardOutput = true,
                RedirectStandardError = true
            });
            p.WaitForExit();
            if (p.ExitCode != 0)
                throw new Exception($"{exe} {args}\n{p.StandardError.ReadToEnd()}");
        }
    }

    // ----------------------------------------------------------------------
    // Alias catalogue class (all-lowercase for YAML)
    // ----------------------------------------------------------------------

}
