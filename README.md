homecloud-docker
=========================

A HomeCloud service stack uses docker-compose,  deploy home cloud service(s) quickly.
This small project is directly from the thread here, 
https://www.reddit.com/r/selfhosted/comments/103tbd3/comment/j95zp9b/?utm_source=share&utm_medium=web2x&context=3 

## Services include

* Authentik
* NextCloud
* Database(MariaDB, Postgres and Redis)
* Imaginary
* ElasticSearch
* Collabora
* ClamAV(disabled by default)
* Nextcloud talk(disabled by default)

## Background

I have my home cloud services(primary is Nextcloud) hosted on an Ubuntu box when I plan to migrate to docker based services, I found a lot of solutions, including Nextcloud All-in-one. But according to the situation, not all of them match my requirements. For example, I have so much history data, more than 15 years family data, always kept in multiple copies in HDD, multiple disks hold same data copies. And they are mounted to the Ubuntu server through USB and Network. Then I found it is not easy for me to migrate data or smooth boot docker based services with a new home server box.

After some quick researching, I start this small and quiet simple project, help to resolve the issue, dockerizing core services such as Nextcloud, authentication service with local file volumes. At the same time keep very simple base OS maintenance files and basic services. So that I have things here, 

* Docker server as computing node _ONLY_ and de-attached from the data, the node can be replaced at any time if broken
* Base OS(Ubuntu run on the node) as the housekeeper, takes over the disk management, files backup, network/firewall and Docker platform
* All data keep in HDD with multiple copies as usually, no data dump or export / import to Docker containers, my disks remained in external USB box or small NAS servers

For the above reason, I also have another small project, [homecloud-baseos](https://github.com/a3linux/homecloud-baseos)

### Deployment diagram

![homecloud deploy diagram](docs/homecloud-docker-diagram.drawio.png)

## How to start

### Requirement

Before start, please confirm the OS environment has essential parts, 

* Actually, you MUST have Docker-CE installed with compose, [Install Docker on ubuntu](https://docs.docker.com/engine/install/ubuntu/) might be helpful.

* DNS Names, at least you need two, one for primary service as Nextcloud, the other for Authentication service(Authentik), e.g www.example.com and auth.example.com

* Multiple volumes or paths to mount with Docker, at least you need 4
    1. SERVICE_DESTINATION - Service destination, the homecloud service files will store there, recommend to keep in OS SSD disk
    2. APPS_BASE - Application data volumes, recommend to keep in OS SSD disk
    3. DATA_BASE - User data, recommend to keep in HDD, this is the volume what Nextcloud used for service user files storage
    4. VAULT_BASE - Vault, a folder to host docker secret files, recommend to keep in OS SSD

For other HDD volumes, if you have, like me, used as backup, please feel free to mount or use them in base OS, docker services will NOT touch them.
For the data stores in base OS SSD disk, please keep them backup regularly.

* You will need HTTPS certificate files either self signed one for testing or Letsencrypt any other one. I did not integrate this part into docker as I found there are multiple services now, ACME supports at least two free services, at the same time, lot of people, like myself, still use traditional certbot with let'sencrypt.

### Quick start

* BaseOS installed and setup
* Clone this repository
* Config the deployment config file, copy the _homecloud.env_ to homecloud.dev or homecloud.prod and put into folder according to your OS environment, e.g. <some_path>/homecloud.dev
* Run ./sync_deployment.sh -c <some_path>/homecloud.<env>, here env is dev or prod you copied above
* Go to service folder to start the service with <some_path>/bin/start.dbonly.sh 
* Create databases by run <some_apth>/bin/create_databases.sh
* Stop the service with <some_path>/bin/stop.dbonly.sh
* Start the service with <some_path>/bin/start.sh and waiting for all service up
* First time setup

### Setup services

#### Authentik

Go to Authentik URL https://<AUTHENTIK_SERVER_NAME>/if/flow/initial-setup/, Authentik domain name should be the one in _homecloud_.<env>, setup the akadmin user.
Start to use Authentik if everything is fine.

#### Nextcloud

Login into Nextcloud by URL https://<PRIMARY_SERVER_NAME>/.

##### Well known issue about Nextcloud App Store json load issue

WARN message in Nextcloud Administration -> Logging, 

 ```
     Could not connect to appstore: cURL error 28: Operation timed out after 60000 milliseconds with 421888 bytes received (see https://curl.haxx.se/libcurl/c/libcurl-errors.html) for https://apps.nextcloud.com/api/v1/apps.json
 ```

 Root cause of timeout, Nextcloud source code, lib/private/App/AppStore/Fetcher/Fetcher.php, line 103, $timeout => 60. I did not get reasonable solution for this. Just waiting for a while and lucky to have it.

If your Nextcloud App Store is fine, then the script *config_nextcloud.sh* can be used for more Nextcloud configurations, including the Nextcloud Office(Collabora), Fulltextsearch and so forth. Use -h with the script to check more details. Anyway, all those settings can be done on Nextcloud management console too.

#### Nextcloud SSO by Authentik

There are good reference online for this part, 

* [Complete Guide from Jack](https://blog.cubieserver.de/2022/complete-guide-to-nextcloud-saml-authentication-with-authentik/) 
* [Another guide](https://geekscircuit.com/nextcloud-saml-authentication-with-athentik/).

