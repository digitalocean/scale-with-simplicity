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
