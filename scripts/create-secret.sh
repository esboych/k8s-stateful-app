#!/bin/bash

# Check if environment variables are set
if [[ -z "$POSTGRES_USER" || -z "$POSTGRES_PASSWORD" ]]; then
  echo "POSTGRES_USER and POSTGRES_PASSWORD environment variables must be set."
  exit 1
fi

# Create Kubernetes secret from environment variables
kubectl create secret generic postgres-secret \
  --from-literal=postgresql-username=$POSTGRES_USER \
  --from-literal=postgresql-password=$POSTGRES_PASSWORD
