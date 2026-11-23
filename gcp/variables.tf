variable "project_id" {
  type        = string
  description = "ID of an existing Google Cloud project."
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "image_tag" {
  type        = string
  default     = null
  description = "Backend image tag to deploy. Leave unset to provision infrastructure before pushing the image."
}

variable "cognito_user_pool_id" {
  type    = string
  default = ""
}

variable "cognito_client_id" {
  type    = string
  default = ""
}

variable "database_running" {
  type    = bool
  default = true
}
