using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using System.Text.Json;
using System.Text.Json.Nodes;
using YamlDotNet.Serialization;

// Namespace stays the same as existing file
namespace VipbJsonTool
{
    internal static class Program
    {
        /*
         * CLI usage:
         *   vipb2json  <vipb-in> <json-out>
         *   json2vipb  <json-in> <vipb-out>
         *   patchjson  <json-in> <json-out> <patch-yaml>
         *   patch2vipb <json-in> <vipb-out> <patch-yaml>
         */
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
                        Json2Vipb("patched.json", args[2]);
                        File.Delete("patched.json");
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

        // ----------------------------------------------------------------
        // Existing functions you already had (simplified stubs here)
        // ----------------------------------------------------------------
        static void Vipb2Json(string vipbIn, string jsonOut)
        {
            // Existing conversion logic – unchanged
            File.Copy(vipbIn, jsonOut, overwrite: true); // placeholder
        }
        static void Json2Vipb(string jsonIn, string vipbOut)
        {
            // Existing conversion logic – unchanged
            File.Copy(jsonIn, vipbOut, overwrite: true); // placeholder
        }

        // ----------------------------------------------------------------
        // NEW: apply alias patches
        // ----------------------------------------------------------------
        static void PatchJson(string inJson, string outJson, string patchYaml)
        {
            // 1) load alias map
            var catalog = new DeserializerBuilder().Build()
                .Deserialize<AliasCatalog>(File.ReadAllText(".vipb-alias-map.yml"));
            if (catalog.SchemaVersion != 1)
                throw new Exception($"Unsupported alias map schema: {catalog.SchemaVersion}");

            // 2) load patches (alias → value)
            var patches = new DeserializerBuilder().Build()
                .Deserialize<Dictionary<string, object>>(File.ReadAllText(patchYaml));

            // 3) load JSON as JsonNode tree
            var root = JsonNode.Parse(File.ReadAllText(inJson))
                       ?? throw new InvalidOperationException("Invalid JSON");

            // 4) apply each alias
            foreach (var kvp in patches)
            {
                if (!catalog.Aliases.TryGetValue(kvp.Key, out var jqPath))
                    throw new Exception($"Unknown alias '{kvp.Key}'");

                ApplyPath(root, jqPath.Trim('.').Split('.'), 0, kvp.Value);
            }

            File.WriteAllText(outJson,
                root.ToJsonString(new JsonSerializerOptions { WriteIndented = true }));
        }

        // Recursive helper: create nodes as needed and assign value
        static void ApplyPath(JsonNode node, string[] parts, int index, object value)
        {
            string key = parts[index];

            // final segment → set value
            if (index == parts.Length - 1)
            {
                node[key] = JsonSerializer.SerializeToNode(value);
                return;
            }

            // intermediate → descend or create
            if (node[key] is not JsonNode child)
            {
                child = new JsonObject();
                node[key] = child;
            }
            ApplyPath(child, parts, index + 1, value);
        }
    }
}
