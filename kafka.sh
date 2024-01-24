#!/bin/bash

# Vérifier si git est installé
if ! command -v git &> /dev/null; then
  sudo apt-get install -y git
fi

# Vérifier si le démon Docker est en cours d'exécution
if ! sudo systemctl is-active --quiet docker; then
  echo "Docker n'est pas en cours d'exécution. Veuillez démarrer Docker avant d'exécuter ce script."
  exit 1
fi

# Vérifier et installer les paquets requis
paquets=("python3" "python3-pip" "docker" "docker-compose")
for paquet in "${paquets[@]}"; do
  if ! dpkg -l | grep -q "$paquet"; then
    sudo apt-get install -y "$paquet"
  else
    echo "Le paquet '$paquet' est déjà installé"
  fi
done

# Vérifier et installer le paquet kafka-python
if ! pip3 show kafka-python > /dev/null; then
  sudo pip3 install kafka-python
else
  echo "Le paquet 'kafka-python' est déjà installé"
fi

# Cloner le dépôt kafka-docker
if [ -d "kafka-docker" ]; then
  sudo rm -rf kafka-docker
fi

sudo git clone https://github.com/wurstmeister/kafka-docker.git

cd kafka-docker/

# Créer le fichier Docker Compose YAML
nom_fichier="docker-compose-expose.yml"
cat << EOF > $nom_fichier
version: '2'

services:
  zookeeper:
    image: wurstmeister/zookeeper:3.4.6
    ports:
      - "2181:2181"

  kafka:
    build: .
    ports:
      - "9092:9092"
    expose:
      - "9093"
    environment:
      KAFKA_ADVERTISED_LISTENERS: INSIDE://kafka:9093,OUTSIDE://localhost:9092
      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: INSIDE:PLAINTEXT,OUTSIDE:PLAINTEXT
      KAFKA_LISTENERS: INSIDE://0.0.0.0:9093,OUTSIDE://0.0.0.0:9092
      KAFKA_INTER_BROKER_LISTENER_NAME: INSIDE
      KAFKA_ZOOKEEPER_CONNECT: zookeeper:2181
      KAFKA_CREATE_TOPICS: "topic_test:1:1"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
EOF

echo "Le fichier YAML $nom_fichier a été créé."

# Démarrer Kafka en utilisant Docker Compose
sudo docker-compose -f docker-compose-expose.yml up
