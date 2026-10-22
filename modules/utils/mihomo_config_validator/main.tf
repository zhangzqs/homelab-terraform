action "local_command" "validate" {
  config {
    command = "sh"
    arguments = [
      "-c",
      # local_command 失败时仅展示 stderr，Mihomo 的解析错误可能位于 stdout。
      <<-EOT
        validation_output=$(docker run --rm -i "$MIHOMO_VALIDATION_IMAGE" -t -f - 2>&1)
        validation_status=$?
        if [ "$validation_status" -ne 0 ]; then
          printf '%s\n' "$validation_output" >&2
          exit "$validation_status"
        fi
        printf '%s\n' "$validation_output"
      EOT
    ]
    environment = {
      MIHOMO_VALIDATION_IMAGE = var.mihomo_image
    }
    stdin = sensitive(var.config_content)
  }
}

resource "terraform_data" "validation" {
  input = {
    config_sha256 = sha256(var.config_content)
    image         = var.mihomo_image
  }

  lifecycle {
    action_trigger {
      events  = [before_create, before_update]
      actions = [action.local_command.validate]
    }
  }
}
