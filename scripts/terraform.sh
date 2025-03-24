#!/bin/bash

curl -o terraform.zip https://releases.hashicorp.com/terraform/1.6.6/terraform_1.6.6_linux_amd64.zip
unzip terraform.zip
sudo mv terraform /usr/local/bin/
rm terraform.zip