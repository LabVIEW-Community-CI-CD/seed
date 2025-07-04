using System;
using System.IO;
using Newtonsoft.Json;
using System.Xml.Linq;

namespace LvprojJsonTool
{
    internal class Program
    {
        /// <summary>
        ///  lvproj2json --input <file.lvproj> --output <file.json>
        ///  json2lvproj --input <file.json>  --output <file.lvproj>
        /// </summary>
        static int Main(string[] args)
        {
            if (args.Length != 4 || args[0] != "--input" || args[2] != "--output")
            {
                Console.Error.WriteLine("Usage: LvprojJsonTool --input <file.lvproj|file.json> --output <file.json|file.lvproj>");
                return 1;
            }

            string inputPath  = args[1];
            string outputPath = args[3];

            if (!File.Exists(inputPath))
            {
                Console.Error.WriteLine($"Input file '{inputPath}' does not exist.");
                return 1;
            }

            // --- Ensure output directory exists (unless no directory specified)
            var dir = Path.GetDirectoryName(outputPath);
            if (!string.IsNullOrEmpty(dir))
            {
                Directory.CreateDirectory(dir);
            }

            try
            {
                if (inputPath.EndsWith(".lvproj", StringComparison.OrdinalIgnoreCase))
                {
                    // LVPROJ → JSON
                    var xml = XDocument.Load(inputPath);
                    var jsonString = JsonConvert.SerializeXNode(xml, Formatting.Indented);
                    File.WriteAllText(outputPath, jsonString);
                }
                else if (inputPath.EndsWith(".json", StringComparison.OrdinalIgnoreCase))
                {
                    // JSON → LVPROJ
                    var jsonText = File.ReadAllText(inputPath);
                    var xml      = JsonConvert.DeserializeXNode(jsonText, "Project");
                    xml.Save(outputPath);
                }
                else
                {
                    Console.Error.WriteLine("Input must be .lvproj or .json");
                    return 1;
                }
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine($"Error: {ex.Message}");
                return 1;
            }

            return 0;
        }
    }
}
