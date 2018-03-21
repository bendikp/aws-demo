
################################################################################
################################### AWS-demo ###################################
################################################################################

# Create and tag VPC:
VPC_ID=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 | jq -r ".Vpc.VpcId")
aws ec2 modify-vpc-attribute --vpc-id ${VPC_ID} --enable-dns-hostnames
aws ec2 create-tags --resources ${VPC_ID} --tags Key=Name,Value=Demo 

# Create and tag Internet Gateway:
IGW_ID=$(aws ec2 create-internet-gateway | jq -r ".InternetGateway.InternetGatewayId")
aws ec2 create-tags --resources ${IGW_ID} --tags Key=Name,Value=Demo

# Attach IGW to VPC:
aws ec2 attach-internet-gateway --internet-gateway-id ${IGW_ID} --vpc-id ${VPC_ID}

# Create Subnets:
AZ_A_ID=$(aws ec2 describe-availability-zones | jq -r ".AvailabilityZones[0].ZoneName")
SN1_ID=$(aws ec2 create-subnet --vpc-id ${VPC_ID} --availability-zone ${AZ_A_ID} --cidr-block 10.0.0.0/24 | jq -r ".Subnet.SubnetId")
SN2_ID=$(aws ec2 create-subnet --vpc-id ${VPC_ID} --availability-zone ${AZ_A_ID} --cidr-block 10.0.3.0/24 | jq -r ".Subnet.SubnetId")
SN3_ID=$(aws ec2 create-subnet --vpc-id ${VPC_ID} --availability-zone ${AZ_A_ID} --cidr-block 10.0.6.0/24 | jq -r ".Subnet.SubnetId")

# Tag Subnets:
aws ec2 create-tags --resources ${SN1_ID} --tags Key=Name,Value=DMZ
aws ec2 create-tags --resources ${SN2_ID} --tags Key=Name,Value=Internal
aws ec2 create-tags --resources ${SN3_ID} --tags Key=Name,Value=Secure

# Give hosts in DMZ public IP-addresses:
aws ec2 modify-subnet-attribute --subnet-id ${SN1_ID} --map-public-ip-on-launch

# Create a NAT Gateway:
EIP_ID=$(aws ec2 allocate-address --domain vpc | jq -r ".AllocationId")
NGW_ID=$(aws ec2 create-nat-gateway --allocation-id ${EIP_ID} --subnet-id ${SN1_ID} | jq -r ".NatGateway.NatGatewayId")

################################################################################

# Create Route Tables:
RT1_ID=$(aws ec2 create-route-table --vpc-id ${VPC_ID} | jq -r ".RouteTable.RouteTableId")
RT2_ID=$(aws ec2 create-route-table --vpc-id ${VPC_ID} | jq -r ".RouteTable.RouteTableId")
RT3_ID=$(aws ec2 create-route-table --vpc-id ${VPC_ID} | jq -r ".RouteTable.RouteTableId")

# Tag Route Tables:
aws ec2 create-tags --resources ${RT1_ID} --tags Key=Name,Value=DMZ
aws ec2 create-tags --resources ${RT2_ID} --tags Key=Name,Value=Internal
aws ec2 create-tags --resources ${RT3_ID} --tags Key=Name,Value=Secure

# Create routes in Route Tables
aws ec2 create-route --route-table-id ${RT1_ID} --destination-cidr-block 0.0.0.0/0 --gateway-id ${IGW_ID}
aws ec2 create-route --route-table-id ${RT2_ID} --destination-cidr-block 0.0.0.0/0 --gateway-id ${NGW_ID}

# Associate Route Tables to Subnets
aws ec2 associate-route-table --route-table-id ${RT1_ID} --subnet-id ${SN1_ID}
aws ec2 associate-route-table --route-table-id ${RT2_ID} --subnet-id ${SN2_ID}
aws ec2 associate-route-table --route-table-id ${RT3_ID} --subnet-id ${SN3_ID}

################################################################################

