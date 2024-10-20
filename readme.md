# Boilerplate for deploying any docker application with PostgresSQL and nginx with Let’s Encrypt

`install.sh` script automates the setup of a Docker-based web application with a PostgreSQL database. It checks and installs dependencies like curl, docker, and docker-compose, ensures there’s no existing database volume, and modifies configuration files (config.toml, .env). It then initializes Nginx with SSL, starts the Docker containers for the app and database, and verifies if they’re running successfully, providing feedback on the setup status.

`init-letsencrypt.sh` automates obtaining an SSL certificate from Let’s Encrypt using Certbot in a Docker environment. It loads AWS credentials, sets up TLS configurations, creates a temporary certificate for Nginx, requests the real certificate using either the webroot or dns-route53 method, and reloads Nginx to apply the certificate.

## Features

- Automatically downloads recommended TLS configuration files for Nginx.
- Requests an SSL certificate from Let’s Encrypt using the Certbot client.
- Supports certificate validation via webroot or AWS dns-route53.
- Reloads Nginx to apply the new SSL certificate.

## Installation

1. Clone this repository: `git clone https://github.com/maniSHarma7575/docker-deployment.git`

2. Create a .env file with your AWS credentials if using the dns-route53 method:

        
        AWS_ACCESS_KEY_ID=your-access-key
        AWS_SECRET_ACCESS_KEY=your-secret-key
        

3. Modify configuration:
- Add domains and email addresses to init-letsencrypt.sh
- Replace all occurrences of example.com with primary domain (the first one you added to init-letsencrypt.sh) in data/nginx/nginx.conf

4. Run the init script:

        ./install.sh

## License
All code in this repository is licensed under the terms of the `MIT License`. For further information please refer to the `LICENSE` file.
