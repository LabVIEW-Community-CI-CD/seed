using System;
using System.IO;
using System.Xml;
using Newtonsoft.Json;

namespace VipbJsonTool
{
    class Program
    {
        static int Main(string[] args)
        {
            if (args.Length < 3)
            {
                Console.Error.WriteLine("Usage: VipbJsonTool <mode> <input> <output>");
                return 1;
            }

            string mode = args[0].ToLower();
            string inputPath = args[1];
            string outputPath = args[2];

            // Ensure the output directory exists
            Directory.CreateDirectory(Path.GetDirectoryName(outputPath));

            try
            {
                switch (mode)
                {
                    case "vipb2json":
                        ConvertXmlToJson(inputPath, outputPath, "Package");
                        break;

                    case "json2vipb":
                        ConvertJsonToXml(inputPath, outputPath, "Package");
                        break;

                    case "lvproj2json":
                        ConvertXmlToJson(inputPath, outputPath, "Project");
                        break;

                    case "json2lvproj":
                        ConvertJsonToXml(inputPath, outputPath, "Project");
                        break;

                    case "buildspec2json":
                        ConvertBuildSpecToJson(inputPath, outputPath);
                        break;

                    case "json2buildspec":
                        ConvertJsonToBuildSpec(inputPath, outputPath);
                        break;

                    default:
                        Console.Error.WriteLine($"ERROR: Unknown mode '{mode}'");
                        return 1;
                }

                Console.WriteLine($"Successfully executed {mode}");
                return 0;
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine($"ERROR: {ex.Message}");
                return 1;
            }
        }

        // General XML → JSON conversion
        static void ConvertXmlToJson(string xmlPath, string jsonPath, string rootElementName)
        {
            if (!File.Exists(xmlPath))
                throw new FileNotFoundException($"Input file not found: {xmlPath}");

            var doc = new XmlDocument { PreserveWhitespace = true };
            doc.Load(xmlPath);

            if (doc.DocumentElement == null || doc.DocumentElement.Name != rootElementName)
                throw new InvalidOperationException($"Invalid root element. Expected '{rootElementName}'.");

            string json = JsonConvert.SerializeXmlNode(doc, Newtonsoft.Json.Formatting.Indented, true);
            File.WriteAllText(jsonPath, json);
        }

        // General JSON → XML conversion
        static void ConvertJsonToXml(string jsonPath, string xmlPath, string rootElementName)
        {
            if (!File.Exists(jsonPath))
                throw new FileNotFoundException($"Input file not found: {jsonPath}");

            string json = File.ReadAllText(jsonPath);
            var xmlDoc = JsonConvert.DeserializeXmlNode(json, rootElementName);

            using var writer = XmlWriter.Create(xmlPath, new XmlWriterSettings { Indent = true });
            xmlDoc.Save(writer);
        }

        // Unified buildspec → JSON (VIPB or LVPROJ based on extension)
        static void ConvertBuildSpecToJson(string inputPath, string outputPath)
        {
            var ext = Path.GetExtension(inputPath).ToLower();
            if (ext == ".vipb")
            {
                ConvertXmlToJson(inputPath, outputPath, "Package");
            }
            else if (ext == ".lvproj")
            {
                ConvertXmlToJson(inputPath, outputPath, "Project");
            }
            else
            {
                throw new InvalidOperationException("Unsupported input file type for buildspec2json. Must be .vipb or .lvproj");
            }
        }

        // Unified JSON → buildspec (VIPB or LVPROJ based on extension)
        static void ConvertJsonToBuildSpec(string inputPath, string outputPath)
        {
            var ext = Path.GetExtension(outputPath).ToLower();
            if (ext == ".vipb")
            {
                ConvertJsonToXml(inputPath, outputPath, "Package");
            }
            else if (ext == ".lvproj")
            {
                ConvertJsonToXml(inputPath, outputPath, "Project");
            }
            else
            {
                throw new InvalidOperationException("Unsupported output file type for json2buildspec. Must be .vipb or .lvproj");
            }
        }
    }
}
