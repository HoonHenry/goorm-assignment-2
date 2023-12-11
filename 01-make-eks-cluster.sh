#!/bin/bash
#################### AWS Cloud9 settings ###################
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
unzip awscliv2.zip && \
sudo ./aws/install && \
export PATH=/usr/local/bin:$PATH && \
source ~/.bash_profile && \
aws --version && \
sudo curl -o /usr/local/bin/kubectl https://s3.us-west-2.amazonaws.com/amazon-eks/1.27.4/2023-08-16/bin/linux/amd64/kubectl && \
sudo chmod +x /usr/local/bin/kubectl && \
kubectl version --client=true --short=true && \
sudo yum install -y jq && \
sudo yum install -y bash-completion && \
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp && \
sudo mv -v /tmp/eksctl /usr/local/bin && \
eksctl version && \
wget https://gist.githubusercontent.com/joozero/b48ee68e2174a4f1ead93aaf2b582090/raw/2dda79390a10328df66e5f6162846017c682bef5/resize.sh && \
sh resize.sh && \
AWS_REGION=$(curl -s 169.254.169.254/latest/dynamic/instance-identity/document | jq -r '.region') && \
ACCOUNT_ID=$(curl -s 169.254.169.254/latest/dynamic/instance-identity/document | jq -r '.accountId') && \
echo "export AWS_REGION=${AWS_REGION}" | tee -a ~/.bash_profile && \
aws configure set default.region ${AWS_REGION} && \
echo "export ACCOUNT_ID=${ACCOUNT_ID}" | tee -a ~/.bash_profile && \
#################### AWS Cloud9 settings ###################


#################### Environment variables settings ###################
AWS_REGION=$(curl -s 169.254.169.254/latest/dynamic/instance-identity/document | jq -r '.region')
ACCOUNT_ID=$(curl -s 169.254.169.254/latest/dynamic/instance-identity/document | jq -r '.accountId')
ROOT_FOLDER="eks_test"
CLUSTER_NAME="eks-test"
LOAD_BALANCER_POLICY_NAME=AWSLoadBalancerControllerIAMPolicyFor${CLUSTER_NAME}
EBS_CSI_ROLE_NAME="AmazonEKS_EBS_CSI_Driver_For_${CLUSTER_NAME}"
# echo $AWS_REGION $ACCOUNT_ID $ROOT_FOLDER $CLUSTER_NAME $LOAD_BALANCER_POLICY_NAME $EBS_CSI_ROLE_NAME
#################### Environment variables settings ###################


#################### Cluster settings ###################
# create a folder for the project
mkdir ~/${ROOT_FOLDER} && cd ~/${ROOT_FOLDER} && /

# create a yaml for a cluster
cat << EOF > make-eks-cluster.yaml
---
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: ${CLUSTER_NAME} # EKS Cluster name
  region: ${AWS_REGION} # Region Code to place EKS Cluster
  version: "1.27"

vpc:
  cidr: "10.0.0.0/16" # CIDR of VPC for use in EKS Cluster
  nat:
    gateway: HighlyAvailable

managedNodeGroups:
  - name: node-group # Name of node group in EKS Cluster
    instanceType: m5.large # Instance type for node group
    desiredCapacity: 3 # The number of worker node in EKS Cluster
    volumeSize: 20  # EBS Volume for worker node (unit: GiB)
    privateNetworking: true
    iam:
      withAddonPolicies:
        imageBuilder: true # Add permission for Amazon ECR
        albIngress: true  # Add permission for ALB Ingress
        cloudWatch: true # Add permission for CloudWatch
        autoScaler: true # Add permission Auto Scaling
        ebs: true # Add permission EBS CSI driver

cloudWatch:
  clusterLogging:
    enableTypes: ["*"]
EOF

# deploy the cluster and 
# check that the node is properly deployed
eksctl create cluster -f make-eks-cluster.yaml && \
kubectl get nodes && \

