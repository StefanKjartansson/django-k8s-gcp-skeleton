#!/usr/bin/env bash
#
# Configures service accounts
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
    CLUSTER_REGION
    CLUSTER_NAME
    DB_PASSWORD
    DB_USER
    GCP_PROJECT
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
    gcloud --quiet config set project "${GCP_PROJECT}"
    log "set gcp project $GCP_PROJECT"
    gcloud container clusters get-credentials --region="$CLUSTER_REGION" "${CLUSTER_NAME}"
    log "kubectl logged in"
}

###########################
# Creates a Service Account
# Arguments:
#   Id
#   Display name
# Returns:
#   None
###########################
_create_sa() {
  local fullname="$1@$GCP_PROJECT.iam.gserviceaccount.com"
  # Exit early if the service account already exists
  gcloud iam service-accounts describe "$fullname" >/dev/null 2>&1 && log "Service Account '$1' already exists" && return
  gcloud iam service-accounts create "$1" \
    --display-name "$2" >/dev/null 2>&1
  log "Created Service Account '$1'"
}

###########################
# Grants a role to a Service Account
# Arguments:
#   Id
# Returns:
#   None
###########################
_grant_role_to_sa() {
  gcloud projects add-iam-policy-binding "$GCP_PROJECT" \
    --member "serviceAccount:$1@$GCP_PROJECT.iam.gserviceaccount.com" \
    --role "roles/$2" >/dev/null 2>&1
  log "Role '$2' granted to '$1'"
}

###########################
# Downloads a key for the user
# Arguments:
#   Id
# Returns:
#   None
###########################
_download_key() {
  mkdir -p "$DIR/keys"
  if [ -f "$DIR/keys/$1.json" ]; then
    return
  fi
  gcloud iam service-accounts keys create "$DIR/keys/$1.json" \
    --iam-account "$1@$GCP_PROJECT.iam.gserviceaccount.com"
  log "Downloaded key '$DIR/keys/$1.json'"
}

# create database client user
create_database_sa() {
  local user="dbuser"
  local secret_name="cloudsql-instance-credentials"
  _create_sa "$user" "Database user"
  _grant_role_to_sa "$user" cloudsql.client
  _download_key $user
  log "creating k8s secrets"
  kubectl create secret generic $secret_name \
    --from-file=credentials.json="$DIR/keys/dbuser.json"
  log "created secret $secret_name"
  kubectl create secret generic cloudsql-db-credentials \
    --from-literal=username="$DB_USER" --from-literal=password="$DB_PASSWORD"
  log "created secret cloudsql-db-credentials"
  kubectl apply -f "$DIR/k8s/sql-proxy.yaml"
  log "created sql-proxy deployment"
  rm -rf "$DIR/keys/dbuser.json"
}

# create build ci service account
create_build_sa() {
  local user="cibuild"
  _create_sa "$user" "CI Build user"
  roles=(
    container.admin
    cloudbuild.builds.editor
    cloudbuild.builds.viewer
    storage.admin
    viewer
  )
  for i in "${roles[@]}"
  do
    _grant_role_to_sa "$user" "$i"
  done
  _download_key $user
}

# create tracing service account
create_trace_sa() {
  local user="tracing"
  local secret_name="trace-secret"
  _create_sa "$user" "Stackdriver tracing user"
  roles=(
    cloudtrace.agent
    logging.configWriter
    logging.logWriter
    monitoring.metricWriter
  )
  for i in "${roles[@]}"
  do
    _grant_role_to_sa "$user" "$i"
  done
  _download_key "$user"
  kubectl create secret generic "$secret_name" \
    --from-file=trace_key.json="$DIR/keys/tracing.json"
  rm -rf "$DIR/keys/tracing.json"
}

#######################################
# Creates a django secret key secrets
# SECRET_KEY etc.
# Arguments:
#   None
# Returns:
#   None
#######################################
create_application_secret() {
  local secret_name="$PROJECT_NAME-secret"
  log "creating secret $secret_name"
  # Exit early if the secret exists, if the user
  # wants to alter the secret, delete it manually
  # and run the script again
  kubectl describe "secrets/$secret_name" && return
  kubectl create -f "$DIR/k8s/secrets.yaml"
  log "created $secret_name secret"
  kubectl get secret "$secret_name" -o yaml
}

preflight_check
authenticate
create_database_sa
create_trace_sa
create_build_sa
create_application_secret
