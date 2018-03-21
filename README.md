# AWS-demo

Simple demo to set up a VPC with a public and two private subnets. 

## Shell

### Prerequisites

[Install aws-cli:](https://docs.aws.amazon.com/cli/latest/userguide/cli-install-macos.html)

Configure aws-cli:

```
aws configure set aws_access_key_id <key-id>
aws configure set aws_secret_access_key <key>
aws configure set region <region>
```

Credentials and config is usually found here: `~/.aws/config` and `~/.aws/credentials`

### Run
Run the script:
```
./aws-demo.sh
```

## Ansible

### Prerequisites
Install Ansible and some Python dependencies

* Ansible 2.4+
```
sudo pip install ansible
sudo pip install boto3 --ignore-installed six
sudo pip install botocore --ignore-installed six
```

### Run
```
ansible-playbook -i inventory playbooks/playbook.yml -e @vars.yml
```