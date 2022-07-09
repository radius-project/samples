# See here for image contents: https://github.com/microsoft/vscode-dev-containers/tree/v0.192.0/containers/codespaces-linux
FROM mcr.microsoft.com/vscode/devcontainers/universal:linux

USER root

# If "context" is set to ".." in devcontainer.json, use .devcontainer/library-scripts/*.sh
COPY library-scripts/*.sh /tmp/library-scripts/

ENV DOCKER_BUILDKIT=1
RUN apt-get update && /bin/bash /tmp/library-scripts/docker-in-docker-debian.sh
ENTRYPOINT ["/usr/local/share/docker-init.sh"]
VOLUME [ "/var/lib/docker" ]
CMD ["sleep", "infinity"]

# Install Radius CLI
RUN wget -q "https://get.radapp.dev/tools/rad/install.sh" -O - | /bin/bash

# Download Radius Bicep extension and Radius extension.
RUN wget -O /home/rad-vscode-bicep.vsix https://get.radapp.dev/tools/vscode/stable/rad-vscode-bicep.vsix
RUN wget -O /home/rad-vscode.vsix https://get.radapp.dev/tools/vscode/stable/rad-vscode.vsix

# Setup Kubectl
RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
RUN chmod +x ./kubectl
RUN mv ./kubectl /usr/local/bin

# Setup k3d
RUN wget -q -O - https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

# Setup Stern
RUN wget -O  ./stern.tar.gz https://github.com/stern/stern/releases/download/v1.21.0/stern_1.21.0_linux_arm64.tar.gz
RUN tar -xzf ./stern.tar.gz -C ./
RUN chmod +x ./stern
RUN mv ./stern /usr/local/bin

USER codespace