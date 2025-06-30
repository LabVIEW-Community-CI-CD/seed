# ---------- build stage ----------
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY ./src ./src
RUN dotnet publish src/VipbJsonTool/VipbJsonTool.csproj -c Release -r linux-x64 --self-contained true -p:PublishSingleFile=true -o /app

# ---------- runtime stage ----------
FROM mcr.microsoft.com/dotnet/runtime-deps:8.0
RUN apt-get update && apt-get install -y --no-install-recommends git curl && rm -rf /var/lib/apt/lists/*
WORKDIR /workspace
COPY --from=build /app /usr/local/bin
COPY scripts/entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
