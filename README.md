# IRUO – OpenStack CLI Deployment (TechSprint Moodle okolina)

OpenStack dio IRUO projekta (Red Hat OpenStack Platform 16.1 – Train release).
Automatizirani deployment putem Bash skripte i OpenStack CLI-ja iz CSV datoteke
s popisom korisnika: bastion/jump host, izolirane mreže po developeru,
2 Moodle VM instance po developeru, Cinder data volumeni, security grupe
i Keystone IAM (projekti, korisnici, role).

> Pokreće se **s controller0 noda** unutar Red Hat Academy CL110 laba,
> jer je OpenStack API dostupan samo unutar lab okruženja.

## Arhitektura

| Komponenta | Detalji |
|---|---|
| **Compute** | 6 VM-ova: 1 bastion, 1 lead, 4 Moodle (2 po developeru) |
| **Network** | production-network1 + izolirane vnet-* mreže po developeru |
| **Storage** | 4× Cinder volume (10 GB), attached na Moodle VM-ove |
| **Security** | sg-bastion (SSH), sg-developer (HTTP/HTTPS/SSH), sg-lead (full) |
| **IAM** | Keystone projekt `techsprint`, 3 korisnika (1 lead + 2 dev) |
| **Image** | octavia-amphora-16.1-20200812.3.x86_64 |
| **Flavors** | default (2vCPU/2GB/10GB), default-extra-disk (+5GB ephemeral) |

## Preduvjeti

- Red Hat Academy CL110 lab okruženje (RHOSP 16.1)
- Pristup controller0 konzoli
- OpenStack kredencijali (`/home/heat-admin/overcloudrc`)

## Pokretanje

```bash
# Na controller0
source /home/heat-admin/overcloudrc

# Kloniranje repozitorija
cd /tmp
git clone https://github.com/marin2139/techsprint-openstack.git
cd techsprint-openstack

# Deploy
chmod +x deploy.sh cleanup.sh
./deploy.sh techsprint_users.csv
```

## Čišćenje

```bash
./cleanup.sh
```

Briše sve TechSprint resurse (VM-ove, volumene, mreže, security grupe,
Keystone korisnike i projekt) i vraća lab u čisto stanje.

## Struktura repozitorija

```
├── deploy.sh                 # Glavna deployment skripta
├── cleanup.sh                # Skripta za brisanje svih resursa
├── techsprint_users.csv      # CSV s korisnicima (ime;prezime;uloga)
└── README.md
```

## CSV format

```csv
ime;prezime;uloga
Ana;Anic;devops_lead
Luka;Lukic;developer
Marko;Marinkovic;developer
```

## Napomena

Deployment koristi OpenStack CLI umjesto Terraforma zbog ograničenja
Red Hat Academy lab okruženja (nestabilnost Neutron API-ja pri paralelnim
Terraform pozivima). Bash skripta izvršava pozive sekvencijalno što je
pouzdanije za ovaj tip laba.

Kredencijali se učitavaju iz `overcloudrc` fajla i ne idu na GitHub.
