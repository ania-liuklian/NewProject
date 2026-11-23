locals {
  apis = toset([
    "artifactregistry.googleapis.com",
    "firebase.googleapis.com",
    "firebasehosting.googleapis.com",
    "iam.googleapis.com",
    "run.googleapis.com",
    "secretmanager.googleapis.com",
    "sqladmin.googleapis.com",
  ])
  registry = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.meetings.repository_id}"
}

resource "google_project_service" "api" {
  for_each           = local.apis
  service            = each.value
  disable_on_destroy = false
}

resource "google_artifact_registry_repository" "meetings" {
  repository_id = "meetings"
  location      = var.region
  format        = "DOCKER"
  depends_on    = [google_project_service.api]
}

resource "google_service_account" "api" {
  account_id   = "meetings-api"
  display_name = "Meetings Cloud Run runtime"
  depends_on   = [google_project_service.api]
}

resource "google_project_iam_member" "sql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.api.email}"
}

resource "google_sql_database_instance" "meetings" {
  name                = "meetings"
  database_version    = "POSTGRES_17"
  region              = var.region
  deletion_protection = false

  settings {
    edition           = "ENTERPRISE"
    tier              = "db-f1-micro"
    disk_size         = 10
    disk_type         = "PD_SSD"
    activation_policy = var.database_running ? "ALWAYS" : "NEVER"

    ip_configuration {
      ipv4_enabled = true
      # The Cloud Run integration connects using the Cloud SQL Auth Proxy.
      # No authorized networks are configured.
    }
  }

  depends_on = [google_project_service.api]
}

resource "google_sql_database" "meetings" {
  name     = "meetings"
  instance = google_sql_database_instance.meetings.name
}

resource "random_password" "database" {
  length  = 32
  special = false
}

resource "google_sql_user" "api" {
  name     = "meetings"
  instance = google_sql_database_instance.meetings.name
  password = random_password.database.result
}

resource "google_secret_manager_secret" "database_url" {
  secret_id = "meetings-database-url"

  replication {
    auto {}
  }

  depends_on = [google_project_service.api]
}

resource "google_secret_manager_secret_version" "database_url" {
  secret      = google_secret_manager_secret.database_url.id
  secret_data = "postgresql+asyncpg://${google_sql_user.api.name}:${random_password.database.result}@/${google_sql_database.meetings.name}?host=/cloudsql/${google_sql_database_instance.meetings.connection_name}"
}

resource "google_secret_manager_secret_iam_member" "api" {
  secret_id = google_secret_manager_secret.database_url.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.api.email}"
}

resource "google_firebase_project" "meetings" {
  provider   = google-beta
  project    = var.project_id
  depends_on = [google_project_service.api]
}

resource "google_firebase_hosting_site" "meetings" {
  provider = google-beta
  project  = google_firebase_project.meetings.project
  site_id  = var.project_id
}

resource "google_cloud_run_v2_service" "api" {
  count                = var.image_tag == null ? 0 : 1
  name                 = "meetings-api"
  location             = var.region
  deletion_protection  = false
  invoker_iam_disabled = true

  lifecycle {
    precondition {
      condition     = var.cognito_user_pool_id != "" && var.cognito_client_id != ""
      error_message = "Provide the existing Cognito pool ID and client ID before deploying the API."
    }
  }

  template {
    service_account       = google_service_account.api.email
    execution_environment = "EXECUTION_ENVIRONMENT_GEN2"

    scaling {
      min_instance_count = 0
      max_instance_count = 2
    }

    containers {
      image = "${local.registry}/api:${var.image_tag}"

      ports {
        container_port = 8080
      }

      env {
        name = "DATABASE_URL"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.database_url.secret_id
            version = google_secret_manager_secret_version.database_url.version
          }
        }
      }

      env {
        name  = "CORS_ORIGINS"
        value = "https://${var.project_id}.web.app,https://${var.project_id}.firebaseapp.com"
      }

      env {
        name  = "COGNITO_USER_POOL_ID"
        value = var.cognito_user_pool_id
      }

      env {
        name  = "COGNITO_CLIENT_ID"
        value = var.cognito_client_id
      }

      env {
        name  = "DB_POOL_SIZE"
        value = "2"
      }

      env {
        name  = "DB_MAX_OVERFLOW"
        value = "0"
      }

      volume_mounts {
        name       = "cloudsql"
        mount_path = "/cloudsql"
      }
    }

    volumes {
      name = "cloudsql"
      cloud_sql_instance {
        instances = [google_sql_database_instance.meetings.connection_name]
      }
    }
  }

  depends_on = [
    google_project_iam_member.sql_client,
    google_secret_manager_secret_iam_member.api,
  ]
}

output "image_repository" {
  value = "${local.registry}/api"
}

output "api_url" {
  value = one(google_cloud_run_v2_service.api[*].uri)
}

output "hosting_url" {
  value = "https://${google_firebase_hosting_site.meetings.site_id}.web.app"
}
