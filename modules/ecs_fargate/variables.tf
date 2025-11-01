variable "cluster_name" {
  type = string
}

variable "service_name" {
  type = string
}

variable "ecr_url" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
  default = []
}

variable "vpc_id" {
  type = string
}

variable "cpu" {
  type    = number
  default = 512
}

variable "memory" {
  type    = number
  default = 1024
}

variable "desired_count" {
  type    = number
  default = 1
}

variable "assign_public_ip" {
  type    = bool
  default = true
}

variable "user_container_port" {
  type    = number
  default = 8081
}

variable "course_container_port" {
  type    = number
  default = 8082
}

variable "user_env_vars" {
  type    = list(object({ name = string, value = string }))
  default = []
}

variable "course_env_vars" {
  type    = list(object({ name = string, value = string }))
  default = []
}

variable "tags" {
  type    = map(string)
  default = {}
}
