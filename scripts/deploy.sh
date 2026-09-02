#!/usr/bin/env bash
# ==============================================================================
# SCRIPT DE DÉPLOIEMENT TERRAFORM VERS LOCALSTACK
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TERRAFORM_DIR="$PROJECT_ROOT/terraform"

echo "================================================================="
echo " 🚀 DÉPLOIEMENT DE L'INFRASTRUCTURE E-COMMERCE VERS LOCALSTACK"
echo "================================================================="

# 1. Vérification de la disponibilité de LocalStack
LOCALSTACK_URL="${LOCALSTACK_ENDPOINT:-http://localhost:4566}"
echo -n "👉 Vérification de LocalStack sur $LOCALSTACK_URL... "
if curl -s "$LOCALSTACK_URL/_localstack/health" > /dev/null; then
    echo "✅ En ligne et fonctionnel !"
else
    echo "❌ LocalStack n'est pas accessible."
    echo "Veuillez démarrer LocalStack via votre conteneur localstack-aws ou 'docker compose up -d localstack'."
    exit 1
fi

# 2. Initialisation Terraform
echo ""
echo "👉 Initialisation de Terraform..."
export TF_CLI_CONFIG_FILE="/dev/null"
terraform -chdir="$TERRAFORM_DIR" init -input=false

# 3. Validation de la syntaxe
echo ""
echo "👉 Validation de la configuration..."
terraform -chdir="$TERRAFORM_DIR" validate

# 4. Application du plan
echo ""
echo "👉 Application des ressources AWS sur LocalStack..."
terraform -chdir="$TERRAFORM_DIR" apply -auto-approve -input=false

echo ""
echo "================================================================="
echo " 🎉 INFRASTRUCTURE TERRAFORM DÉPLOYÉE AVEC SUCCÈS SUR LOCALSTACK !"
echo "================================================================="
terraform -chdir="$TERRAFORM_DIR" output