# check the cluster credentials
cat ~/.kube/config && \

# define the role ARN(Amazon Resource Number)
rolearn=$(aws cloud9 describe-environment-memberships --environment-id=$C9_PID | jq -r '.memberships[].userArn') && \
echo ${rolearn} && \

# create an identity mapping
eksctl create iamidentitymapping \
    --cluster ${CLUSTER_NAME} \
    --arn ${rolearn} \
    --group system:masters \
    --username admin && \

# check aws-auth config map information
kubectl describe configmap -n kube-system aws-auth && \

mkdir -p manifests/alb-ingress-controller && cd manifests/alb-ingress-controller && \

# Final location
# ~/${ROOT_FOLDER}/manifests/alb-ingress-controller

# create IAM OpenID Connect (OIDC) identity provider for the cluster
eksctl utils associate-iam-oidc-provider \
    --region ${AWS_REGION} \
    --cluster ${CLUSTER_NAME} \
    --approve && \

# check IAM OIDC provider must exist in the cluster
OIDC_ID=$(aws eks describe-cluster --name ${CLUSTER_NAME} --query "cluster.identity.oidc.issuer" --output text | awk -F'/' '{printf $5}') && \
aws iam list-open-id-connect-providers | grep ${OIDC_ID} && \

# create an IAM Policy to grant to the AWS Load Balancer Controller
curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.5.4/docs/install/iam_policy.json && \
aws iam create-policy \
    --policy-name ${LOAD_BALANCER_POLICY_NAME} \
    --policy-document file://iam_policy.json && \

# create ServiceAccount for AWS Load Balancer Controller
eksctl create iamserviceaccount \
    --cluster ${CLUSTER_NAME} \
    --namespace kube-system \
    --name aws-load-balancer-controller \
    --attach-policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/${LOAD_BALANCER_POLICY_NAME} \
    --override-existing-serviceaccounts \
    --approve && \

# add AWS Load Balancer controller to the cluster
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.12.0/cert-manager.yaml && \

# download Load balancer controller yaml file
curl -Lo v2_5_4_full.yaml https://github.com/kubernetes-sigs/aws-load-balancer-controller/releases/download/v2.5.4/v2_5_4_full.yaml && \

# remove the ServiceAccount section in the manifest
sed -i.bak -e '596,604d' ./v2_5_4_full.yaml && \

# replace cluster name in the Deployment spec section
sed -i.bak -e "s|your-cluster-name|$CLUSTER_NAME|" ./v2_5_4_full.yaml && \

# deploy AWS Load Balancer controller file
kubectl apply -f v2_5_4_full.yaml && \

# download the IngressClass and IngressClassParams manifest to the cluster and apply the manifest to the cluster.
curl -Lo v2_5_4_ingclass.yaml https://github.com/kubernetes-sigs/aws-load-balancer-controller/releases/download/v2.5.4/v2_5_4_ingclass.yaml && \
kubectl apply -f v2_5_4_ingclass.yaml && \

# check that the deployment is successed and the controller is running and service account has been created
kubectl get deployment -n kube-system aws-load-balancer-controller && \
kubectl get sa aws-load-balancer-controller -n kube-system -o yaml && \

# detailed property values
kubectl logs -n kube-system $(kubectl get po -n kube-system | egrep -o "aws-load-balancer[a-zA-Z0-9-]+") && \
ALBPOD=$(kubectl get pod -n kube-system | egrep -o "aws-load-balancer[a-zA-Z0-9-]+") && \

kubectl describe pod -n kube-system ${ALBPOD} && \
#################### Cluster settings ###################


