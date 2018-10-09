#!/usr/bin/env bash
#
# Creates Kubernetes resources for Django deployment
#

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ROOT="$(dirname "$DIR")"

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

DB_VERSION="POSTGRES_9_6"

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
    GCP_DB_KEY_PATH
    GCP_PROJECT
    GCP_TRACE_KEY_PATH
    PROJECT_NAME
    DB_PASSWORD
    DB_USER
    DB_NAME
    DB_INSTANCE_NAME
  )
  missing_vars=()
  for i in "${required_vars[@]}"
  do
    test -n "${!i:+y}" || missing_vars+=("$i")
  done
  if [ ${#missing_vars[@]} -ne 0 ]
  then
    echo "The following variables are not set, but should be:" >&2
    printf ' %q\n' "${missing_vars[@]}" >&2
    exit 1
  fi
  if [ ! -f "$GCP_DB_KEY_PATH" ]; then
    die "Missing GCP database key path"
  fi
  if [ ! -f "$GCP_TRACE_KEY_PATH" ]; then
    die "Missing GCP trace key path"
  fi
  if [ ! -d "$DIR/k8s" ]; then
    die "Init script has not been run, missing k8s folder"
  fi
  log "preflight check succeded"
}

#######################################
# Authenticates to gcloud, logs into to
# the container registry and kubectl.
# Arguments:
#   None
# Returns:
#   None
#######################################
authenticate() {
    gcloud --quiet config set project ${GCP_PROJECT}
    log "set gcp project $GCP_PROJECT"
    gcloud container clusters get-credentials --region="$CLUSTER_REGION" ${CLUSTER_NAME}
    log "kubectl logged in"
}

#######################################
# Creates a django secret key secrets
# SECRET_KEY etc.
# Arguments:
#   None
# Returns:
#   None
#######################################
create_secret() {
    local secret_name="$PROJECT_NAME-secret"
    log "creating secret $secret_name"
    # Exit early if the secret exists, if the user
    # wants to alter the secret, delete it manually
    # and run the script again
    kubectl describe secrets/$secret_name && return
    kubectl create -f "$DIR/k8s/secrets.yaml"
    log "created $secret_name secret"
    kubectl get secret $secret_name -o yaml
}

#######################################
# Creates a trace key used for stackdriver
# Arguments:
#   None
# Returns:
#   None
#######################################
create_trace_key() {
    local secret_name="trace-secret"
    log "creating secret $secret_name"
    kubectl describe secrets/$secret_name && return
    kubectl create secret generic $secret_name --from-file="$GCP_TRACE_KEY_PATH"
    log "created $secret_name secret"
    kubectl get secret $secret_name -o yaml
}

#######################################
# Creates a postgres instance
# Globals:
#   INSTANCE
#   REGION
#   VERSION
# Arguments:
#   None
# Returns:
#   None
#######################################
create_instance() {
  gcloud sql instances create "$DB_INSTANCE_NAME" \
    --database-version="$DB_VERSION" \
    --region="$CLUSTER_REGION" \
    --cpu=2 \
    --memory=4
  log "database $DB_INSTANCE_NAME created"
}

#######################################
# Creates the proxy user
# Globals:
#   DB_INSTANCE_NAME
#   DB_PASSWORD
#   DB_USER
# Arguments:
#   None
# Returns:
#   None
#######################################
create_proxyuser() {
  gcloud sql users create "$DB_USER" host \
    --instance="$DB_INSTANCE_NAME" \
    --password="$DB_PASSWORD"
  log "proxy user created"
}

#######################################
# Creates a database
# Globals:
#   DB_NAME
#   DB_INSTANCE_NAME
# Arguments:
#   None
# Returns:
#   None
#######################################
create_database() {
  gcloud sql databases create \
    "$DB_NAME" --instance="$DB_INSTANCE_NAME"
  log "database created"
}

#######################################
# Sets up a database instance
# Globals:
#   INSTANCE
# Arguments:
#   None
# Returns:
#   IP address of the instance
#######################################
setup_database() {
  gcloud sql instances describe "$DB_INSTANCE_NAME" && return
  create_instance
  create_proxyuser
  create_database
}

#######################################
# Creates the database secrets for k8s
# Arguments:
#   None
#######################################
create_db_secrets() {
  local secret_name="cloudsql-instance-credentials"
  log "creating secret $secret_name"
  kubectl describe secrets/$secret_name && return
  kubectl create secret generic $secret_name \
    --from-file=credentials.json="$GCP_DB_KEY_PATH"
  log "created secret $secret_name"
  kubectl create secret generic cloudsql-db-credentials \
    --from-literal=username="$DB_USER" --from-literal=password="$DB_PASSWORD"
  log "created secret cloudsql-db-credentials"
}

#######################################
# Configures the sql proxy for the gcp
# sql instance
# Arguments:
#   None
#######################################
create_sql_proxy() {
  kubectl apply -f "$DIR/k8s/sql-proxy.yaml"
}

preflight_check
authenticate
create_trace_key
create_secret
create_db_secrets
setup_database
create_sql_proxy
