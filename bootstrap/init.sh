#!/usr/bin/env bash
# 
# Injects user environment variables into kubernetes templates
#

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ROOT="$(dirname "$DIR")"

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
    CLUSTER_NAME 
    CLUSTER_REGION 
    DB_INSTANCE_NAME 
    DB_NAME 
    GCP_PROJECT 
    PROJECT_NAME 
    SECRET_KEY
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
# Merges environment variables with 
# kubernetes templates.
# templates
# Arguments:
#   None
# Returns:
#   None
#######################################
generate_k8s_configuration() {
  mkdir -p $DIR/k8s
  for filename in $DIR/k8s-templates/*.yaml; do
      cat "$filename" |python $ROOT/scripts/override-envvars > $DIR/k8s/$(basename "$filename")
  done
  log "Generated cluster configuration"
  mkdir -p $ROOT/k8s
  for filename in $ROOT/k8s-templates/*.yaml; do
      cat "$filename" |python $ROOT/scripts/override-envvars > $ROOT/k8s/$(basename "$filename")
  done
  log "Generated deployment configuration"
}

preflight_check
generate_k8s_configuration
