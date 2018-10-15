#!/usr/bin/env bash
#
#

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

err() {
  echo -e "${RED}[$(date +'%Y-%m-%dT%H:%M:%S%z')]:${NC} $@" >&2
}

log() {
  echo -e "${GREEN}[$(date +'%Y-%m-%dT%H:%M:%S%z')]:${NC} $@" >&1
}

die() {
  err "$@"
  exit 1
}

#######################################
# Runs preflight check
# Arguments:
#   None
# Returns:
#   None
#######################################
preflight_check() {
  required_vars=(
    GCP_PROJECT
    CLUSTER_NAME
    CLUSTER_REGION
  )
  missing_vars=()
  for i in "${required_vars[@]}"
  do
    test -n "${!i:+y}" || missing_vars+=("$i")
  done
  if [ ${#missing_vars[@]} -ne 0 ]
  then
    err "The following variables are not set, but should be:"
    printf ' %q\n' "${missing_vars[@]}" >&2
    exit 1
  fi
  log "preflight check succeded"
}

#######################################
# Creates a K8s cluster
# Arguments:
#   None
# Returns:
#   None
#######################################
create_cluster() {
  gcloud beta container \
    --project "$GCP_PROJECT" \
    clusters create "$CLUSTER_NAME" \
    --region "$CLUSTER_REGION" \
    --username "admin" \
    --cluster-version "1.10.7-gke.6" \
    --machine-type "n1-standard-1" \
    --image-type "COS" \
    --disk-type "pd-standard" \
    --disk-size "100" \
    --scopes "https://www.googleapis.com/auth/devstorage.read_only","https://www.googleapis.com/auth/logging.write","https://www.googleapis.com/auth/monitoring","https://www.googleapis.com/auth/servicecontrol","https://www.googleapis.com/auth/service.management.readonly","https://www.googleapis.com/auth/trace.append" \
    --num-nodes "1" \
    --enable-cloud-logging \
    --enable-cloud-monitoring \
    --network "projects/$GCP_PROJECT/global/networks/default" \
    --subnetwork "projects/$GCP_PROJECT/regions/$CLUSTER_REGION/subnetworks/default" \
    --addons HorizontalPodAutoscaling,HttpLoadBalancing \
    --no-enable-autoupgrade \
    --enable-autorepair
}

preflight_check
create_cluster
