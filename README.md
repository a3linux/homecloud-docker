homecloud-docker
=========================
A HomeCloud service stack uses docker-compose,  deploy home cloud service(s) quickly.
This small project is directly from the thread [here](https://www.reddit.com/r/selfhosted/comments/103tbd3/comment/j95zp9b/?utm_source=share&utm_medium=web2x&context=3 )

## Services include

* Authentik
* NextCloud
* Database(MariaDB, Postgres and Redis)
* Imaginary
* ElasticSearch
* Collabora
* ClamAV(disabled by default)
* Nextcloud talk(disabled by default)

## Background and design

I have my home cloud services(primary is Nextcloud) hosted on an Ubuntu box when I plan to migrate to docker based services, I found a lot of solutions, including Nextcloud All-in-one. But according to the situation, not all of them match my requirements. For example, I have so much history data, more than 15 years family data, always kept in multiple copies in HDD, multiple disks hold same data copies. And they are mounted to the Ubuntu server through USB and Network. Then I found it is not easy for me to migrate data or smooth boot docker based services with a new home server box.

After some quick researching, I start this small and quiet simple project, help to resolve the issue, dockerizing core services such as Nextcloud, authentication service with local file volumes. At the same time keep very simple base OS maintenance files and basic services. So that I have things here, 

* Docker server as computing node _ONLY_ and de-attached from the data, the node can be replaced at any time if broken
* Base OS(Ubuntu run on the node) as the housekeeper, takes over the disk management, files backup, network/firewall and Docker platform
* All data keep in HDD with multiple copies as usually, no data dump or export / import to Docker containers, my disks remained in external USB box or small NAS servers

For the above reason, I also have another small project, [homecloud-baseos](https://github.com/a3linux/homecloud-baseos)

### Deployment diagram

![homecloud deploy diagram](docs/homecloud-docker-diagram.drawio.png)

## Preparation and requirements

**First of all, please clone this git repository to the machine**

### Requirements

Before start, please confirm the OS environment has essential parts, 

* Recommend hardware >2.0GHz multiple cores CPU and >8GB memory
* Ubuntu 22.04 LTS server
* Docker-ce

And you might need,

* DNS Names, at least you need two, one for primary service as Nextcloud, the other for Authentication service(Authentik), e.g www.example.com and auth.example.com

* Multiple volumes or paths to mount with Docker, at least you need 4
    1. SERVICE_DESTINATION - Service destination, the homecloud service files will store there, recommend to keep in OS SSD disk
    2. APPS_BASE - Application data volumes, recommend to keep in OS SSD disk
    3. DATA_BASE - User data, recommend to keep in HDD, this is the volume what Nextcloud used for service user files storage
    4. VAULT_BASE - Vault, a folder to host docker secret files, recommend to keep in OS SSD

For other HDD volumes, if you have, like me, used as backup, please feel free to mount or use them in base OS, docker services will NOT touch them.
For the data stores in base OS SSD disk, please keep them backup regularly.


### Preparation the Base OS

Install Ubuntu Server (>= 22.04), run the setup script,

```
$ bin/setup.ubuntu.sh
```

### HTTPS certificates and acme.sh

**If free HTTPS certificate**, if you have commercial certificates, please ignore this.

acme.sh for free SSL certificate request and renew, keep it in base OS might be easy then in Docker and keep it out of scope the docker chain can make the docker chain more clean and easy for local development and debug.

For production deployment, acme.sh is as an option to obtain HTTPS certificates. There are also other popular solutions such as Letsencrypt.

There are two ways to enable acme.sh SSL certificate for [homecloud-docker](https://github.com/a3linux/homecloud-docker) based deployment.

1. Use self signed certificate to bootstrap or local development deployment

*bin/create_selfsigned_crt.sh* can be used to generate such certificates. The script generates *DNS_NAME*.crt and *DNS_NAME*.key in the current folder according to the input *-n DNS_NAME*, also you can give more DNS ALIAS with -a.

```
$ bin/create_selfsigned_crt.sh -n sample.com -a auth.sample.com,office.sample.com 
```
will create sample.com.crt as the certificate and sample.com.key as the private key.

After setup the deployment with self-signed certificates, you can use acme.sh to get real certificate and replace the self-signed one

2. Use acme.sh standalone mode to get the SSL certificate first, then set up the homecloud-docker configuration to kick start

#### Install acme.sh and config

```
curl https://get.acme.sh | sh -s email=my@example.com
```

More on [acme.sh document](https://github.com/acmesh-official/acme.sh/wiki/How-to-install)

Setup default CA, 

```
acme.sh --set-default-ca --server zerossl
acme.sh --set-default-ca --server letsencrypt
```

Register account for ZeroSSL(EAB),

```
acme.sh --register-account  --server zerossl \
        --eab-kid <EAB-KEY-ID> \
        --eab-hmac-key <EAB-KEY-HMAC>
```

#### Issue SSL certificate by acme.sh

Very basic issue command, 

```
acme.sh --issue -d domain.com -w ${APPS_BASE}/lb/webroot
```

${APPS_BASE}/lb/webroot is based on the homecloud.<env> file, APPS_BASE and assume the homecloud service already up.

acme.sh supports so many different modes to issue certificate. Go to [Here](https://github.com/acmesh-official/acme.sh) for more details.


## HomeCloud docker compose service quick start

### Initialize the service

* BaseOS installed and setup
* Config the deployment config file, copy the _homecloud.env_ to homecloud.dev or homecloud.prod and put into folder according to your OS environment, e.g. <some_path>/homecloud.dev
* Run ./sync_deployment.sh -c <some_path>/homecloud.<env>, here env is dev or prod you copied above
* Go to service folder to start the service with <some_path>/bin/start.dbonly.sh 
* Create databases by run <some_apth>/bin/create_databases.sh
* Stop the service with <some_path>/bin/stop.dbonly.sh
* Start the service with <some_path>/bin/start.sh and waiting for all service up

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

