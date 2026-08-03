# ott-agent/terraform/variables.tf
variable "environment" {
  default = "playground"
}

variable "image_tag" {
  default = "latest"
}

variable "desired_count" {
  default = 1
}

variable "acm_certificate_arn" {
  description = "ACM cert for HTTPS. Leave empty to use HTTP only."
  default     = ""
}
