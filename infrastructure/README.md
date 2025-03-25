# Terraform Installation and Deployment Guide

## Installation

1. Download Terraform from the [official website](https://www.terraform.io/downloads.html) or use package manager:

   ```bash
   # MacOS with Homebrew
   brew install terraform

   # Windows with Chocolatey
   choco install terraform

   # Linux (Ubuntu/Debian)
   wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
   echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
   sudo apt update && sudo apt install terraform
   ```

2. Verify installation:

   ```bash
   terraform -v
   ```

## Basic Deployment

1. Create a new directory for your project:

   ```bash
   mkdir terraform-project
   cd terraform-project
   ```

2. Create a `main.tf` file with your infrastructure code:

   ```hcl
   provider "aws" {
     region = "us-west-2"
   }

   resource "aws_instance" "example" {
     ami           = "ami-0c55b159cbfafe1f0"
     instance_type = "t2.micro"
     tags = {
       Name = "example-instance"
     }
   }
   ```

3. Initialize the working directory:

   ```bash
   terraform init
   ```

4. Preview changes:

   ```bash
   cp project.tfvars.example project.tfvars
   terraform plan -var-file=project.tfvars -out project.out
   ```

5. Apply changes:

   ```bash
   tterraform apply "project.out" 
   ```

6. Destroy resources when finished:

   ```bash
   terraform destroy
   ```

