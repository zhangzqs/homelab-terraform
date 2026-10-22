action "local_command" "validate" {
  config {
    command = "docker"
    arguments = [
      "run", "--rm", "-i", var.mihomo_image,
      "-t", "-f", "-",
    ]
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
