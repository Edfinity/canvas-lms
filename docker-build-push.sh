#!/bin/bash

if (( $# < 1 )); then
  echo "Build and push a docker image"
  echo
  echo "Usage:"
  echo "docker-build-and-push version [push]"
  echo
  echo "example:"
  echo "./docker-build-push.sh 20240813 push"
  echo "Builds 20240813 and pushes to ecr."
  exit
fi

set -eo pipefail

echo "Building version $VERSION"
source .env

VERSION=$1
REGION=us-east-1

REPO_TAG=$PUBLIC_REPO:"$VERSION"
docker build -t $REPO_TAG --platform linux/amd64 -f Dockerfile.edfinity .

if [[ "$2" == "push" ]]
then
  echo "pushing $REPO_TAG"
  docker push "$REPO_TAG"
fi
