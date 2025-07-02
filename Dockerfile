# Use the official .NET runtime dependencies image as base (no build stage needed)
FROM mcr.microsoft.com/dotnet/runtime-deps:8.0

# Install any additional system dependencies required by the tool
RUN apt-get update && apt-get install -y --no-install-recommends git curl && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /workspace

# Copy the pre-built VipbJsonTool binary from the build context into the image
# (The binary is built by the CI pipeline and placed in publish/linux-x64/)
COPY publish/linux-x64/VipbJsonTool /usr/local/bin/VipbJsonTool

# Copy entrypoint script and the VIPB alias map into the image
COPY scripts/entrypoint.sh /entrypoint.sh
COPY .vipb-alias-map.yml /workspace/vipb-alias-map.yml

# Ensure the entrypoint script is executable
RUN chmod +x /entrypoint.sh

# Set the container entrypoint
ENTRYPOINT ["/entrypoint.sh"]
