FROM golang:1.24-alpine

# Install essential tools
RUN apk add --no-cache \
    make \
    unzip \
    wget \
    curl \
    git \
    ca-certificates \
    bash \
    openssh-client \
    jq \
    gcompat

# Install Terraform
ARG TERRAFORM_VERSION=1.11.4
RUN wget https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip \
 && unzip terraform_${TERRAFORM_VERSION}_linux_amd64.zip \
 && mv terraform /usr/local/bin/terraform \
 && rm terraform_${TERRAFORM_VERSION}_linux_amd64.zip

# Install TFLint
ARG TFLINT_VERSION=v0.57.0
RUN curl -sSL https://github.com/terraform-linters/tflint/releases/download/${TFLINT_VERSION}/tflint_linux_amd64.zip -o tflint.zip \
 && unzip tflint.zip \
 && mv tflint /usr/local/bin/tflint \
 && rm tflint.zip

# Install kubectl
ARG KUBECTL_VERSION=v1.32.0
RUN curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
 && chmod +x kubectl \
 && mv kubectl /usr/local/bin/kubectl

# Install deepsix (from private GitHub release)
ARG GITHUB_TOKEN
ARG DEEPSIX_VERSION=v0.9.3
RUN ASSET_URL=$(curl -sL \
      -H "Authorization: token ${GITHUB_TOKEN}" \
      -H "Accept: application/vnd.github.v3+json" \
      "https://api.github.com/repos/DO-Solutions/deepsix/releases/tags/${DEEPSIX_VERSION}" \
      | jq -r '.assets[] | select(.name == "deepsix-linux-amd64") | .url') \
 && curl -sL \
      -H "Authorization: token ${GITHUB_TOKEN}" \
      -H "Accept: application/octet-stream" \
      "${ASSET_URL}" \
      -o /usr/local/bin/deepsix \
 && chmod +x /usr/local/bin/deepsix

# Set up workdir and environment
WORKDIR /workspace
ENV GO111MODULE=on
ENV PATH=$PATH:/go/bin

CMD ["bash"]
