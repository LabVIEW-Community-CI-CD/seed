using System;
using System.Collections.Generic;
using System.IO;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Xml;
using YamlDotNet.Serialization;
using YamlDotNet.Serialization.NamingConventions;

namespace VipbJsonTool
{
    class Program
    {
        static int Main(string[] args)
        {
            if (args.Length < 1)
            {
                Console.Error.WriteLine("Usage: VipbJsonTool vipb2json|json2vipb|patch2vipb <input> <output> [patchYaml]");
                return 1;
            }

            try
            {
                switch (args[0])
                {
                    case "vipb2json":
                        Vipb2Json(args[1], args[2]);
                        break;
                    case "json2vipb":
                        Json2Vipb(args[1], args[2]);
                        break;
                    case "patch2vipb":
                        if (args.Length < 4) throw new ArgumentException("Missing patch YAML file");
                        Patch2Vipb(args[1], args[2], args[3]);
                        break;
                    default:
                        throw new ArgumentException($"Unknown mode '{args[0]}'");
                }
                return 0;
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine(ex.Message);
                return 1;
            }
        }

        static void Vipb2Json(string vipbIn, string jsonOut)
        {
            var doc = new XmlDocument();
            doc.Load(vipbIn);
            string json = JsonSerializer.Serialize(doc, new JsonSerializerOptions { WriteIndented = true });
            File.WriteAllText(jsonOut, json);
        }

        static void Json2Vipb(string jsonIn, string vipbOut)
        {
            // placeholder: implement your JSON→XML conversion logic here
            string xml = JsonToXmlConverter.Convert(File.ReadAllText(jsonIn));
            File.WriteAllText(vipbOut, xml);
        }

        static void Patch2Vipb(string srcJson, string vipbOut, string patchYaml)
        {
            var map = PatchMap.Load(patchYaml);
            var root = JsonNode.Parse(File.ReadAllText(srcJson)) 
                       ?? throw new InvalidOperationException("Invalid JSON");

            foreach (var kv in map.Patch)
                ApplyPath(root, kv.Key.Split('.', StringSplitOptions.RemoveEmptyEntries), kv.Value);

            var tmp = Path.GetTempFileName();
            File.WriteAllText(tmp, root.ToJsonString(new JsonSerializerOptions { WriteIndented = true }));
            Json2Vipb(tmp, vipbOut);
            File.Delete(tmp);
        }

        static void ApplyPath(JsonNode node, string[] path, JsonNode? value)
        {
            for (int i = 0; i < path.Length - 1; i++)
            {
                var key = path[i];
                if (node[key] is not JsonObject next)
                {
                    next = new JsonObject();
                    (node as JsonObject)![key] = next;
                }
                node = next;
            }

            if (node is JsonObject obj)
                obj[path[^1]] = value;
            else
                throw new InvalidOperationException("Cannot apply patch to non-object node");
        }
    }

    class PatchMap
    {
        public int SchemaVersion { get; set; }
        public Dictionary<string, JsonNode?> Patch { get; set; } = new();

        public static PatchMap Load(string yamlFile)
        {
            var yaml = File.ReadAllText(yamlFile);
            var des = new DeserializerBuilder()
                        .WithNamingConvention(CamelCaseNamingConvention.Instance)
                        .IgnoreUnmatchedProperties()
                        .Build();

            var dict = des.Deserialize<Dictionary<string, object>>(yaml)
                       ?? throw new InvalidOperationException("Invalid YAML");

            if (!dict.TryGetValue("schema_version", out var v) || Convert.ToInt32(v) != 1)
                throw new InvalidOperationException("Unsupported schema_version");

            if (!dict.TryGetValue("patch", out var p) || p is not Dictionary<object, object> raw)
                throw new InvalidOperationException("Missing or invalid 'patch' section");

            var map = new PatchMap();
            foreach (var kv in raw)
            {
                var path = kv.Key.ToString()!;
                JsonNode? node = kv.Value switch
                {
                    bool b   => JsonValue.Create(b),
                    int i    => JsonValue.Create(i),
                    long l   => JsonValue.Create(l),
                    double d => JsonValue.Create(d),
                    string s => JsonValue.Create(s),
                    _        => JsonValue.Create(kv.Value.ToString())
                };
                map.Patch[path] = node;
            }

            return map;
        }
    }

    static class JsonToXmlConverter
    {
        public static string Convert(string json)
        {
            // stub: your conversion implementation here
            throw new NotImplementedException("Implement JSON→VIPB XML conversion");
        }
    }
}
