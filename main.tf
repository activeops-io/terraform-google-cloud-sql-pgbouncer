locals {
  private_ip = google_compute_instance.pgbouncer.network_interface[0].network_ip
  public_ip  = length(google_compute_instance.pgbouncer.network_interface[0].access_config) > 0 ? google_compute_instance.pgbouncer.network_interface[0].access_config[0].nat_ip : null
}

/* Instance Configuration --------------------------------------------------- */

module "pgbouncer_cloud_init" {
  source = "./modules/pgbouncer_cloud_init"

  pgbouncer_image_tag = var.pgbouncer_image_tag
  listen_port         = var.port
  database_host       = var.database_host
  database_port       = 5432
  users               = var.users
  auth_user           = var.auth_user
  auth_query          = var.auth_query
  default_pool_size   = var.default_pool_size
  max_db_connections  = var.max_db_connections
  max_client_conn     = var.max_client_connections
  pool_mode           = var.pool_mode
  logging_config      = var.pgbouncer_logging_config
  custom_config       = var.pgbouncer_custom_config
}

resource "google_compute_instance" "pgbouncer" {
  project      = var.project
  name         = var.name
  machine_type = var.machine_type
  zone         = var.zone
  tags         = var.tags

  dynamic "service_account" {
    for_each = var.disable_service_account ? [] : [1]
    content {
      email  = var.service_account_email
      scopes = var.service_account_scopes == null ? ["https://www.googleapis.com/auth/cloud-platform"] : var.service_account_scopes
    }
  }

  metadata = {
    google-logging-enabled = var.disable_service_account ? null : true
    user-data              = module.pgbouncer_cloud_init.cloud_config
    enable-oslogin         = var.enable_oslogin ? null : true
    pgbouncer-version      = var.pgbouncer_image_tag
  }

  metadata_startup_script = var.pgbouncer_startup_script

  boot_disk {
    initialize_params {
      image = var.boot_image
    }
  }

  network_interface {
    subnetwork = var.subnetwork
    network_ip = var.private_ip_address

    dynamic "access_config" {
      for_each = var.disable_public_ip ? [] : [1]
      content {
        nat_ip = var.public_ip_address
      }
    }
  }

  scheduling {
    automatic_restart = true
  }

  allow_stopping_for_update = true
}
