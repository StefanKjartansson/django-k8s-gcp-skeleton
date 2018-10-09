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

### GCP Configuration

Setup a GCP account, create a project and install the [gcloud][gcloud-sdk] command line tool. The gcloud tool needs to be configured for your project. Install [kubectl][kubectl]. GCP has up to date instructions for how to setup the cli tooling and creating a project. When all of that is up and running, the following resources need to be enabled/created in GCP's interface.

1. In the Kubernetes engine interface, create a Kubernetes cluster. Note the cluster name and region.
2. Enable Cloud SQL & Cloud Build
3. Enable Stackdriver
4. In the "IAM > Service accounts" interface create a service account for the database user with the following permissions:
	* Cloud SQL Client
5. Create a key and download it. Note the path.
6. In the "IAM > Service accounts" interface create a service account for the circle user with the following permissions:
	* Cloud Build Service Account
	* Kubernetes Engine Admin
	* Storage Admin
	* Storage Object Creator
	* Viewer
7. Create a key and download it. Note the path.
8. In the "IAM > Service accounts" interface create a service account for the tracing user with the following permissions:
	* Cloud Trace Agent
	* Logs Configuration Writer
	* Logs Writer
	* Monitoring Metric Writer
9. Create a key and download it. Note the path.

### Configuring the skeleton

1. Create a new repository on GitHub.
	* CircleCI also [works with BitBucket](https://circleci.com/integrations/bitbucket/) but the instructions assume that GitHub will be used.
2. Clone the skeleton into a local directory.
3. Delete the `.git` folder, run `git init`, commit and push into your new repository.
4. Configure the following environment variables, I recommend [direnv][direnv] for managing envvars but use whatever you're using already.
	* `CLUSTER_NAME` - k8s cluster name, value from step 1 of GCP config.
	* `CLUSTER_REGION` - k8s cluster region, value from step 1 of GCP config.
	* `DB_INSTANCE_NAME` - Name of your database instance, note: this is not the database name.
	* `DB_NAME` - Name of your database.
	* `DB_PASSWORD` - Password for the proxy user
	* `DB_USER` - User name for the proxy user
	* `GCP_DB_KEY_PATH` - This should be the path to the file you downloaded in step 5 of GCP configuration.
	* `GCP_PROJECT` - Id of your GCP project.
	* `GCP_TRACE_KEY_PATH` - This should be the path to the file you downloaded in step 9 of GCP configuration.
	* `PROJECT_NAME` - Name of your project.
	* `SECRET_KEY` - Your Django secret key.
5. In the project root run: `$ ./bootstrap/init.sh`. This merges your environment variables with k8s deployment & configuration templates. You should now have a k8s folder inside the project root and bootstrap directory.
	* You can add further secrets to `bootstrap/k8s/secret.yaml`, be default it only contains the Django secret key.
	* You can safely delete the `k8s-templates` directories. They will not be used again.
6. Authenticate gcloud, run `$ gcloud auth login`
7. Run `$ gcloud config set project $GCP_PROJECT`
8. In the project root run: `$ ./bootstrap/configure-cluster.sh`. This script does the following:
	* Creates a trace key from the `$GCP_TRACE_KEY_PATH`.
	* Creates a k8s with the Django secret key.
	* Creates credentials secret for the sql proxy.
	* Creates db connection credentials secret.
	* Creates a PostgreSQL instance.
	* Creates a user for the instance.
	* Creates a database on the instance.
	* Creates a sql-proxy deployment.
9. Commit the k8s directories and push to the repository.

### Configuring CircleCI

All steps need to be configured inside CircleCI's interface.

1. Select your organization and add a project.
2. Select your repository, and set Linux as the operating system and Python as the language.
3. Press the "Start building" button.
4. The first build will fail the preflight check because the environment variables have not been configured.
5. In the build interface, press the settings configuration button
6. Add the following environment variables:
	* `GCP_AUTH` - This is the base64 encoded value of the circle service account key you downloaded in step 7 of the GCP configuration. You can base base64 encode it with `cat name-of-key.json|base64`.
	* `GCP_PROJECT` - The id of the GCP project
  	* `CLUSTER_NAME` - Name of the kubernetes cluster
  	* `CLUSTER_REGION` - Name of the kubernetes cluster region
  	* `PROJECT_NAME` - Name of the project, used for containers & k8s.
7. Build the workflow again.
8. Navigate to the ip of the service listed in the kubernetes interface. It should return a HTTP response with the text body "ok".

## Next Steps

Add a DATABASE_URL pointing to a local database and start working on your project.

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