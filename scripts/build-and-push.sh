#!/bin/bash

# Configuration
AWS_REGION="us-west-2"
AWS_ACCOUNT_ID="123456789000"
REPOSITORY_NAME="helloworld-app"
IMAGE_TAG="latest"
KIND_CLUSTER_NAME="my-cluster" # assume the kind cluster is alreadyy running
TARGET="local"  # Set to either "local" or "ecr"

# Function to display usage
usage() {
  echo "Usage: $0"
  exit 1
}

# Build Docker image
echo "Building Docker image..."
docker build -t $REPOSITORY_NAME:$IMAGE_TAG .

if [ "$TARGET" == "ecr" ]; then
  # Authenticate Docker to ECR
  echo "Authenticating Docker to ECR..."
  aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

  # Check if the repository exists
  echo "Checking if the repository exists..."
  REPO_CHECK=$(aws ecr describe-repositories --repository-names $REPOSITORY_NAME --region $AWS_REGION 2>&1)

  if [[ $REPO_CHECK == *"RepositoryNotFoundException"* ]]; then
    echo "Repository does not exist. Creating repository..."
    aws ecr create-repository --repository-name $REPOSITORY_NAME --region $AWS_REGION
  else
    echo "Repository exists."
  fi

  # Tag Docker image for ECR
  echo "Tagging Docker image for ECR..."
  docker tag $REPOSITORY_NAME:$IMAGE_TAG $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$REPOSITORY_NAME:$IMAGE_TAG

  # Push Docker image to ECR
  echo "Pushing Docker image to ECR..."
  docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$REPOSITORY_NAME:$IMAGE_TAG

  echo "Docker image pushed to ECR successfully."

elif [ "$TARGET" == "local" ]; then
  # Tag Docker image for Kind
  echo "Tagging Docker image for Kind..."
  docker tag $REPOSITORY_NAME:$IMAGE_TAG $REPOSITORY_NAME:kind-$IMAGE_TAG

  # Check if Kind cluster is running
  echo "Checking if Kind cluster is running..."
  kind get clusters | grep -w $KIND_CLUSTER_NAME > /dev/null 2>&1

  if [ $? -ne 0 ]; then
    echo "Kind cluster $KIND_CLUSTER_NAME not found. Please ensure the Kind cluster is running."
    exit 1
  else
    echo "Kind cluster $KIND_CLUSTER_NAME is running."
  fi

  # Load Docker image into Kind cluster
  echo "Loading Docker image into Kind cluster..."
  kind load docker-image $REPOSITORY_NAME:kind-$IMAGE_TAG --name $KIND_CLUSTER_NAME

  # Verify that the image is loaded
  echo "Verifying the image is loaded in the Kind cluster..."
  kubectl get pods --all-namespaces -o jsonpath="{..image}" | tr -s '[[:space:]]' '\n' | grep $REPOSITORY_NAME

  if [ $? -eq 0 ]; then
    echo "Docker image successfully loaded into Kind cluster."
  else
    echo "Failed to load Docker image into Kind cluster."
    exit 1
  fi
else
  usage
fi
