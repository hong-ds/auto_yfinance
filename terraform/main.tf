terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 3.53"
    }
  }
}

provider "google" {
  project = "auto-yfinance"
  region  = "europe-west2"
  zone    = "europe-west2-b"
}

# resource "google_storage_bucket" "bucket" {
#   name = "auto-yfinance-cloud-function-bucket" # This bucket name must be unique
#   location = "europe-west2"
#   force_destroy = true
# }

resource "google_storage_bucket" "data_bucket" {
  name = "auto-yfinance-data-bucket" # This bucket name must be unique
  location = "europe-west2"
  force_destroy = true
}

# data "archive_file" "src" {
#   type        = "zip"
#   source_dir  = "${path.root}/../cloudfunction" # Directory where your Python source code is
#   output_path = "${path.root}/../temp/cloudfunction.zip"
# }

# resource "google_storage_bucket_object" "archive" {
#   name   = "${data.archive_file.src.output_md5}.zip"
#   bucket = google_storage_bucket.bucket.name
#   source = "${path.root}/../temp/cloudfunction.zip"
# }

resource "google_cloud_run_service" "service" {
  name        = "scheduled-cloud-run"
  location = "europe-west2"
  template {
    spec {
      containers {
        image = "eu.gcr.io/auto_yfinance/auto_yfinance"
        resources {
          limits ={
            cpu = "1000m"
            memory = "1024Mi"
          }
        }
      }
    }
  }
  traffic {
    percent         = 100
    latest_revision = true
  }
}

resource "google_service_account" "service_account" {
  account_id   = "cloud-run-invoker"
  display_name = "Cloud run Invoker Service Account"
}

resource "google_cloud_run_service_iam_member" "invoker" {
  project        = google_cloud_run_service.service.project
  service        = google_cloud_run_service.service.name

  role   = "roles/invoker"
  member = "serviceAccount:${google_service_account.service_account.email}"
}

resource "google_cloud_scheduler_job" "job" {
  name             = "cloud-function-scheduler"
  description      = "Trigger the ${google_cloud_run_service.service.name} Cloud Function Every saturday at 10."
  schedule         = "* 6 * * 6"
  time_zone        = "Europe/Dublin"
  attempt_deadline = "320s"

  http_target {
    http_method = "GET"
    uri         = "${google_cloud_run_service.service.status[0].url}/main"

    oidc_token {
      service_account_email = google_service_account.service_account.email
    }
  }
}
