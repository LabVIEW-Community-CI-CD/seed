FROM ubuntu:20.04

# Install dependencies
RUN apt-get update && \
    apt-get install -y git curl unzip && \
    rm -rf /var/lib/apt/lists/*

# Set working directory to GitHub Actions workspace
WORKDIR /github/workspace

# Copy entrypoint and action files
COPY entrypoint.sh /entrypoint.sh
COPY action.yml /action.yml

# Copy golden sample templates for seeding
COPY tests/Samples/seed.lvproj /github/workspace/tests/Samples/seed.lvproj
COPY tests/Samples/seed.vipb  /github/workspace/tests/Samples/seed.vipb

# Copy conversion CLI binaries or scripts into /usr/local/bin
COPY bin/vipb2json /usr/local/bin/vipb2json
COPY bin/json2vipb /usr/local/bin/json2vipb

# Ensure executables have the correct permissions
RUN chmod +x /entrypoint.sh /usr/local/bin/vipb2json /usr/local/bin/json2vipb

ENTRYPOINT ["/entrypoint.sh"]