#################### EBS CSI Driver settings ###################
mkdir -p ~/${ROOT_FOLDER}/manifests/ebs_csi_driver && cd ~/${ROOT_FOLDER}/manifests/ebs_csi_driver && \
# create an IAM trust policy file for EBS CSI Driver
cat <<EOF > trust-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${ACCOUNT_ID}:oidc-provider/oidc.eks.${AWS_REGION}.amazonaws.com/id/${OIDC_ID}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc.eks.${AWS_REGION}.amazonaws.com/id/${OIDC_ID}:aud": "sts.amazonaws.com",
          "oidc.eks.${AWS_REGION}.amazonaws.com/id/${OIDC_ID}:sub": "system:serviceaccount:kube-system:ebs-csi-controller-sa"
        }
      }
    }
  ]
}
EOF

aws iam create-role \
    --role-name ${EBS_CSI_ROLE_NAME} \
    --assume-role-policy-document file://"trust-policy.json" && \
aws eks create-addon \
    --cluster-name ${CLUSTER_NAME} \
    --addon-name aws-ebs-csi-driver \
    --service-account-role-arn arn:aws:iam::${ACCOUNT_ID}:role/${EBS_CSI_ROLE_NAME} && \
eksctl get addon --cluster ${CLUSTER_NAME} | grep ebs

cat <<EOF > ebs-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateSnapshot",
        "ec2:AttachVolume",
        "ec2:DetachVolume",
        "ec2:ModifyVolume",
        "ec2:DescribeAvailabilityZones",
        "ec2:DescribeInstances",
        "ec2:DescribeSnapshots",
        "ec2:DescribeTags",
        "ec2:DescribeVolumes",
        "ec2:DescribeVolumesModifications"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateTags"
      ],
      "Resource": [
        "arn:aws:ec2:*:*:volume/*",
        "arn:aws:ec2:*:*:snapshot/*"
      ],
      "Condition": {
        "StringEquals": {
          "ec2:CreateAction": [
            "CreateVolume",
            "CreateSnapshot"
          ]
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DeleteTags"
      ],
      "Resource": [
        "arn:aws:ec2:*:*:volume/*",
        "arn:aws:ec2:*:*:snapshot/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateVolume"
      ],
      "Resource": "*",
      "Condition": {
        "StringLike": {
          "aws:RequestTag/ebs.csi.aws.com/cluster": "true"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateVolume"
      ],
      "Resource": "*",
      "Condition": {
        "StringLike": {
          "aws:RequestTag/CSIVolumeName": "*"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DeleteVolume"
      ],
      "Resource": "*",
      "Condition": {
        "StringLike": {
          "ec2:ResourceTag/ebs.csi.aws.com/cluster": "true"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DeleteVolume"
      ],
      "Resource": "*",
      "Condition": {
        "StringLike": {
          "ec2:ResourceTag/CSIVolumeName": "*"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DeleteVolume"
      ],
      "Resource": "*",
      "Condition": {
        "StringLike": {
          "ec2:ResourceTag/kubernetes.io/created-for/pvc/name": "*"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DeleteSnapshot"
      ],
      "Resource": "*",
      "Condition": {
        "StringLike": {
          "ec2:ResourceTag/CSIVolumeSnapshotName": "*"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DeleteSnapshot"
      ],
      "Resource": "*",
      "Condition": {
        "StringLike": {
          "ec2:ResourceTag/ebs.csi.aws.com/cluster": "true"
        }
      }
    }
  ]
}
EOF

# aws iam create-policy \
#   --policy-name EBS_CSI_POLICY \
#   --policy-document file://ebs-policy.json && \
# aws iam attach-role-policy \
#   --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/EBS_CSI_POLICY \
#   --role-name ${EBS_CSI_POLICY_NAME}

EBS_CSI_POLICY_NAME="EBS_CSI_Policy_${CLUSTER_NAME}"
aws iam create-policy \
  --policy-name ${EBS_CSI_POLICY_NAME} \
  --policy-document file://ebs-policy.json && \
aws iam attach-role-policy \
  --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/${EBS_CSI_POLICY_NAME} \
  --role-name ${EBS_CSI_ROLE_NAME}
#################### EBS CSI Driver settings ###################
