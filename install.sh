#!/bin/bash

printf '\n'

RED="$(tput setaf 1 2>/dev/null || printf '')"
BLUE="$(tput setaf 4 2>/dev/null || printf '')"
GREEN="$(tput setaf 2 2>/dev/null || printf '')"
NO_COLOR="$(tput sgr0 2>/dev/null || printf '')"

info() {
  printf '%s\n' "${BLUE}> ${NO_COLOR} $*"
}

error() {
  printf '%s\n' "${RED}x $*${NO_COLOR}" >&2
}

completed() {
  printf '%s\n' "${GREEN}✓ ${NO_COLOR} $*"
}

exists() {
  command -v "$1" 1>/dev/null 2>&1
}

check_dependencies() {
	if ! exists curl; then
		error "curl is not installed."
		exit 1
	fi

	if exists docker;
    then
        echo "Docker is already installed"
    else
        echo "Installing docker"
        sudo apt update
        sudo apt install apt-transport-https ca-certificates curl software-properties-common
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
        sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu jammy stable"
        sudo apt update
        sudo apt install docker-ce
        sudo chmod 666 /var/run/docker.sock
        sudo systemctl status docker
	fi

	if exists docker-compose;
    then
		echo "docker-compose is already installed."
    else
        echo "Installing docker compose"
				sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        docker-compose --version
	fi
}

check_existing_db_volume() {
	info "checking for an existing docker db volume"
	if docker volume inspect docker_docker-db >/dev/null 2>&1; then
		error "docker-db volume already exists. Please use docker-compose down -v to remove old volumes for a fresh setup of PostgreSQL."
		exit 1
	fi
}

download() {
	curl --fail --silent --location --output "$2" "$1"
}

is_healthy() {
	info "waiting for db container to be up. retrying in 3s"
	health_status="$(docker inspect -f "{{.State.Health.Status}}" "$1")"
	if [ "$health_status" = "healthy" ]; then
		return 0
	else
		return 1
	fi
}

is_running() {
	info "checking if "$1" is running"
	status="$(docker inspect -f "{{.State.Status}}" "$1")"
	if [ "$status" = "running" ]; then
		return 0
	else
		return 1
	fi
}

generate_password(){
	echo $(LC_ALL=C tr -dc A-Za-z0-9 </dev/urandom | head -c 13 ; echo '')
}

get_config() {
	info "Copying config.toml.sample to config.toml"
	cp config.toml.sample config.toml

	info "Copying .env.example to .env"

	cp .env.example .env
}

modify_config(){

	info "modifying config.toml"
	read -sp 'Enter database Password: ' password
	db_password=$password
	# Replace `db.host=localhost` with `db.host=db` in config file.
	sed -i "s/host = \"localhost\"/host = \"docker_db\"/g" config.toml
	# Replace `db.password=docker` with `db.password={{db_password}}` in config file.
	# Note that `password` is wrapped with `\b`. This ensures that `admin_password` doesn't match this pattern instead.
	sed -i "s/\bpassword\b = \"docker\"/password = \"$db_password\"/g" config.toml
	# Replace `app.address=localhost:9000` with `app.address=0.0.0.0:9000` in config file.
	sed -i "s/address = \"localhost:9000\"/address = \"0.0.0.0:8080\"/g" config.toml

  # Replace the application level configuration here
	# read -sp 'Enter admin username:' admin_username
	# read -sp 'Enter admin password:' admin_password
	# sed -i "s/admin_username = \"docker\"/admin_username = \"$admin_username\"/g" config.toml
	# sed -i "s/admin_password = \"docker\"/admin_password = \"$admin_password\"/g" config.toml

	info "modifying docker-compose.yml"
	sed -i "s/POSTGRES_PASSWORD=docker/POSTGRES_PASSWORD=$db_password/g" docker-compose.yml
}

start_nginx(){
	./init-letsencrypt.sh
}

start_services(){
	info "starting app"
	docker-compose up -d app db
}

show_output(){
	info "finishing setup"
	sleep 3

	if is_running docker_db && is_running docker_app
	then completed " is now up and running. Visit https://example.com in your browser."
	else
		error "error running containers. something went wrong."
	fi
}


check_dependencies
check_existing_db_volume
get_config
modify_config
start_nginx
start_services
show_output