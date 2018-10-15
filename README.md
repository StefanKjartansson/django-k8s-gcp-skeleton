# django-k8s-gcp-skeleton

> Django project skeleton with a preconfigured CI/CD pipeline for [k8s][k8s] and [GCP][gcp].

django-k8s-gcp-skeleton is a django project skeleton with a preconfigured CI/CD pipeline that deploys onto a [Kubernetes][k8s] cluster running on [GCP][gcp]. It uses [CircleCI][circleci] for running tests, uploading code to GCP's [cloud build][cbuilder] and applying the [Kubernetes][k8s] deployments.

It comes with bootstrapping scripts for setting up a GCP [Cloud SQL][cloud-sql] instance, configuring a sql proxy, creating [Kubernetes][k8s] secrets & enabling GCP's [Stackdriver][stackdriver] tracing.

## Features

* Continous integration with CircleCI.
* Build containers with GCP's cloud build and saving to GCP's container registry.
* Deploy to a Kubernetes cluster running on GCP's Kubernetes Engine.
* Tracing with Stackdriver

## Configuration

### 1. Clone the project

1. Create a new repository on GitHub.
	* CircleCI also [works with BitBucket](https://circleci.com/integrations/bitbucket/) but the instructions assume that GitHub will be used.
2. Clone the skeleton into a local directory.
3. Delete the `.git` folder, run `git init`, commit and push into your new repository.

### 2. Create a GCP Project

Setup a GCP account, create a project and install the [gcloud][gcloud-sdk] command line tool. The gcloud tool needs to be configured for your project. Install [kubectl][kubectl]. GCP has up to date instructions for how to setup the cli tooling and creating a project.

### 3. Configure environment variables

Configure the following environment variables, I recommend [direnv][direnv] for managing environment variables but use whatever you're using already.

```bash
# The name you want to have on your k8s cluster
export CLUSTER_NAME=my-example-cluster
# The GCP region you want to use
export CLUSTER_REGION=europe-west3
# Name of your database instance, note: this is not the database name.
export DB_INSTANCE_NAME=my-psql
# The name of your database
export DB_NAME=my-example-db
# The name of your database user
export DB_USER=exampledbuser
# The password of your database user
export DB_PASSWORD=verysecret
# The id of the GCP project you created in the first step
export GCP_PROJECT=example-foobar-12232
# The name of your project
export PROJECT_NAME=myexample
# Your django secret key
export SECRET_KEY=somethingsecret
```

### 4. Provision GCP services

When the previous steps have been completed, run the following in your shell with the environment variables from the above step sourced.

```bash
# Login to GCP
$ gcloud auth login
# Enable the required GCP services
$ ./bootstrap/enable.sh
# Initialize the k8s application templates 
$ ./bootstrap/init.sh
# Create a k8s cluster
$ ./bootstrap/create-cluster.sh
# Create a DB 
$ ./bootstrap/setup-database.sh
# Create & configure service accounts
$ ./bootstrap/create-service-accounts.sh
```

You should now have a k8s cluster with a sql-proxy workload & service running.

### 4. Cleanup the repository

The scripts should have created k8s folders from the templates. Delete the k8s-templates folders and commit the change. Add the k8s folders the init script created and commit them.  

Copy the CI key:

```bash
cat ./bootstrap/keys/cibuild.json|base64
```

You can now delete the `./bootstrap/keys` folder.

### 5. Configuring CircleCI

All steps need to be configured inside CircleCI's interface.

1. Select your organization and add a project.
2. Select your repository, and set Linux as the operating system and Python as the language.
3. Press the "Start building" button.
4. The first build will fail the preflight check because the environment variables have not been configured.
5. In the build interface, press the settings configuration button
6. Add the following environment variables:
	* `GCP_AUTH` - This is the value of the base64 encoded `cibuild.json` key.
	* `GCP_PROJECT` - The id of the GCP project
  	* `CLUSTER_NAME` - Name of the kubernetes cluster
  	* `CLUSTER_REGION` - Name of the kubernetes cluster region
  	* `PROJECT_NAME` - Name of the project, used for containers & k8s.
7. Build the workflow again.
8. Navigate to the ip of the service listed in the kubernetes interface. It should return a HTTP response with the text body "ok".

## Next Steps

* Add a DATABASE_URL pointing to a local database and start working on your project.
* You can delete the bootstrap folder, it's not needed anymore.

## Release History

* 0.0.1
    * Initial release

## Meta

Distributed under the MIT license. See ``LICENSE`` for more information.

## Contributing

1. Fork it (<https://github.com/yourname/yourproject/fork>)
2. Create your feature branch (`git checkout -b feature/fooBar`)
3. Commit your changes (`git commit -am 'Add some fooBar'`)
4. Push to the branch (`git push origin feature/fooBar`)
5. Create a new Pull Request

<!-- Markdown links -->
[gcp]: https://cloud.google.com/
[circleci]: http://circleci.com
[k8s]: https://kubernetes.io
[cbuilder]: https://cloud.google.com/cloud-build/
[cloud-sql]: https://cloud.google.com/sql/
[stackdriver]: https://cloud.google.com/stackdriver/
[gcloud-sdk]: https://cloud.google.com/sdk/
[direnv]: https://direnv.net
[kubectl]: https://kubernetes.io/docs/tasks/tools/install-kubectl/