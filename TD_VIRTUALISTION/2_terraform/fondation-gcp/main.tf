// Initialisation du provider Google
provider "google" {
    project = "esirem"
    region  = "europe-west9"
}

// Creation de la ressource VPC
resource "google_compute_network" "my_vpc" {
  name                    = "my-vpc"
  auto_create_subnetworks = false  # Désactive la création automatique des sous-réseaux pour une gestion plus fine
}

//Ajout  d_une instance Compute Engine dans ce VPC (google_compute_instance)
resource "google_compute_subnetwork" "my_subnet" {
  name          = "my-subnet"
  ip_cidr_range = "10.0.1.0/24"
  region        = "europe-west9"
  network       = google_compute_network.my_vpc.name
}

resource "google_compute_instance" "my_instance" {
  count        = 3  # Meta-argument pour haute disponibilité , count = 3 : C'est un meta-argument qui permet de créer plusieurs instances pour améliorer la disponibilité.
  name         = "my-instance-${count.index}"
  machine_type = "e2-medium"
  zone         = "eu-west-a"

  //La base de données est liée au réseau VPC via private_network.

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-9"
    }
  }

  network_interface {
    network    = google_compute_network.my_vpc.name
    subnetwork = google_compute_subnetwork.my_subnet.name
    access_config {
      // Éphémère IP pour accès Internet
    }
  }

  tags = ["http-server", "https-server"]
}

//  Ajout d_une base de données dans ce VPC (google_sql_database_instance)
resource "google_sql_database_instance" "my_sql_instance" {
  name             = "my-sql-instance"
  database_version = "POSTGRES_12"
  region           = "us-central1"

  settings {
    tier = "db-f1-micro"  # Type d'instance pour la base de données
    ip_configuration {
      ipv4_enabled    = true
      private_network = google_compute_network.my_vpc.self_link  # Relie la base de données au réseau VPC
    }
  }
}
// Explication :google_sql_database_instance : Crée une instance de base de données SQL, ici PostgreSQL 12.La base de données est liée au réseau VPC via private_network.

//  Ajouter une entrée DNS (google_dns_record_set)
resource "google_dns_managed_zone" "my_dns_zone" {
  name     = "my-dns-zone"
  dns_name = "example.com."
}

resource "google_dns_record_set" "my_a_record" {
  name         = "www.example.com."
  managed_zone = google_dns_managed_zone.my_dns_zone.name
  type         = "A"
  ttl          = 300
  rrdatas      = [google_compute_instance.my_instance[0].network_interface[0].access_config[0].nat_ip]
}
// Explication :google_dns_managed_zone : Crée une zone DNS gérée pour votre domaine.google_dns_record_set : Crée un enregistrement DNS de type A, pointant vers l'adresse IP publique de votre instance.

//Configurer la haute disponibilité avec un meta-argument:
// count        = 3  # Meta-argument pour haute disponibilité
//name         = "my-instance-${count.index}"
// Ce bloc permet de créer 3 instances de Compute Engine, chacune ayant un nom unique. Le premier chiffre de la haute disponibilité est atteint avec cette approche.