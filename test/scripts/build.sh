#!/bin/bash

# Copyright 2018 The Kubeflow Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This shell script is used to build an image from our argo workflow

set -o errexit
set -o nounset
set -o pipefail

export PATH=${GOPATH}/bin:/usr/local/go/bin:${PATH}
REGISTRY="${GCP_REGISTRY}"
PROJECT="${GCP_PROJECT}"
GO_DIR=${GOPATH}/src/github.com/${REPO_OWNER}/${REPO_NAME}
VERSION=$(git describe --tags --always --dirty)

echo "Activating service-account"
gcloud auth activate-service-account --key-file=${GOOGLE_APPLICATION_CREDENTIALS}

echo "Create symlink to GOPATH"
mkdir -p ${GOPATH}/src/github.com/${REPO_OWNER}
ln -s ${PWD} ${GO_DIR}

cd ${GO_DIR}
#echo "building container in gcloud"
#gcloud version
# gcloud components update -q

pids=()
cp cmd/manager/Dockerfile .
gcloud container builds submit . --tag=${REGISTRY}/${REPO_NAME}/vizier-core:${VERSION} --project=${PROJECT} &
pids+=($!)
sleep 30 # wait for copy code to gcloud

cp cmd/suggestion/random/Dockerfile .
gcloud container builds submit . --tag=${REGISTRY}/${REPO_NAME}/suggestion-random:${VERSION} --project=${PROJECT} &
pids+=($!)
sleep 30 # wait for copy code to gcloud

cp cmd/suggestion/grid/Dockerfile .
gcloud container builds submit . --tag=${REGISTRY}/${REPO_NAME}/suggestion-grid:${VERSION} --project=${PROJECT} &
pids+=($!)
sleep 30 # wait for copy code to gcloud

#cp cmd/suggestion/hyperband/Dockerfile .
#gcloud container builds submit . --tag=${REGISTRY}/${REPO_NAME}/suggestion-hyperband:${VERSION} --project=${PROJECT} &
#pids+=($!)
#sleep 30 # wait for copy code to gcloud

cp cmd/suggestion/bayesianoptimization/Dockerfile .
gcloud container builds submit . --tag=${REGISTRY}/${REPO_NAME}/suggestion-bayesianoptimization:${VERSION} --project=${PROJECT} &
pids+=($!)
sleep 30 # wait for copy code to gcloud

cp cmd/earlystopping/medianstopping/Dockerfile .
gcloud container builds submit . --tag=${REGISTRY}/${REPO_NAME}/earlystopping-medianstopping:${VERSION} --project=${PROJECT} &
pids+=($!)
sleep 30 # wait for copy code to gcloud

cp modeldb/Dockerfile .
gcloud container builds submit . --tag=${REGISTRY}/${REPO_NAME}/katib-frontend:${VERSION} --project=${PROJECT} &
pids+=($!)

for pid in ${pids[@]}; do
  wait $pid
  if [ $? -ne 0 ]; then
    exit 1
  fi
done
