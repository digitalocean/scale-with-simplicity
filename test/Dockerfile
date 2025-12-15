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
    openssh-client

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

# Set up workdir and environment
WORKDIR /workspace
ENV GO111MODULE=on
ENV PATH=$PATH:/go/bin

CMD ["bash"]
