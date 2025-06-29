# run this in the repo root; it writes Dockerfile
@'
FROM mcr.microsoft.com/dotnet/runtime-deps:8.0

# copy the self‑contained single‑file binary produced by dotnet publish
COPY publish/linux-x64-singlefile/VipbJsonTool /usr/local/bin/VipbJsonTool

ENTRYPOINT ["/usr/local/bin/VipbJsonTool"]
'@ | Set-Content -NoNewline -Encoding UTF8 Dockerfile
