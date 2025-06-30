// src/VipbJsonTool/AliasCatalog.cs
public record AliasCatalog
{
    [YamlDotNet.Serialization.YamlMember(Alias="schema_version")]
    public int SchemaVersion { get; init; }
    public Dictionary<string,string> Aliases { get; init; }
}
