diff --git a/tests/RoundTrip.GoldenSample.Tests.ps1 b/tests/RoundTrip.GoldenSample.Tests.ps1
index 5f4c7a3..02d84c1 100644
--- a/tests/RoundTrip.GoldenSample.Tests.ps1
+++ b/tests/RoundTrip.GoldenSample.Tests.ps1
@@
 param([string]$SourceFile = "tests/Samples/seed.vipb")
 
+# ──────────────────────────────────────────────────────────────────────────────
+# Utility: Flatten‑Object
+#   Recursively flattens a PSCustomObject / array tree into
+#   path‑to‑value pairs that are easy to serialise to YAML.
+# ──────────────────────────────────────────────────────────────────────────────
+function Flatten-Object {
+    [CmdletBinding()]
+    param(
+        [Parameter(Mandatory, ValueFromPipeline)][object]$InputObject,
+        [string]$BasePath = ''
+    )
+    process {
+        $dict = [System.Collections.Generic.Dictionary[string,object]]::new()
+        switch ($InputObject) {
+            { $_ -is [pscustomobject] } {
+                foreach ($p in $_.psobject.Properties) {
+                    $child = $BasePath ? "$BasePath.$($p.Name)" : $p.Name
+                    foreach ($kv in (Flatten-Object -InputObject $p.Value -BasePath $child)) {
+                        $dict[$kv.Key] = $kv.Value
+                    }
+                }
+            }
+            { $_ -is [System.Collections.IEnumerable] -and $_ -isnot [string] } {
+                for ($i = 0; $i -lt $_.Count; $i++) {
+                    $child = "$BasePath[$i]"
+                    foreach ($kv in (Flatten-Object -InputObject $_[$i] -BasePath $child)) {
+                        $dict[$kv.Key] = $kv.Value
+                    }
+                }
+            }
+            default {
+                if ($BasePath) { $dict[$BasePath] = $_ }
+            }
+        }
+        return $dict.GetEnumerator()
+    }
+}
+
 Describe "Golden Sample Full Coverage — $SourceFile" {
@@
-            foreach ($kv in Flatten-Object $json) {
+            foreach ($kv in (Flatten-Object -InputObject $json)) {
@@
-            foreach ($kv in Flatten-Object $json) {
+            foreach ($kv in (Flatten-Object -InputObject $json)) {
diff --git a/src/VipbJsonTool/XmlHelper.cs b/src/VipbJsonTool/XmlHelper.cs
new file mode 100644
index 0000000..dc18d02
--- /dev/null
+++ b/src/VipbJsonTool/XmlHelper.cs
@@
+using System;
+using System.IO;
+using System.Xml.Linq;
+
+namespace VipbJsonTool
+{
+    /// <summary>
+    /// Normalises LabVIEW XML roots: both &lt;Project&gt; and &lt;Package&gt;
+    /// are accepted and returned as a single XElement payload.
+    /// </summary>
+    internal static class XmlHelper
+    {
+        internal static XElement LoadPayload(string path)
+        {
+            var doc  = XDocument.Load(path, LoadOptions.PreserveWhitespace);
+            var root = doc.Root ?? throw new InvalidDataException("Empty XML document");
+
+            if (root.Name.LocalName.Equals("Project", StringComparison.OrdinalIgnoreCase) ||
+                root.Name.LocalName.Equals("Package", StringComparison.OrdinalIgnoreCase))
+            {
+                return root;
+            }
+
+            throw new InvalidDataException(
+                $"Unexpected root element <{root.Name.LocalName}> in '{Path.GetFileName(path)}'");
+        }
+    }
+}
diff --git a/src/VipbJsonTool/Program.cs b/src/VipbJsonTool/Program.cs
index 9aba112..c83f8ac 100644
--- a/src/VipbJsonTool/Program.cs
+++ b/src/VipbJsonTool/Program.cs
@@
-using System.Xml.Linq;
+using System.Xml.Linq;
+using VipbJsonTool;   // ─── new
 
@@  switch (cmd)
-        case "vipb2json":
-        {
-            var doc     = XDocument.Load(input, LoadOptions.PreserveWhitespace);
-            var payload = doc.Root;              // expected &lt;Package&gt;
+        case "vipb2json":
+        {
+            var payload = XmlHelper.LoadPayload(input);   // accepts &lt;Project&gt; *or* &lt;Package&gt;
             var json    = ConvertVipbToJson(payload);
             File.WriteAllText(output, json, Encoding.UTF8);
             Console.WriteLine("Successfully executed vipb2json");
             break;
         }
@@  switch (cmd)
-        case "buildspec2json":
-        {
-            var doc     = XDocument.Load(input, LoadOptions.PreserveWhitespace);
-            var payload = doc.Root;
+        case "buildspec2json":
+        {
+            var payload = XmlHelper.LoadPayload(input);
             var json    = ConvertBuildSpecToJson(payload);
             File.WriteAllText(output, json, Encoding.UTF8);
             Console.WriteLine("Successfully executed buildspec2json");
             break;
         }
