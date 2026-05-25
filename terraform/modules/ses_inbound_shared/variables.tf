variable "account_id" {
  description = "AWS account ID that owns the inbound email stack."
  type        = string
}

variable "region" {
  description = "AWS region for SES receiving and Lambda."
  type        = string
}

variable "bucket_name" {
  description = "Shared bucket for raw inbound email."
  type        = string
}

variable "lambda_function_name" {
  description = "Shared forwarder Lambda function name."
  type        = string
}

variable "lambda_package_path" {
  description = "Path to the Lambda deployment package zip."
  type        = string
}

variable "lambda_handler" {
  description = "Lambda handler."
  type        = string
  default     = "index.handler"
}

variable "lambda_runtime" {
  description = "Lambda runtime."
  type        = string
  default     = "nodejs24.x"
}

variable "lambda_timeout" {
  description = "Lambda timeout in seconds."
  type        = number
  default     = 10
}

variable "lambda_memory_size" {
  description = "Lambda memory size in MB."
  type        = number
  default     = 128
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days."
  type        = number
  default     = 30
}

variable "alarm_actions" {
  description = "Optional CloudWatch alarm action ARNs, such as an SNS topic."
  type        = list(string)
  default     = []
}

variable "ok_actions" {
  description = "Optional CloudWatch OK action ARNs, such as an SNS topic."
  type        = list(string)
  default     = []
}

variable "error_alarm_evaluation_periods" {
  description = "Number of periods for the Lambda error alarm."
  type        = number
  default     = 1
}

variable "error_alarm_period_seconds" {
  description = "Period in seconds for the Lambda error alarm."
  type        = number
  default     = 300
}

variable "error_alarm_threshold" {
  description = "Threshold for the Lambda error alarm."
  type        = number
  default     = 1
}

variable "throttle_alarm_evaluation_periods" {
  description = "Number of periods for the Lambda throttle alarm."
  type        = number
  default     = 1
}

variable "throttle_alarm_period_seconds" {
  description = "Period in seconds for the Lambda throttle alarm."
  type        = number
  default     = 300
}

variable "throttle_alarm_threshold" {
  description = "Threshold for the Lambda throttle alarm."
  type        = number
  default     = 1
}

variable "enable_low_invocation_alarm" {
  description = "Whether to enable a low-invocation alarm for the shared forwarder Lambda."
  type        = bool
  default     = false
}

variable "low_invocation_alarm_period_seconds" {
  description = "Period in seconds for the low-invocation alarm."
  type        = number
  default     = 86400
}

variable "low_invocation_alarm_evaluation_periods" {
  description = "Number of periods for the low-invocation alarm."
  type        = number
  default     = 1
}

variable "low_invocation_alarm_threshold" {
  description = "Minimum expected invocation count for the low-invocation alarm period."
  type        = number
  default     = 1
}

variable "receipt_rule_set_name" {
  description = "SES receipt rule set name."
  type        = string
}

variable "activate_receipt_rule_set" {
  description = "Whether to activate the target SES receipt rule set."
  type        = bool
  default     = false
}

variable "domain_forwarding_config" {
  description = "Forwarding configuration consumed by the Lambda."
  type        = any
}
