using System;
using System.IO;
using System.Text.Json;
using System.Text.Json.Nodes;
using YamlDotNet.Serialization;
using YamlDotNet.Serialization.NamingConventions;

namespace VipbJsonTool
{
    class Program
    {
        static void Main(string[] args)
        {
            if (args.Length < 1)
            {
                Console.Error.WriteLine("Usage: VipbJsonTool vipb2json|json2vipb|patch2vipb <input> <output> [patchYaml]");
                Environment.Exit(1);
            }

            var mode = args[0];
            try
            {
                switch (mode)
                {
                    case "vipb2json":
                        Vipb2Json(args[1], args[2]);
                        break;
                    case "json2vipb":
                        Json2Vipb(args[1], args[2]);
                        break;
                    case "patch2vipb":
                        PatchJson(args[1], args[2], args.Length > 3 ? args[3] : throw new ArgumentException("Missing patch YAML"));
                        break;
                    default:
                        throw new ArgumentException($"Unknown mode '{mode}'");
                }
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine(ex.Message);
                Environment.Exit(1);
            }
        }

        static void Vipb2Json(string vipbIn, string jsonOut)
        {
            var doc = new System.Xml.XmlDocument();
            doc.Load(vipbIn);
            var json = JsonSerializer.Serialize(doc, new JsonSerializerOptions { WriteIndented = true });
            File.WriteAllText(jsonOut, json);
        }

        static void Json2Vipb(string jsonIn, string vipbOut)
        {
            var xml = JsonToXmlConverter.Convert(File.ReadAllText(jsonIn)); // assume implementation
            File.WriteAllText(vipbOut, xml);
        }

        static void PatchJson(string inJson, string outVipb, string patchYaml)
        {
            // Load patch map from YAML
            var catalog = PatchMap.Load(patchYaml);

            // Read JSON
            var root = JsonNode.Parse(File.ReadAllText(inJson));
            if (root == null) throw new InvalidOperationException("Invalid JSON");

            foreach (var kv in catalog.Patch)
            {
                var path = kv.Key;
                var value = kv.Value;
                ApplyPath(root, path.TrimStart('.').Split('.'), 0, value!);
            }

            // Write out patched VIPB via round-trip JSON->VIPB
            var tmpJson = Path.GetTempFileName();
            File.WriteAllText(tmpJson, root.ToJsonString(new JsonSerializerOptions { WriteIndented = true }));
            Json2Vipb(tmpJson, outVipb);
            File.Delete(tmpJson);
        }

        static void ApplyPath(JsonNode node, string[] parts, int idx, JsonNode value)
        {
            if (idx == parts.Length - 1)
            {
                if (node is JsonObject obj)
                    obj[parts[idx]] = value;
                else
                    throw new InvalidOperationException("Cannot apply patch, target is not object");
            }
            else
            {
                var next = (node as JsonObject)?[parts[idx]];
                if (next == null)
                {
                    next = new JsonObject();
                    (node as JsonObject)![parts[idx]] = next;
                }
                ApplyPath(next, parts, idx + 1, value);
            }
        }
    }

    public class PatchMap
    {
        public int SchemaVersion { get; set; }
        public Dictionary<string, JsonNode?> Patch { get; set; } = new Dictionary<string, JsonNode?>();

        public static PatchMap Load(string yamlPath)
        {
            var yaml = File.ReadAllText(yamlPath);
            var deserializer = new DeserializerBuilder()
                                .WithNamingConvention(CamelCaseNamingConvention.Instance)
                                .IgnoreUnmatchedProperties()
                                .Build();
            var root = deserializer.Deserialize<Dictionary<string, object>>(yaml);

            if (!root.TryGetValue("schema_version", out var verObj) || Convert.ToInt32(verObj) != 1)
                throw new Exception("Unsupported schema_version");

            if (!root.TryGetValue("patch", out var patchObj) || !(patchObj is Dictionary<object, object> raw))
                throw new Exception("Missing or invalid 'patch' section");

            var map = new Dictionary<string, JsonNode?>();
            foreach (var kv in raw)
            {
                var path = kv.Key.ToString()!;
                JsonNode? node = kv.Value switch
                {
                    bool b   => JsonValue.Create(b),
                    int i    => JsonValue.Create(i),
                    string s => JsonValue.Create(s),
                    _        => JsonValue.Create(kv.Value.ToString())
                };
                map[path] = node;
            }

            return new PatchMap { SchemaVersion = 1, Patch = map };
        }
    }
}