# Create Security Groups:
SG1_ID=$(aws ec2 create-security-group --vpc-id ${VPC_ID} --group-name DMZ --description "Security group for DMZ" | jq -r ".GroupId")
SG2_ID=$(aws ec2 create-security-group --vpc-id ${VPC_ID} --group-name Internal --description "Security group for Internal" | jq -r ".GroupId")
SG3_ID=$(aws ec2 create-security-group --vpc-id ${VPC_ID} --group-name Secure --description "Security group for Secure" | jq -r ".GroupId")

# Tag Security Groups:
aws ec2 create-tags --resources ${SG1_ID} --tags Key=Name,Value=DMZ
aws ec2 create-tags --resources ${SG2_ID} --tags Key=Name,Value=Internal
aws ec2 create-tags --resources ${SG3_ID} --tags Key=Name,Value=Secure

# Find my public IP
MY_IP=$(curl -s ipinfo.io/ip)

# Create rules in Security Groups
aws ec2 authorize-security-group-ingress --group-id ${SG1_ID} --protocol tcp --port 22 --cidr ${MY_IP}/32
aws ec2 authorize-security-group-ingress --group-id ${SG1_ID} --protocol tcp --port 8080 --cidr ${MY_IP}/32
aws ec2 authorize-security-group-ingress --group-id ${SG2_ID} --protocol tcp --port 22 --source-group ${SG1_ID}
aws ec2 authorize-security-group-ingress --group-id ${SG3_ID} --protocol tcp --port 22 --source-group ${SG1_ID}

################################################################################

# Provision EC2-instances:
VM1_ID=$(aws ec2 run-instances --image-id ami-dff017b8 --count 1 --instance-type t2.micro --key-name aws_london_mac --security-group-ids ${SG1_ID} --subnet-id ${SN1_ID} | jq -r ".Instances[0].InstanceId")
VM2_ID=$(aws ec2 run-instances --image-id ami-dff017b8 --count 1 --instance-type t2.micro --key-name aws_london_mac --security-group-ids ${SG2_ID} --subnet-id ${SN2_ID} | jq -r ".Instances[0].InstanceId")
VM3_ID=$(aws ec2 run-instances --image-id ami-dff017b8 --count 1 --instance-type t2.micro --key-name aws_london_mac --security-group-ids ${SG3_ID} --subnet-id ${SN3_ID} | jq -r ".Instances[0].InstanceId")

# Tag EC2-instances:
aws ec2 create-tags --resources ${VM1_ID} --tags Key=Name,Value=DMZ
aws ec2 create-tags --resources ${VM2_ID} --tags Key=Name,Value=Internal
aws ec2 create-tags --resources ${VM3_ID} --tags Key=Name,Value=Secure

sleep 5

# Generate ssh config file with IPs
VM1_IP=$(aws ec2 describe-instances --instance-ids ${VM1_ID} | jq -r ".Reservations[].Instances[].PublicIpAddress")
VM2_IP=$(aws ec2 describe-instances --instance-ids ${VM2_ID} | jq -r ".Reservations[].Instances[].PrivateIpAddress")
VM3_IP=$(aws ec2 describe-instances --instance-ids ${VM3_ID} | jq -r ".Reservations[].Instances[].PrivateIpAddress")

cat << EOT > ~/.ssh/config
Host bastion
  Hostname $VM1_IP
  IdentityFile ~/.ssh/aws_london_mac.pem
  User ec2-user

Host internal
  Hostname $VM2_IP
  IdentityFile ~/.ssh/aws_london_mac.pem
  User ec2-user
  ProxyCommand ssh bastion -W %h:%p

Host secure
  Hostname $VM3_IP
  IdentityFile ~/.ssh/aws_london_mac.pem
  User ec2-user
  ProxyCommand ssh bastion -W %h:%p
EOT


#
# Clean up
# aws ec2 terminate-instances --instance-ids $VM3_ID $VM2_ID $VM1_ID
# aws ec2 delete-nat-gateway --nat-gateway-id $NGW_ID
# aws ec2 release-address --allocation-id $EIP_ID
# aws ec2 detach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID
# aws ec2 delete-vpc --vpc-id ${VPC_ID}
# 


# aws ec2 describe-vpcs | jq -r ".Vpcs[] | .VpcId"
# aws ec2 describe-vpcs --vpc-ids ${VPC_ID}
# aws ec2 terminate-instances --instance-ids $VM3_ID $VM2_ID $VM1_ID
