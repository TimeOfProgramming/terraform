# terraform {
#   required_providers {
#     yandex = {
#       source = "yandex-cloud/yandex"
#     }
#   }
#   required_version = ">= 0.13"

#   backend "s3" {
#     endpoints = {
#       s3 = "https://storage.yandexcloud.net"
#     }
#     bucket     = "tf-state-bucket-mentor"
#     region     = "ru-central1"
#     key        = "issue1/lemp.tfstate"
#     access_key = "YCAJEbwXD-pTQt9hDMLsyLpJ4"
#     secret_key = "YCPHsbLrxJDogfWGD9WdVLmGr8kbSCekQKir63tz"

#     skip_region_validation      = true
#     skip_credentials_validation = true
#     skip_requesting_account_id  = true # необходимая опция Terraform для версии 1.6.1 и старше.
#     skip_s3_checksum            = true # необходимая опция при описании бэкенда для Terraform версии 1.6.3 и старше.
#   }
# }

# locals {
#   folder_id = "b1gn1366nchejrqtie00"
#   cloud_id  = "b1g78s5ferm2jsultro9"
# }

# provider "yandex" {
#   service_account_key_file = "D:\\authorized_key.json"
#   cloud_id                 = local.cloud_id
#   folder_id                = local.folder_id
# }

# resource "yandex_vpc_network" "network" {
#   name = "network"
# }

# resource "yandex_vpc_subnet" "subnet1" {
#   name           = "subnet1"
#   zone           = "ru-central1-a"
#   network_id     = yandex_vpc_network.network.id
#   v4_cidr_blocks = ["192.168.10.0/24"]
# }

# resource "yandex_vpc_subnet" "subnet2" {
#   name           = "subnet2"
#   zone           = "ru-central1-b"
#   network_id     = yandex_vpc_network.network.id
#   v4_cidr_blocks = ["192.168.11.0/24"]
# }

# data "yandex_compute_image" "my_image1" {
#   family = "lemp"
# }

# resource "yandex_compute_instance" "vm1" {
#   name = "terraform-lemp"
#   zone = "ru-central1-a"

#   resources {
#     cores  = 2
#     memory = 2
#   }

#   boot_disk {
#     initialize_params {
#       image_id = data.yandex_compute_image.my_image1.id
#     }
#   }

#   network_interface {
#     subnet_id = yandex_vpc_subnet.subnet1.id
#     nat       = true
#   }

#   metadata = {
#     ssh-keys = "${file("./cloud-config.yaml")}"
#   }
# }

# data "yandex_compute_image" "my_image2" {
#   family = "lamp"
# }

# resource "yandex_compute_instance" "vm2" {
#   name = "terraform-lamp"
#   zone = "ru-central1-b"

#   resources {
#     cores  = 2
#     memory = 2
#   }

#   boot_disk {
#     initialize_params {
#       image_id = data.yandex_compute_image.my_image2.id
#     }
#   }

#   network_interface {
#     subnet_id = yandex_vpc_subnet.subnet2.id
#     nat       = true
#   }

#   metadata = {
#     ssh-keys = "${file("./cloud-config.yaml")}"
#   }
# }

# resource "yandex_lb_target_group" "my-target-group" {
#   name      = "my-target-group"
#   region_id = "ru-central1"

#   target {
#     subnet_id = yandex_vpc_subnet.subnet1.id
#     address   = yandex_compute_instance.vm1.network_interface.0.ip_address
#   }

#   target {
#     subnet_id = yandex_vpc_subnet.subnet2.id
#     address   = yandex_compute_instance.vm2.network_interface.0.ip_address
#   }
# }

# resource "yandex_lb_network_load_balancer" "my-network-load-balancer" {
#   name = "my-network-load-balancer"

#   listener {
#     name = "my-listener"
#     port = 8080
#     external_address_spec {
#       ip_version = "ipv4"
#     }
#   }

#   attached_target_group {
#     target_group_id = yandex_lb_target_group.my-target-group.id

#     healthcheck {
#       name = "http"
#       http_options {
#         port = 8080
#         path = "/ping"
#       }
#     }
#   }
# }


terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}

locals {
  folder_id = "b1gn1366nchejrqtie00"
  cloud_id  = "b1g78s5ferm2jsultro9"
}

provider "yandex" {
  service_account_key_file = "../authorized_key.json"
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

resource "yandex_compute_instance" "vm1" {
  name = "vm1-ubuntu"
  zone = "ru-central1-a"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = "fd8t849k1aoosejtcicj"
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet1.id
    nat       = true
  }

  metadata = {
    user-data = "${file("./cloud-config.yaml")}"
  }
}

resource "null_resource" "generate_ssh_keys" {
  triggers = {
    instance_id = yandex_compute_instance.vm1.id
  }

  provisioner "remote-exec" {
    inline = [
      "ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ''",
      "echo \"$(cat ~/.ssh/id_ed25519.pub)\" > /tmp/id_ed25519.pub"
    ]

    connection {
      type        = "ssh"
      user        = "maxim"
      private_key = file("~/.ssh/id_ed25519")
      host        = yandex_compute_instance.vm1.network_interface.0.nat_ip_address
    }
  }

  provisioner "local-exec" {
    command = "scp -o StrictHostKeyChecking=no -i ~/.ssh/id_ed25519 maxim@${yandex_compute_instance.vm1.network_interface.0.nat_ip_address}:/tmp/id_ed25519.pub new77.pub"
  }
}

data "local_file" "foo" {
  depends_on = [null_resource.generate_ssh_keys]
  filename = "new77.pub"
}

output "new_ssh_public_key" {
  depends_on = [null_resource.generate_ssh_keys]
  value = data.local_file.foo.content
}

resource "yandex_compute_instance" "vm2" {
  depends_on = [null_resource.generate_ssh_keys]
  name = "vm2-ubuntu"
  zone = "ru-central1-a"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = "fd8t849k1aoosejtcicj"
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet1.id
    nat       = true
  }

  metadata = {
    user-data = <<-EOT
    #cloud-config
    ssh_pwauth: no
    users:
      - name: maxim
        groups: sudo
        shell: /bin/bash
        sudo: "ALL=(ALL) NOPASSWD:ALL"
        ssh_authorized_keys:
          - ${data.local_file.foo.content}
          - ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIwJ46wyh+n1d+cG7l5Ylp79qhuqj0lzLWVCBfN6n6IO max@max-RLEF-XX
    EOT
  }
}

resource "yandex_compute_instance" "vm3" {
  depends_on = [null_resource.generate_ssh_keys]
  name = "vm3-centos"
  zone = "ru-central1-a"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = "fd8p3qkkviv008rkeb83"
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet1.id
    nat       = true
  }

  metadata = {
    user-data = <<-EOT
    #cloud-config
    ssh_pwauth: no
    users:
      - name: maxim
        groups: sudo
        shell: /bin/bash
        sudo: "ALL=(ALL) NOPASSWD:ALL"
        ssh_authorized_keys:
          - ${data.local_file.foo.content}
          - ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIwJ46wyh+n1d+cG7l5Ylp79qhuqj0lzLWVCBfN6n6IO max@max-RLEF-XX
    EOT
  }
}