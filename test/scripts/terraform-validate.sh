#!/bin/bash
terraform init -backend=false
terraform validate
terraform fmt -check -recursive
