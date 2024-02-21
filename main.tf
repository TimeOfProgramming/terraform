terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"

  backend "s3" {
    endpoints = {
      s3 = "https://storage.yandexcloud.net"
    }
    bucket     = "tf-state-bucket-mentor"
    region     = "ru-central1"
    key        = "issue1/lemp.tfstate"
    access_key = "YCAJEbwXD-pTQt9hDMLsyLpJ4"
    secret_key = "YCPHsbLrxJDogfWGD9WdVLmGr8kbSCekQKir63tz"

    skip_region_validation      = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true # необходимая опция Terraform для версии 1.6.1 и старше.
    skip_s3_checksum            = true # необходимая опция при описании бэкенда для Terraform версии 1.6.3 и старше.
  }
}

locals {
  folder_id = "b1gn1366nchejrqtie00"
  cloud_id  = "b1g78s5ferm2jsultro9"
}

provider "yandex" {
  service_account_key_file = "D:\\authorized_key.json"
  cloud_id                 = local.cloud_id
  folder_id                = local.folder_id
}

resource "yandex_vpc_network" "network" {
  name = "network"
}

resource "yandex_vpc_subnet" "subnet1" {
  name           = "subnet1"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.network.id
  v4_cidr_blocks = ["192.168.10.0/24"]
}

resource "yandex_vpc_subnet" "subnet2" {
  name           = "subnet2"
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.network.id
  v4_cidr_blocks = ["192.168.11.0/24"]
}

data "yandex_compute_image" "my_image1" {
  family = "lemp"
}

resource "yandex_compute_instance" "vm1" {
  name = "terraform-lemp"
  zone = "ru-central1-a"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.my_image1.id
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet1.id
    nat       = true
  }

  metadata = {
    ssh-keys = "${file("./cloud-config.yaml")}"
  }
}

data "yandex_compute_image" "my_image2" {
  family = "lamp"
}

resource "yandex_compute_instance" "vm2" {
  name = "terraform-lamp"
  zone = "ru-central1-b"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.my_image2.id
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet2.id
    nat       = true
  }

  metadata = {
    ssh-keys = "${file("./cloud-config.yaml")}"
  }
}

resource "yandex_lb_target_group" "my-target-group" {
  name      = "my-target-group"
  region_id = "ru-central1"

  target {
    subnet_id = yandex_vpc_subnet.subnet1.id
    address   = yandex_compute_instance.vm1.network_interface.0.ip_address
  }

  target {
    subnet_id = yandex_vpc_subnet.subnet2.id
    address   = yandex_compute_instance.vm2.network_interface.0.ip_address
  }
}

resource "yandex_lb_network_load_balancer" "my-network-load-balancer" {
  name = "my-network-load-balancer"

  listener {
    name = "my-listener"
    port = 8080
    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = yandex_lb_target_group.my-target-group.id

    healthcheck {
      name = "http"
      http_options {
        port = 8080
        path = "/ping"
      }
    }
  }
}
