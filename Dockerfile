FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY src/VipbJsonTool/ ./VipbJsonTool/
COPY .vipb-alias-map.yml /src/
RUN dotnet publish VipbJsonTool -c Release -r linux-x64 --self-contained -p:PublishSingleFile=true -o /app

FROM mcr.microsoft.com/dotnet/runtime-deps:8.0
RUN apt-get update && apt-get install -y git curl
COPY --from=build /app/VipbJsonTool /usr/local/bin/VipbJsonTool
COPY .vipb-alias-map.yml /vipb-alias-map.yml
COPY scripts/entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
