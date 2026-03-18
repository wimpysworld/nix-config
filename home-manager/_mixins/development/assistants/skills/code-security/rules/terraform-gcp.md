---
title: Secure GCP Terraform Configurations
impact: HIGH
impactDescription: Cloud misconfigurations and data exposure
tags: security, terraform, gcp, infrastructure, iac, gcs, gce, gke
---

## Secure GCP Terraform Configurations

**Impact: HIGH**

Secure configuration patterns for Google Cloud Platform (GCP) resources using Terraform.

---

## Google Cloud Storage (GCS)

**Incorrect:**
```hcl
resource "google_storage_bucket" "insecure" {
  name     = "example"
  location = "EU"
  uniform_bucket_level_access = false
}
resource "google_storage_bucket_iam_member" "public" {
  bucket = google_storage_bucket.default.name
  role   = "roles/storage.admin"
  member = "allUsers"
}
```

**Correct:**
```hcl
resource "google_storage_bucket" "secure" {
  name     = "example"
  location = "EU"
  uniform_bucket_level_access = true
  versioning { enabled = true }
  logging { log_bucket = "my-logging-bucket" }
}
resource "google_storage_bucket_iam_member" "restricted" {
  bucket = google_storage_bucket.default.name
  role   = "roles/storage.admin"
  member = "user:jane@example.com"
}
```

---

## Google Compute Engine and Firewall

**Incorrect:**
```hcl
resource "google_compute_instance" "insecure" {
  name = "test"; machine_type = "n1-standard-1"; zone = "us-central1-a"
  can_ip_forward = true; boot_disk {}
  metadata = { serial-port-enable = true, enable-oslogin = false }
  network_interface { network = "default"; access_config {} }
}
resource "google_compute_firewall" "open" {
  name = "allow-all"; network = "google_compute_network.vpc.name"
  allow { protocol = "tcp"; ports = [22, 3389] }
  source_ranges = ["0.0.0.0/0"]
}
```

**Correct:**
```hcl
resource "google_compute_instance" "secure" {
  name = "test"; machine_type = "n1-standard-1"; zone = "us-central1-a"
  can_ip_forward = false
  boot_disk { kms_key_self_link = google_kms_crypto_key.key.id }
  metadata = { enable-oslogin = true }
  network_interface { network = "default" }
  shielded_instance_config { enable_vtpm = true; enable_integrity_monitoring = true }
}
resource "google_compute_firewall" "restricted" {
  name = "allow-ssh"; network = "google_compute_network.vpc.name"
  allow { protocol = "tcp"; ports = ["22"] }
  source_ranges = ["172.1.2.3/32"]; target_tags = ["ssh"]
}
```

---

## Google Kubernetes Engine (GKE)

**Incorrect:**
```hcl
resource "google_container_cluster" "insecure" {
  name = "my-cluster"; location = "us-central1-a"; initial_node_count = 3
  enable_legacy_abac = true; logging_service = "none"
  master_auth { username = "admin"; password = "password123" }
}
```

**Correct:**
```hcl
resource "google_container_cluster" "secure" {
  name = "my-cluster"; location = "us-central1-a"; initial_node_count = 3
  enable_legacy_abac = false; enable_shielded_nodes = true; enable_binary_authorization = true
  private_cluster_config { enable_private_nodes = true; master_ipv4_cidr_block = "10.0.0.0/28" }
  master_authorized_networks_config { cidr_blocks { cidr_block = "10.0.0.0/8" } }
  master_auth { client_certificate_config { issue_client_certificate = false } }
  network_policy { enabled = true }
}
resource "google_container_node_pool" "secure" {
  name = "my-pool"; cluster = "my-cluster"
  management { auto_repair = true; auto_upgrade = true }
}
```

---

## Cloud SQL

**Incorrect:**
```hcl
resource "google_sql_database_instance" "insecure" {
  database_version = "MYSQL_8_0"; name = "instance"
  settings {
    tier = "db-f1-micro"
    ip_configuration { ipv4_enabled = true; authorized_networks { value = "0.0.0.0/0" } }
  }
}
```

**Correct:**
```hcl
resource "google_sql_database_instance" "secure" {
  database_version = "MYSQL_8_0"; name = "instance"
  settings {
    tier = "db-f1-micro"
    ip_configuration { ipv4_enabled = false; require_ssl = true; private_network = google_compute_network.net.id }
  }
}
```

---

## IAM, VPC, and Networking

**Incorrect:**
```hcl
resource "google_project_iam_member" "dangerous" {
  project = "your-project-id"; role = "roles/iam.serviceAccountTokenCreator"
  member  = "serviceAccount:test-compute@developer.gserviceaccount.com"
}
resource "google_compute_subnetwork" "no_logs" {
  name = "example"; ip_cidr_range = "10.0.0.0/16"; network = "google_compute_network.vpc.id"
}
resource "google_project" "default_network" {
  name = "My Project"; project_id = "your-project-id"; org_id = "1234567"
}
```

