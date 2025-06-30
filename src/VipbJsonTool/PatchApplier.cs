
using System.Collections.Generic;
using YamlDotNet.Serialization;
using Newtonsoft.Json.Linq;

namespace VipbJsonTool {
    public static class PatchApplier {
        public static void ApplyYamlPatch(JObject root, string yaml) {
            var deserializer = new DeserializerBuilder().Build();
            var patchMap = deserializer.Deserialize<Dictionary<string, object>>(yaml);
            foreach(var kvp in patchMap) {
                var path = kvp.Key;
                var value = kvp.Value == null ? null : JToken.FromObject(kvp.Value);
                ApplyPath(root, path.Split('.'), 0, value);
            }
        }

        private static void ApplyPath(JToken node, string[] parts, int idx, JToken value) {
            if (idx == parts.Length) return;
            var part = parts[idx];
            JToken child;
            if (part.Contains('[')) {
                // array element e.g. Items[0]
                var name = part.Substring(0, part.IndexOf('['));
                var posStr = part.Substring(part.IndexOf('[')+1);
                var pos = int.Parse(posStr.TrimEnd(']'));
                var arr = node[name] as JArray;
                if (arr == null) {
                    arr = new JArray();
                    node[name] = arr;
                }
                while (arr.Count <= pos) arr.Add(new JObject());
                child = arr[pos];
            } else {
                child = node[part];
                if (child == null) {
                    child = new JObject();
                    node[part] = child;
                }
            }
            if (idx == parts.Length-1) {
                node[part] = value;
            } else {
                ApplyPath(child, parts, idx+1, value);
            }
        }
    }
}
