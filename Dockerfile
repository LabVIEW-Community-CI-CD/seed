FROM ubuntu:20.04

# Install core dependencies and required tools
RUN apt-get update && \
    apt-get install -y git curl unzip patch yq && \
    rm -rf /var/lib/apt/lists/*

# Install GitHub CLI (gh)
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list && \
    apt-get update && \
    apt-get install -y gh && \
    rm -rf /var/lib/apt/lists/*

# Set working directory to GitHub Actions workspace
WORKDIR /github/workspace

# Copy entrypoint and action files
COPY entrypoint.sh /entrypoint.sh
COPY action.yml /action.yml

# Copy golden sample templates for seeding
COPY tests/Samples/seed.lvproj /github/workspace/tests/Samples/seed.lvproj
COPY tests/Samples/seed.vipb  /github/workspace/tests/Samples/seed.vipb

# Copy conversion CLI scripts and binary into /usr/local/bin
COPY bin/vipb2json      /usr/local/bin/vipb2json
COPY bin/json2vipb      /usr/local/bin/json2vipb
COPY bin/lvproj2json    /usr/local/bin/lvproj2json
COPY bin/json2lvproj    /usr/local/bin/json2lvproj
COPY bin/buildspec2json /usr/local/bin/buildspec2json
COPY bin/json2buildspec /usr/local/bin/json2buildspec
COPY bin/VipbJsonTool   /usr/local/bin/VipbJsonTool

# Ensure executables have the correct permissions
RUN chmod +x /entrypoint.sh \
            /usr/local/bin/vipb2json \
            /usr/local/bin/json2vipb \
            /usr/local/bin/lvproj2json \
            /usr/local/bin/json2lvproj \
            /usr/local/bin/buildspec2json \
            /usr/local/bin/json2buildspec \
            /usr/local/bin/VipbJsonTool

ENTRYPOINT ["/entrypoint.sh"]
