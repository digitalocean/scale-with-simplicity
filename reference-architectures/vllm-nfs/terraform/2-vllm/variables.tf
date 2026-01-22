variable "model_id" {
  description = "HuggingFace model ID to download and serve (e.g., Qwen/Qwen2.5-0.5B-Instruct, meta-llama/Llama-3.1-8B-Instruct)"
  type        = string
  default     = "Qwen/Qwen2.5-0.5B-Instruct"
}

variable "hf_token" {
  description = "HuggingFace API token for downloading gated models. Optional for public models like Qwen."
  type        = string
  sensitive   = true
  default     = ""
}

variable "replicas" {
  description = "Number of vLLM replicas. Set > 1 for high availability with multiple GPU nodes."
  type        = number
  default     = 1
}

variable "quantization" {
  description = "Quantization method for model inference (e.g., 'fp8' for FP8 quantization)."
  type        = string
  default     = "fp8"
}
