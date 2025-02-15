#!/bin/bash
domains=(example.com)
rsa_key_size=4096
data_path="./data/certbot"
email="<@youremail.com>" # Adding a valid address is strongly recommended
staging=0 # Set to 1 if you're testing your setup to avoid hitting request limits
method="webroot" # Method argument: either 'webroot' or 'dns-route53'

# Load environment variables from .env file
if [ -f .env ]; then
  export $(cat .env | xargs)
else
  echo ".env file not found. Please create it with the required AWS credentials."
  exit 1
fi

if [ -d "$data_path" ]; then
  read -p "Existing data found for $domains. Continue and replace existing certificate? (y/N) " decision
  if [ "$decision" != "Y" ] && [ "$decision" != "y" ]; then
    exit
  fi
fi

if [ ! -e "$data_path/conf/options-ssl-nginx.conf" ] || [ ! -e "$data_path/conf/ssl-dhparams.pem" ]; then
  echo "### Downloading recommended TLS parameters ..."
  mkdir -p "$data_path/conf"
  curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf > "$data_path/conf/options-ssl-nginx.conf"
  curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot/certbot/ssl-dhparams.pem > "$data_path/conf/ssl-dhparams.pem"
  echo
fi

echo "### Creating dummy certificate for $domains ..."
path="/etc/letsencrypt/live/$domains"
mkdir -p "$data_path/conf/live/$domains"
docker-compose run --rm --entrypoint "\
  openssl req -x509 -nodes -newkey rsa:$rsa_key_size -days 1\
    -keyout '$path/privkey.pem' \
    -out '$path/fullchain.pem' \
    -subj '/CN=localhost'" certbot
echo

echo "### Starting nginx ..."
docker-compose up --force-recreate -d nginx
echo

echo "### Deleting dummy certificate for $domains ..."
docker-compose run --rm --entrypoint "\
  rm -Rf /etc/letsencrypt/live/$domains && \
  rm -Rf /etc/letsencrypt/archive/$domains && \
  rm -Rf /etc/letsencrypt/renewal/$domains.conf" certbot
echo

request_cert() {
  echo "### Requesting Let's Encrypt certificate for $domains ..."

  # Join $domains to -d args
  domain_args=""
  for domain in "${domains[@]}"; do
    domain_args="$domain_args -d $domain"
  done

  # Select appropriate email arg
  case "$email" in
    "") email_arg="--register-unsafely-without-email" ;;
    *) email_arg="--email $email" ;;
  esac

  # Enable staging mode if needed
  if [ $staging != "0" ]; then staging_arg="--staging"; fi

  echo "Printing the inputs required for certbot"
  echo $email_arg
  echo $email
  echo $rsa_key_size
  if [ "$method" == "webroot" ]; then
    # Run Certbot with webroot method
    docker-compose run --rm --entrypoint "\
      certbot certonly --webroot -w /var/www/certbot \
      $staging_arg \
      $email_arg \
      $domain_args \
      --rsa-key-size $rsa_key_size \
      --agree-tos \
      --force-renewal" certbot
  elif [ "$method" == "dns-route53" ]; then
    # Run Certbot with DNS Route 53 method
    docker run -it --name certbot \
      -v "/etc/letsencrypt:/etc/letsencrypt" \
      -v "/var/lib/letsencrypt:/var/lib/letsencrypt" \
      -e AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID" \
      -e AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY" \
      certbot/dns-route53 certonly -n --agree-tos \
      $email_arg \
      --dns-route53 \
      --server "https://acme-v02.api.letsencrypt.org/directory" \
      $domain_args \
      $staging_arg \
      --force-renewal
  else
    echo "Invalid method specified. Use 'webroot' or 'dns-route53'."
    exit 1
  fi
}

# Call the function to request the certificate
request_cert

echo "### Reloading nginx ..."
docker-compose exec nginx nginx -s reload
