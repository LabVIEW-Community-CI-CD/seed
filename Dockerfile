FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY src/VipbJsonTool/ ./VipbJsonTool/
RUN dotnet publish VipbJsonTool -c Release -r linux-x64 --self-contained -p:PublishSingleFile=true -o /app

FROM mcr.microsoft.com/dotnet/runtime-deps:8.0
COPY --from=build /app/VipbJsonTool /usr/local/bin/VipbJsonTool
ENTRYPOINT ["/usr/local/bin/VipbJsonTool"]
