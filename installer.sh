#! /bin/bash
yum install python37 -y
curl -O https://bootstrap.pypa.io/get-pip.py
python3 get-pip.py
pip3 install ansible
pip3 install boto3
