using System.Collections.Generic;
using Newtonsoft.Json.Linq;
using YamlDotNet.Serialization;

namespace VipbJsonTool
{
    public static class PatchApplier
    {
        public static void ApplyYamlPatch(JObject root, string yaml)
        {
            var deserializer = new DeserializerBuilder().Build();
            var map = deserializer.Deserialize<Dictionary<string, object>>(yaml);
            foreach (var kvp in map)
            {
                ApplyPath(root, kvp.Key.Split('.'), 0, kvp.Value == null ? null : JToken.FromObject(kvp.Value));
            }
        }

        private static void ApplyPath(JToken node, string[] parts, int idx, JToken value)
        {
            var part = parts[idx];
            if (idx == parts.Length - 1)
            {
                node[part] = value;
                return;
            }
            JToken child = node[part];
            if (child == null)
            {
                child = new JObject();
                node[part] = child;
            }
            ApplyPath(child, parts, idx + 1, value);
        }
    }
}
