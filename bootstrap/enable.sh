#!/usr/bin/env bash
#
#

set -e

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
# Enables a GCP service
# Arguments:
#   None
# Returns:
#   None
#######################################
_enable_service() {
  gcloud services enable "$1"
  log "Enabled service '$1'"
}

#######################################
# Enables the required services
# Arguments:
#   None
# Returns:
#   None
#######################################
enable_services() {
  services=(
    cloudbuild.googleapis.com
    cloudtrace.googleapis.com
    container.googleapis.com
    containerregistry.googleapis.com
    logging.googleapis.com
    sql-component.googleapis.com
    sqladmin.googleapis.com
  )
  for i in "${services[@]}"
  do
    _enable_service "$i"
  done
}

enable_services
