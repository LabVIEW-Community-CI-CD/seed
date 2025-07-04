using System;
using System.IO;
using Newtonsoft.Json;
using System.Xml.Linq;

namespace VipbJsonTool
{
    internal class Program
    {
        /// <summary>
        ///  vipb2json  --input <file.vipb>  --output <file.json>
        ///  json2vipb --input <file.json>  --output <file.vipb>
        /// </summary>
        static int Main(string[] args)
        {
            if (args.Length != 4 || args[0] != "--input" || args[2] != "--output")
            {
                Console.Error.WriteLine("Usage: VipbJsonTool --input <file.vipb|file.json> --output <file.json|file.vipb>");
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
                if (inputPath.EndsWith(".vipb", StringComparison.OrdinalIgnoreCase))
                {
                    // VIPB → JSON
                    var xml = XDocument.Load(inputPath);
                    var jsonString = JsonConvert.SerializeXNode(xml, Formatting.Indented);
                    File.WriteAllText(outputPath, jsonString);
                }
                else if (inputPath.EndsWith(".json", StringComparison.OrdinalIgnoreCase))
                {
                    // JSON → VIPB
                    var jsonText = File.ReadAllText(inputPath);
                    var xml      = JsonConvert.DeserializeXNode(jsonText, "VI_Package_Builder_Settings");
                    xml.Save(outputPath);
                }
                else
                {
                    Console.Error.WriteLine("Input must be .vipb or .json");
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