**Correct:**
```hcl
resource "google_project_iam_member" "safe" {
  project = "your-project-id"; role = "roles/viewer"; member = "user:jane@example.com"
}
resource "google_compute_subnetwork" "with_logs" {
  name = "example"; ip_cidr_range = "10.0.0.0/16"; network = "google_compute_network.vpc.self_link"
  log_config { aggregation_interval = "INTERVAL_10_MIN"; flow_sampling = 0.5 }
}
resource "google_project" "no_default_network" {
  name = "My Project"; project_id = "your-project-id"; org_id = "1234567"; auto_create_network = false
}
```

---

## KMS, Redis, BigQuery, and Pub/Sub

**Incorrect:**
```hcl
resource "google_kms_crypto_key" "unprotected" {
  name = "key"; key_ring = google_kms_key_ring.keyring.id; rotation_period = "15552000s"
}
resource "google_redis_instance" "insecure" { name = "my-instance"; memory_size_gb = 1; auth_enabled = false }
resource "google_bigquery_dataset" "unencrypted" { dataset_id = "example"; location = "EU" }
resource "google_pubsub_topic" "unencrypted" { name = "example-topic" }
```

**Correct:**
```hcl
resource "google_kms_crypto_key" "protected" {
  name = "key"; key_ring = google_kms_key_ring.keyring.id; rotation_period = "15552000s"
  lifecycle { prevent_destroy = true }
}
resource "google_redis_instance" "secure" {
  name = "my-instance"; memory_size_gb = 1; auth_enabled = true; transit_encryption_mode = "SERVER_AUTHENTICATION"
}
resource "google_bigquery_dataset" "encrypted" {
  dataset_id = "example"; location = "EU"
  default_encryption_configuration { kms_key_name = google_kms_crypto_key.example.name }
}
resource "google_pubsub_topic" "encrypted" { name = "topic"; kms_key_name = google_kms_crypto_key.key.id }
```

---

## Cloud Run, Cloud Build, Dataproc, and Vertex AI

**Incorrect:**
```hcl
resource "google_cloud_run_service_iam_member" "public" {
  location = google_cloud_run_service.default.location; service = google_cloud_run_service.default.name
  role = "roles/run.invoker"; member = "allUsers"
}
resource "google_cloudbuild_worker_pool" "public" { name = "pool"; location = "eu-west1"; worker_config { no_external_ip = false } }
resource "google_dataproc_cluster" "public" { name = "cluster"; region = "us-central1"; cluster_config { gce_cluster_config { internal_ip_only = false } } }
resource "google_notebooks_instance" "public" {
  name = "instance"; location = "us-west1-a"; machine_type = "e2-medium"
  vm_image { project = "deeplearning-platform-release"; image_family = "tf-latest-cpu" }; no_public_ip = false
}
```

**Correct:**
```hcl
resource "google_cloud_run_service_iam_member" "restricted" {
  location = google_cloud_run_service.default.location; service = google_cloud_run_service.default.name
  role = "roles/run.invoker"; member = "user:jane@example.com"
}
resource "google_cloudbuild_worker_pool" "private" { name = "pool"; location = "eu-west1"; worker_config { no_external_ip = true } }
resource "google_dataproc_cluster" "private" { name = "cluster"; region = "us-central1"; cluster_config { gce_cluster_config { internal_ip_only = true } } }
resource "google_notebooks_instance" "private" {
  name = "instance"; location = "us-west1-a"; machine_type = "e2-medium"
  vm_image { project = "deeplearning-platform-release"; image_family = "tf-latest-cpu" }; no_public_ip = true
}
```

---

## SSL Policies and DNS

**Incorrect:**
```hcl
resource "google_compute_ssl_policy" "weak" { name = "weak"; min_tls_version = "TLS_1_0" }
resource "google_dns_managed_zone" "weak" {
  name = "zone"; dns_name = "example.com."
  dnssec_config { state = "on"; default_key_specs { algorithm = "rsasha1"; key_length = 2048; key_type = "keySigning" } }
}
```

**Correct:**
```hcl
resource "google_compute_ssl_policy" "strong" { name = "strong"; min_tls_version = "TLS_1_2"; profile = "MODERN" }
resource "google_dns_managed_zone" "strong" {
  name = "zone"; dns_name = "example.com."
  dnssec_config { state = "on"; default_key_specs { algorithm = "rsasha256"; key_length = 2048; key_type = "keySigning" } }
}
```

---

## References

- [Google Cloud Security Best Practices](https://cloud.google.com/security/best-practices)
- [CIS Google Cloud Platform Foundation Benchmark](https://www.cisecurity.org/benchmark/google_cloud_computing_platform)
- [Terraform Google Provider Documentation](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
