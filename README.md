# Scale With Simplicity
# Scale With Simplicity

[![Security Scan](https://github.com/digitalocean/scale-with-simplicity/actions/workflows/security-scan.yaml/badge.svg)](https://github.com/digitalocean/scale-with-simplicity/actions/workflows/security-scan.yaml)

This repository contains reference architectures developed by DigitalOcean to help users understand how to leverage DigitalOcean Services for specific use cases. Each reference architecture is provided as a Terraform module, enabling you to deploy and test to facilitate learning and rapid development. These reference architecture modules leverage our [Terraform Module Library](./TERRAFORM-MODULE-LIBRARY.md), which contains reusable Terraform modules addressing specific components of the architectures.

> **Note**: While these reference architectures are fully functional, they are intended to be used as a reference. Please validate any configuration for your specific use case.

## 🏗️ Reference Architectures

| Name | Use Case | Periodic Validation | YouTube Video |
|------|----------|-------------------|---------------|
| [Globally Load Balanced Web Servers](./reference-architectures/globally-load-balanced-web-servers) | Load balanced web servers deployed into multiple regions with a global load balancer directing users to the region closest to them. | ✅ Yes | [Watch Tutorial](https://youtu.be/JRmCjIuOc4o?feature=shared) |
| [Partner Network Connect with AWS](./reference-architectures/partner-network-connect-aws) | End-to-End connection between DO VPC and AWS VPC using Partner Network Connect with HA support | ❌ No | 🔜 Coming Soon |
| [Site to Site VPN with AWS](./reference-architectures/site-to-site-vpn-aws) | IPSec VPN Gateway Droplet connecting DO VPC and DOKS cluster with AWS VPC | ❌ No | [Watch Tutorial](https://youtu.be/TCELPPiaI20?feature=shared) |

Reference Architectures deployed entirely on DigitalOcean are validated periodically (typically daily) to ensure they work as intended. Multi-cloud architectures are typically not validated via periodic testing but are still validated using static analysis and unit testing when updates are made.

## 🚀 Quick Start

### Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) (v1.5.0 or later)
- [Go](https://golang.org/dl/) (1.18+ for testing)
- DigitalOcean [Personal Access Token](https://docs.digitalocean.com/reference/api/create-personal-access-token/)

### Deployment Steps

1. **Set up your environment**:
   ```bash
   export DIGITALOCEAN_TOKEN="your_token_here"
   ```

2. **Clone the repository**:
   ```bash
   git clone https://github.com/digitalocean/scale-with-simplicity.git
   cd scale-with-simplicity
   ```

3. **Choose a reference architecture**:
   ```bash
   cd reference-architectures/<architecture-name>/terraform
   ```

4. **Configure your deployment**:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your specific values
   ```

5. **Deploy**:
   ```bash
   terraform init
   terraform plan -var-file terraform.tfvars
   terraform apply -var-file terraform.tfvars
   ```

6. **Clean up**:
   ```bash
   terraform destroy -var-file terraform.tfvars
   ```

## 🛠️ Development

### Setup Development Environment

```bash
# Install development tools
make install-tools

# Run all checks
make check
```

### Available Make Targets

- `make help` - Show available targets
- `make fmt` - Format Terraform files
- `make validate` - Validate Terraform configurations
- `make lint` - Run linting
- `make test` - Run unit tests
- `make docs` - Generate documentation
- `make clean` - Clean temporary files

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](./CONTRIBUTE.md) for details on how to get started.

### Code Quality

This project uses several tools to maintain code quality:

- **Pre-commit hooks** for automated checks
- **TFLint** for Terraform linting
- **Terratest** for testing
- **Security scanning** with Trivy and Checkov

## 📚 Documentation

- [Terraform Module Library](./TERRAFORM-MODULE-LIBRARY.md)
- [Contributing Guide](./CONTRIBUTE.md)
- [Individual Reference Architecture READMEs](./reference-architectures/)

## 🔒 Security

Security is a top priority. This repository includes:

- Automated security scanning
- Dependency vulnerability checks
- Static code analysis
- Regular security updates via Dependabot

## 📄 License

This project is licensed under the Apache License 2.0 - see the LICENSE file for details.

## 🆘 Support

- 📖 [DigitalOcean Documentation](https://docs.digitalocean.com/)
- 💬 [DigitalOcean Community](https://www.digitalocean.com/community/)
- 🐛 [Report Issues](https://github.com/digitalocean/scale-with-simplicity/issues)

