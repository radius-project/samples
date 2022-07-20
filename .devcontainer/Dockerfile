# See here for image contents: https://github.com/microsoft/vscode-dev-containers/tree/v0.192.0/containers/codespaces-linux
FROM mcr.microsoft.com/vscode/devcontainers/universal:linux

USER root

# Install Radius CLI
RUN wget -q "https://radiuspublic.blob.core.windows.net/tools/rad/install.sh" -O - | /bin/bash -s edge

# Download Radius Bicep extension and Radius extension.
RUN wget -O /home/rad-vscode-bicep.vsix https://radiuspublic.blob.core.windows.net/tools/vscode-extensibility/edge/rad-vscode-bicep.vsix
RUN wget -O /home/rad-vscode.vsix https://radiuspublic.blob.core.windows.net/tools/vscode/edge/rad-vscode.vsix

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