#!/bin/bash
# ============================================================
#  [리소스그룹A] Bootstrap 스크립트
#
#  생성 리소스 (team604tuna-infra):
#    ├── Storage Account  ← tfstate 백엔드
#    └── Key Vault        ← 시크릿 6개 저장
#
#  실행 전 환경변수 설정 필요:
#    export SUBSCRIPTION_ID="구독ID"
#
#  실행 후 검증:
#    az keyvault secret list --vault-name tuna-keyvault-604 -o table
# ============================================================

set -e

# ────────────────────────────────────────────────────────────
#  사전 검증
# ────────────────────────────────────────────────────────────
if [[ -z "$SUBSCRIPTION_ID" ]]; then
  echo "❌ SUBSCRIPTION_ID 환경변수를 설정하세요."
  echo "   export SUBSCRIPTION_ID=\"구독ID\""
  exit 1
fi

# ────────────────────────────────────────────────────────────
#  설정값
# ────────────────────────────────────────────────────────────
LOCATION="KoreaCentral"
INFRA_RG="team604tuna-infra"
STORAGE_ACCOUNT="tunatfstate604"
CONTAINER_NAME="tfstate"
KEY_VAULT_NAME="tuna-keyvault-604"

# ────────────────────────────────────────────────────────────
#  시크릿 값
# ────────────────────────────────────────────────────────────
DB_NAME="tuna_db"
DB_USER="tuna"
DB_PASSWORD="It12345@"
VPN_KEY="TunaVPN@1234!"
ONPREM_VPN_IP="1.220.76.5"
ONPREM_DB_IP="2.2.2.4"

# ────────────────────────────────────────────────────────────
#  구독 확인
# ────────────────────────────────────────────────────────────
echo "==> 구독 설정 확인..."
az account set --subscription "$SUBSCRIPTION_ID"

TENANT_ID=$(az account show --query tenantId -o tsv)
CURRENT_USER_ID=$(az ad signed-in-user show --query id -o tsv 2>/dev/null \
                  || az account show --query id -o tsv)

echo "  구독 ID  : $SUBSCRIPTION_ID"
echo "  테넌트   : $TENANT_ID"
echo "  실행 주체: $CURRENT_USER_ID"

# ────────────────────────────────────────────────────────────
#  1. 리소스그룹A 생성
# ────────────────────────────────────────────────────────────
echo ""
echo "── [1/5] 리소스그룹A 생성 ──────────────────────────────"

az group create \
  --name "$INFRA_RG" \
  --location "$LOCATION" \
  --output none
echo "  ✔ $INFRA_RG"

# ────────────────────────────────────────────────────────────
#  2. Storage Account + Container
# ────────────────────────────────────────────────────────────
echo ""
echo "── [2/5] Storage Account 생성 ─────────────────────────"

if az storage account show --name "$STORAGE_ACCOUNT" --resource-group "$INFRA_RG" &>/dev/null; then
  echo "  ℹ️  Storage Account 이미 존재, 생성 스킵"
else
  az storage account create \
    --name "$STORAGE_ACCOUNT" \
    --resource-group "$INFRA_RG" \
    --location "$LOCATION" \
    --sku Standard_LRS \
    --kind StorageV2 \
    --https-only true \
    --min-tls-version TLS1_2 \
    --allow-blob-public-access false \
    --output none
  echo "  ✔ Storage Account: $STORAGE_ACCOUNT"
fi

az storage container create \
  --name "$CONTAINER_NAME" \
  --account-name "$STORAGE_ACCOUNT" \
  --auth-mode login \
  --output none
echo "  ✔ Container: $CONTAINER_NAME"

# ────────────────────────────────────────────────────────────
#  3. Key Vault 생성
# ────────────────────────────────────────────────────────────
echo ""
echo "── [3/5] Key Vault 생성 ────────────────────────────────"

if az keyvault show --name "$KEY_VAULT_NAME" --resource-group "$INFRA_RG" &>/dev/null; then
  echo "  ℹ️  Key Vault 이미 존재, 생성 스킵"
else
  DELETED=$(az keyvault list-deleted --query "[?name=='$KEY_VAULT_NAME'].name" -o tsv 2>/dev/null)
  if [[ -n "$DELETED" ]]; then
    echo "  ⚠️  soft-delete 상태 감지, purge 실행..."
    az keyvault purge --name "$KEY_VAULT_NAME" --location "$LOCATION" --output none
    echo "  ✔ purge 완료"
  fi

  az keyvault create \
    --name "$KEY_VAULT_NAME" \
    --resource-group "$INFRA_RG" \
    --location "$LOCATION" \
    --sku standard \
    --enable-rbac-authorization false \
    --retention-days 7 \
    --output none
  echo "  ✔ Key Vault: $KEY_VAULT_NAME"
fi

az keyvault set-policy \
  --name "$KEY_VAULT_NAME" \
  --object-id "$CURRENT_USER_ID" \
  --secret-permissions get list set delete recover \
  --output none
echo "  ✔ Access Policy 설정 완료"

# ────────────────────────────────────────────────────────────
#  4. SSH 키 생성
# ────────────────────────────────────────────────────────────
echo ""
echo "── [4/5] SSH 키 생성 ───────────────────────────────────"

SSH_KEY_FILE="$HOME/.ssh/id_rsa"

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

if [[ -f "$SSH_KEY_FILE" ]]; then
  echo "  ℹ️  SSH 키 이미 존재, 기존 키 사용"
else
  ssh-keygen -t rsa -b 4096 -f "$SSH_KEY_FILE" -N "" -q
  chmod 600 "$SSH_KEY_FILE"
  echo "  ✔ SSH 키 생성 완료 (~/.ssh/id_rsa)"
fi

if [[ -f "$HOME/.ssh/known_hosts" ]]; then
  rm -f "$HOME/.ssh/known_hosts"
  echo "  ✔ known_hosts 삭제"
fi

# ────────────────────────────────────────────────────────────
#  5. 시크릿 등록 (6개)
# ────────────────────────────────────────────────────────────
echo ""
echo "── [5/5] 시크릿 등록 ──────────────────────────────────"

az keyvault secret set --vault-name "$KEY_VAULT_NAME" --name "db-name"        --value "$DB_NAME"       --output none
echo "  ✔ db-name"
az keyvault secret set --vault-name "$KEY_VAULT_NAME" --name "db-user"        --value "$DB_USER"       --output none
echo "  ✔ db-user"
az keyvault secret set --vault-name "$KEY_VAULT_NAME" --name "db-password"    --value "$DB_PASSWORD"   --output none
echo "  ✔ db-password"
az keyvault secret set --vault-name "$KEY_VAULT_NAME" --name "vpn-shared-key" --value "$VPN_KEY"       --output none
echo "  ✔ vpn-shared-key"
az keyvault secret set --vault-name "$KEY_VAULT_NAME" --name "onprem-vpn-ip"  --value "$ONPREM_VPN_IP" --output none
echo "  ✔ onprem-vpn-ip"
az keyvault secret set --vault-name "$KEY_VAULT_NAME" --name "onprem-db-ip"   --value "$ONPREM_DB_IP"  --output none
echo "  ✔ onprem-db-ip"

# ────────────────────────────────────────────────────────────
#  완료 + 검증 안내
# ────────────────────────────────────────────────────────────
echo ""
echo "✅ Bootstrap 완료! (시크릿 6개 등록)"
echo ""
echo "  ── 검증 명령어 ─────────────────────────────────────"
echo "  az keyvault secret list --vault-name $KEY_VAULT_NAME -o table"