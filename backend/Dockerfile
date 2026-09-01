# Utilisation d'une image Node.js LTS légère sur Alpine
FROM node:18-alpine

# Définition du répertoire de travail dans le conteneur
WORKDIR /app

# Copie des fichiers de gestion des dépendances
COPY package*.json ./

# Installation des dépendances du projet
RUN npm install

# Copie du reste du code source
COPY . .

# Exposition du port applicatif
EXPOSE 3000

# Commande de lancement en mode développement (avec nodemon pour le live-reload)
CMD ["npm", "run", "dev"]