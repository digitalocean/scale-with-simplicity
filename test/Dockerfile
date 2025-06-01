FROM golang:1.24-bullseye

# Install essential tools
RUN apt-get update && apt-get install -y \
    make \
    unzip \
    wget \
    curl \
    git \
    ca-certificates \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

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

# Set up workdir and environment
WORKDIR /workspace
ENV GO111MODULE=on
ENV PATH=$PATH:/go/bin

CMD ["bash"]
