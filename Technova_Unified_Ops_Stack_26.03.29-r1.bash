#!/bin/bash

# PT-BR
# Script Criado por André Rodrigues - (andre.lr@outlook.com / technova.sti@outlook.com)
# na versão 26.03.29-r1 para instalação automatizada do GLPI 11.0.x, Zabbix 7.4.x,
# Grafana 12.x e Graylog 7.0.x em suas últimas versões estáveis no momento de sua execução
# em ambientes Oracle Linux 9.x, RHEL 9.x ou Rocky Linux 9.x.
# Mensagens amigáveis durante sua execução com suporte a Português brasileiro, Inglês e Espanhol.
# 
# Script homologado em ambientes virtualizados com VMware® Workstation 17 Pro 17.5.2 build-23775571
# e Proxmox Virtual Environment 9.1.6.
#  
# Uso: executar como root (ou com sudo).
##------------------------------------------------------------------------
# ENG
# Script Created by André Rodrigues - (andre.lr@outlook.com / technova.sti@outlook.com)
# in version 26.03.29-r1 for automated installation of GLPI 11.0.x, Zabbix 7.4.x,
# Grafana 12.x and Graylog 7.0.x in their latest stable versions at the time of execution
# in Oracle Linux 9.x, RHEL 9.x or Rocky Linux 9.x environments.
# Friendly messages during execution with support for Brazilian Portuguese, English and Spanish.
#
# Script approved in virtualized environments with VMware® Workstation 17 Pro 17.5.2 build-23775571
# and Proxmox Virtual Environment 9.1.6.
#
# Usage: run as root (or with sudo).
#------------------------------------------------------------------------
# ESP
# Script creado por André Rodrigues (andre.lr@outlook.com / technova.sti@outlook.com)
# Versión 26.03.29-r1 para la instalación automatizada de GLPI 11.0.x, Zabbix 7.4.x,
# Grafana 12.x y Graylog 7.0.x en sus últimas versiones estables al momento de la ejecución.
# En entornos Oracle Linux 9.x, RHEL 9.x o Rocky Linux 9.x.
# Mensajes amigables durante la ejecución con soporte para portugués brasileño, inglés y español.
#
# Script aprobado en entornos virtualizados con VMware® Workstation 17 Pro 17.5.2 build-23775571
# y Proxmox Virtual Environment 9.1.6.
#
# Uso: ejecutar como root (o con sudo).
# ========================================================================

set -Eeuo pipefail
START_TIME=$(date +%s)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Versão do script (para log, resumo e controle de release)
readonly SCRIPT_VERSION="26.03.29-r1"

# -------------------------------------------------------------------
# VARIÁVEIS GLOBAIS – VERSÕES CENTRAIS
# -------------------------------------------------------------------
readonly MYSQL_ROOT_PASS="Root@1234"

# GLPI fallback (caso a detecção automática falhe)
readonly GLPI_VERSION="10.0.18"
# Versão efetivamente usada (atualizada após detecção automática)
GLPI_VERSION_USED="$GLPI_VERSION"
GLPI_MAJOR=10

# Linha do Zabbix utilizada (repo oficial 7.4.x)
readonly ZABBIX_VERSION="7.4"

# Versão alvo do PHP (stream Remi)
readonly PHP_TARGET_VERSION="8.3"                # Usado nas mensagens
readonly PHP_STREAM="remi-${PHP_TARGET_VERSION}" # Usado no módulo dnf

# MariaDB – usar repositório oficial na série 12.0.x
readonly MARIADB_SERIES="12.0"   # série suportada pelo Zabbix 7.4
readonly MARIADB_REPO_SETUP_URL="https://r.mariadb.com/downloads/mariadb_repo_setup"
readonly MARIADB_PKG="MariaDB-server"     # pacote do repo oficial MariaDB

# Senha admin do Grafana – versão será detectada depois da instalação
readonly GRAFANA_ADMIN_PASS="Grafana@1234"
GRAFANA_VERSION="latest"   # será sobrescrita com a versão real detectada

# Graylog / OpenSearch / MongoDB
readonly GRAYLOG_SERIES="7.0"
readonly GRAYLOG_REPO_RPM="https://packages.graylog2.org/repo/packages/graylog-${GRAYLOG_SERIES}-repository_latest.rpm"
readonly MONGODB_SERIES="8.0"
readonly OPENSEARCH_REPO_URL="https://artifacts.opensearch.org/releases/bundle/opensearch/2.x/opensearch-2.x.repo"
GRAYLOG_VERSION="${GRAYLOG_SERIES}"
GRAYLOG_LATEST_VERSION="${GRAYLOG_SERIES}"
readonly GRAYLOG_ADMIN_PASS_DEFAULT="Graylog@1234"
GRAYLOG_ADMIN_PASS="${GRAYLOG_ADMIN_PASS_DEFAULT}"
GRAYLOG_ADMIN_PASS_FILE="/tmp/graylog_admin_password.txt"
OPENSEARCH_INITIAL_ADMIN_PASSWORD=""
OPENSEARCH_ADMIN_PASS_FILE="/tmp/opensearch_admin_password.txt"

# Integrações opcionais do Grafana (desligadas por padrão)
ENABLE_GRAFANA_OPENSEARCH_DS="${ENABLE_GRAFANA_OPENSEARCH_DS:-no}"
ENABLE_GRAFANA_GLPI_INFINITY="${ENABLE_GRAFANA_GLPI_INFINITY:-no}"

# Demais variáveis de banco/aplicações
readonly GLPI_DB="glpi"
readonly GLPI_USER="glpiuser"
readonly GLPI_PASS="Glpi@1234"
readonly ZABBIX_DB="zabbix"
readonly ZABBIX_USER="zabbix"
readonly ZABBIX_PASS="Zabbix@1234"

# -------------------------------------------------------------------
# VARIÁVEIS OPCIONAIS – CA/PROXY CORPORATIVO (RHEL)
# -------------------------------------------------------------------
# Estas variáveis podem ser exportadas no shell antes da execução do script.
# Exemplos:
#   export CORP_CA_CERT_FILE="/root/certs/proxy-ca.pem"
#   export RHSM_PROXY_HOST="proxy.empresa.local"
#   export RHSM_PROXY_PORT="8080"
#   export RHSM_PROXY_USER="usuario"        # opcional
#   export RHSM_PROXY_PASS="senha"          # opcional
#
# Alternativas para a CA:
#   CORP_CA_CERT_FILE = caminho local do certificado PEM/CRT
#   CORP_CA_CERT_B64  = conteúdo PEM/CRT em base64
#   CORP_CA_CERT_URL  = URL interna para download do certificado
CORP_CA_CERT_FILE="${CORP_CA_CERT_FILE:-}"
CORP_CA_CERT_B64="${CORP_CA_CERT_B64:-}"
CORP_CA_CERT_URL="${CORP_CA_CERT_URL:-}"

RHSM_PROXY_HOST="${RHSM_PROXY_HOST:-}"
RHSM_PROXY_PORT="${RHSM_PROXY_PORT:-}"
RHSM_PROXY_USER="${RHSM_PROXY_USER:-}"
RHSM_PROXY_PASS="${RHSM_PROXY_PASS:-}"

# -------------------------------------------------------------------
# VARIÁVEIS OPCIONAIS – AUTO-STAGE DE ARQUIVOS NO DIRETÓRIO DO SCRIPT
# -------------------------------------------------------------------
# Permite que o próprio script materialize arquivos auxiliares no diretório
# onde ele está sendo executado, sem exigir cópia manual pelo usuário.
#
# Exemplos:
#   AUTO_STAGE_CA_TO_SCRIPT_DIR="yes"
#   AUTO_STAGE_CA_SOURCE_FILE="/root/certs/proxy-ca.pem"
#
#   AUTO_STAGE_ENV_TO_SCRIPT_DIR="yes"
#   AUTO_STAGE_ENV_SOURCE_FILE="/root/technova-itsm.env"
#
# Alternativamente, o conteúdo pode vir em base64:
#   AUTO_STAGE_CA_SOURCE_B64="..."
#   AUTO_STAGE_ENV_B64="..."
AUTO_STAGE_CA_TO_SCRIPT_DIR="${AUTO_STAGE_CA_TO_SCRIPT_DIR:-no}"
AUTO_STAGE_CA_SOURCE_FILE="${AUTO_STAGE_CA_SOURCE_FILE:-}"
AUTO_STAGE_CA_SOURCE_B64="${AUTO_STAGE_CA_SOURCE_B64:-}"

AUTO_STAGE_ENV_TO_SCRIPT_DIR="${AUTO_STAGE_ENV_TO_SCRIPT_DIR:-no}"
AUTO_STAGE_ENV_SOURCE_FILE="${AUTO_STAGE_ENV_SOURCE_FILE:-}"
AUTO_STAGE_ENV_B64="${AUTO_STAGE_ENV_B64:-}"

# -------------------------------------------------------------------
# VARIÁVEIS OPCIONAIS – RHSM / REGISTRO RHEL
# -------------------------------------------------------------------
# Se o host RHEL já estiver registrado, estas variáveis não são necessárias.
# Em ambientes corporativos, prefira Activation Key + Org ID.
RHSM_ORG_ID="${RHSM_ORG_ID:-}"
RHSM_ACTIVATION_KEY="${RHSM_ACTIVATION_KEY:-}"

# Client de linha de comando para MariaDB/MySQL
MYSQL_BIN="mysql"

readonly INSTALL_GLPI_DIR="/var/www/html/glpi"
readonly DOMAIN="$(hostname -f)"
readonly ZABBIX_ALERTSCRIPTS_DIR="/usr/lib/zabbix/alertscripts"

# -------------------------------------------------------------------
# DETECÇÃO DO IDIOMA DO SISTEMA (SYS_LANG)
# -------------------------------------------------------------------
SYS_LANG=$(echo "${LANG:-en}" | cut -d_ -f1)
case "$SYS_LANG" in
  pt|es|en) ;;
  *) SYS_LANG="en";;
esac
case "$SYS_LANG" in
  pt) ZBX_LANG="pt_BR";;
  es) ZBX_LANG="es_ES";;
  *)  ZBX_LANG="en_GB";;
esac

# -------------------------------------------------------------------
# MENSAGENS MULTILÍNGUES PARA LOGS (PT, EN, ES)
# -------------------------------------------------------------------
declare -A MSGS_PT=(
  [step1]="1) Atualizando o sistema operacional e suas dependências..."
  [step2]="2) Configurando o SELinux como permissivo..."
  [step3]="3) Instalando o Apache, PHP ${PHP_TARGET_VERSION} e MariaDB..."
  [step4]="4) Configurando o Apache para GLPI e Zabbix..."
  [step5]="5) Ajustando o arquivo php.ini para requisitos do Zabbix..."
  [step6]="6) Inicializando o MariaDB e configurando root..."
  [step7]="7) Criando os bancos de dados para uso do GLPI e Zabbix..."
  [step8]="8) Instalando o GLPI (última versão estável detectada)..."
  [step9]="9) Instalando o Zabbix ${ZABBIX_VERSION}..."
  [step10]="10) Importando o esquema do Zabbix..."
  [step11]="11) Configurando /etc/zabbix/zabbix_server.conf..."
  [step12]="12) Configurando a interface web do Zabbix..."
  [step13]="13) Ativando os serviços do Zabbix..."
  [step14]="14) Gerando a configuração locale e configurando o Apache..."
  [step15]="15) Aplicando idioma e tema direto no banco de dados do Zabbix..."
  [step16]="16) Configurando o firewall para GLPI, Grafana, Graylog e Zabbix..."
  [step17]="17) Verificando serviço e porta 10051..."
  [step18]="18) Instalando e configurando Graylog 7.x, MongoDB 8.x e OpenSearch 2.x..."
  [step19]="19) Instalando e configurando o Grafana..."
  [step20]="20) Reiniciando os serviços instalados..."
  [step21]="21) Resumo final da instalação..."
)

declare -A MSGS_EN=(
  [step1]="1) Updating the operating system and its dependencies..."
  [step2]="2) Setting SELinux to permissive..."
  [step3]="3) Installing Apache, PHP ${PHP_TARGET_VERSION} and MariaDB..."
  [step4]="4) Configuring Apache for GLPI and Zabbix..."
  [step5]="5) Adjusting php.ini file for Zabbix requirements..."
  [step6]="6) Initializing MariaDB and configuring root..."
  [step7]="7) Creating databases for GLPI and Zabbix..."
  [step8]="8) Installing GLPI (auto-detected latest stable version)..."
  [step9]="9) Installing ZabbIX ${ZABBIX_VERSION}..."
  [step10]="10) Importing Zabbix schema..."
  [step11]="11) Configuring /etc/zabbix/zabbix_server.conf..."
  [step12]="12) Configuring Zabbix web interface..."
  [step13]="13) Activating Zabbix services..."
  [step14]="14) Generating locale configuration and configuring Apache..."
  [step15]="15) Applying language and theme directly in Zabbix database..."
  [step16]="16) Configuring firewall for GLPI, Grafana, Graylog and Zabbix..."
  [step17]="17) Checking service and port 10051..."
  [step18]="18) Installing and configuring Graylog 7.x, MongoDB 8.x and OpenSearch 2.x..."
  [step19]="19) Installing and configuring Grafana..."
  [step20]="20) Restarting installed services..."
  [step21]="21) Installation final summary..."
)

declare -A MSGS_ES=(
  [step1]="1) Actualizando el sistema operativo y sus dependencias..."
  [step2]="2) Configurando SELinux como permisivo..."
  [step3]="3) Instalando Apache, PHP ${PHP_TARGET_VERSION} y MariaDB..."
  [step4]="4) Configurando Apache para GLPI y Zabbix..."
  [step5]="5) Ajustando el archivo php.ini para requisitos de Zabbix..."
  [step6]="6) Inicializando MariaDB y configurando root..."
  [step7]="7) Creando bases de datos para GLPI y Zabbix..."
  [step8]="8) Instalando GLPI (última versión estable detectada)..."
  [step9]="9) Instalando Zabbix ${ZABBIX_VERSION}..."
  [step10]="10) Importando esquema de Zabbix..."
  [step11]="11) Configurando /etc/zabbix/zabbix_server.conf..."
  [step12]="12) Configurando la interfaz web de Zabbix..."
  [step13]="13) Activando los servicios de Zabbix..."
  [step14]="14) Generando configuración locale y configurando Apache..."
  [step15]="15) Aplicando idioma y tema directamente en la base de Zabbix..."
  [step16]="16) Configurando el firewall para GLPI, Grafana, Graylog y Zabbix..."
  [step17]="17) Verificando servicio y puerto 10051..."
  [step18]="18) Instalando y configurando Graylog 7.x, MongoDB 8.x y OpenSearch 2.x..."
  [step19]="19) Instalando y configurando Grafana..."
  [step20]="20) Reiniciando los servicios instalados..."
  [step21]="21) Resumen final de la instalación..."
)

log_step() {
  local key="$1"
  local msg
  case "$SYS_LANG" in
    pt) msg="${MSGS_PT[$key]}";;
    es) msg="${MSGS_ES[$key]}";;
    *)  msg="${MSGS_EN[$key]}";;
  esac
  echo "$(date +'%F %T') - $msg" | tee -a "$LOG"
}

# -------------------------------------------------------------------
# FUNÇÃO DE LOG
# -------------------------------------------------------------------
LOG="/var/log/install-GLPI-Zabbix-Grafana-date=$(date +%Y%m%d%H%M%S).log"
log(){
    echo "$(date +'%F %T') - $1" | tee -a "$LOG"
}

# ----------------------------------------------------------------
# Robustez: handler de erro + helpers para systemd/HTTP
# ----------------------------------------------------------------
on_error() {
  local exit_code=$?
  local line_no="${1:-?}"
  local cmd="${2:-?}"
  # Evita falhas em cascata se LOG ainda não existir
  if [[ -n "${LOG:-}" ]]; then
    echo "$(date +'%F %T') - ERRO: comando falhou (exit=${exit_code}) na linha ${line_no}: ${cmd}" | tee -a "$LOG" >&2
  else
    echo "$(date +'%F %T') - ERRO: comando falhou (exit=${exit_code}) na linha ${line_no}: ${cmd}" >&2
  fi
  exit "$exit_code"
}
trap 'on_error ${LINENO} "$BASH_COMMAND"' ERR

die() {
  log "    → ERRO: $1"
  exit 1
}

systemd_set_timeout_startsec() {
  # Uso: systemd_set_timeout_startsec "grafana-server" "5min"
  local unit="$1"
  local timeout="$2"
  local dropin_dir="/etc/systemd/system/${unit}.service.d"
  mkdir -p "$dropin_dir"
  cat > "${dropin_dir}/override.conf" <<EOF
[Service]
TimeoutStartSec=${timeout}
EOF
  systemctl daemon-reload >>"$LOG" 2>&1 || true
}

wait_for_service_active() {
  # Uso: wait_for_service_active "grafana-server" 300
  local unit="$1"
  local timeout="${2:-120}"
  local end=$((SECONDS + timeout))

  while (( SECONDS < end )); do
    if systemctl is-active --quiet "$unit"; then
      return 0
    fi
    sleep 2
  done

  systemctl status "$unit" >>"$LOG" 2>&1 || true
  journalctl -u "$unit" --no-pager -n 200 >>"$LOG" 2>&1 || true
  return 1
}

wait_for_http_ok() {
  # Uso: wait_for_http_ok "http://localhost:3000/api/health" 300
  local url="$1"
  local timeout="${2:-120}"
  local end=$((SECONDS + timeout))

  while (( SECONDS < end )); do
    if curl -fsS --max-time 5 "$url" >>"$LOG" 2>&1; then
      return 0
    fi
    sleep 2
  done
  return 1
}

set_prop_value() {
  local file="$1"
  local key="$2"
  local value="$3"
  touch "$file"
  if grep -qE "^[# ]*${key}[[:space:]]*=" "$file"; then
    sed -i "s|^[# ]*${key}[[:space:]]*=.*|${key} = ${value}|" "$file"
  else
    echo "${key} = ${value}" >> "$file"
  fi
}

detect_latest_graylog_release() {
  local detected
  detected=$(curl -fsSL https://graylog.org/releases/ 2>>"$LOG" | grep -oE 'Announcing Graylog 7\.0\.[0-9]+' | head -n1 | awk '{print $3}' || true)
  if [[ -n "$detected" ]]; then
    GRAYLOG_LATEST_VERSION="$detected"
  else
    GRAYLOG_LATEST_VERSION="$GRAYLOG_SERIES"
  fi
}

download_zabbix_release_rpm() {
  local -a candidates=("$@")
  local url
  local tmp_rpm="/tmp/zabbix-release-latest-${ZABBIX_VERSION}.el9.noarch.rpm"

  for url in "${candidates[@]}"; do
    echo "$(date +'%F %T') -     → Tentando obter o repositório do Zabbix via ${url}..." | tee -a "$LOG" >&2
    if curl -fsSL --retry 6 --retry-delay 5 --retry-all-errors "$url" -o "$tmp_rpm" >>"$LOG" 2>&1; then
      printf '%s' "$tmp_rpm"
      return 0
    fi
  done

  return 1
}

configure_opensearch_single_node() {
  local heap="1g"
  local mem_mb
  mem_mb=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
  if (( mem_mb >= 8192 )); then
    heap="2g"
  elif (( mem_mb < 2048 )); then
    heap="512m"
  fi

  cat > /etc/opensearch/opensearch.yml <<EOF
cluster.name: graylog
node.name: ${HOSTNAME}
path.data: /var/lib/opensearch
path.logs: /var/log/opensearch
discovery.type: single-node
network.host: 127.0.0.1
http.port: 9200
action.auto_create_index: false
plugins.security.disabled: true
EOF

  if [[ -f /etc/opensearch/jvm.options ]]; then
    sed -i "s/^-Xms.*/-Xms${heap}/" /etc/opensearch/jvm.options
    sed -i "s/^-Xmx.*/-Xmx${heap}/" /etc/opensearch/jvm.options
  fi

  if [[ -f /usr/lib/tmpfiles.d/opensearch.conf ]]; then
    sed -i 's|/var/run/opensearch|/run/opensearch|g' /usr/lib/tmpfiles.d/opensearch.conf
  fi

  echo 'vm.max_map_count=262144' > /etc/sysctl.d/99-opensearch.conf
  sysctl -w vm.max_map_count=262144 >>"$LOG" 2>&1 || true
  sysctl --system >>"$LOG" 2>&1 || true
}

generate_password_secret() {
  openssl rand -hex 48
}

generate_admin_password() {
  printf 'Tv@%sAa1' "$(openssl rand -hex 8)"
}

provision_grafana_optional_datasources() {
  local ds_file="/etc/grafana/provisioning/datasources/technova-optional-datasources.yaml"
  local wrote=0

  mkdir -p /etc/grafana/provisioning/datasources
  cat > "$ds_file" <<EOF
apiVersion: 1

datasources:
EOF

  if [[ "$ENABLE_GRAFANA_OPENSEARCH_DS" == "yes" ]]; then
    cat >> "$ds_file" <<EOF
  - name: DS_OPENSEARCH_GRAYLOG
    type: grafana-opensearch-datasource
    access: proxy
    url: http://127.0.0.1:9200
    jsonData:
      flavor: opensearch
      version: '2.19.0'
      timeField: timestamp
      database: graylog_*
EOF
    wrote=1
  fi

  if [[ "$ENABLE_GRAFANA_GLPI_INFINITY" == "yes" ]]; then
    cat >> "$ds_file" <<EOF
  - name: DS_GLPI_INFINITY
    type: yesoreyeram-infinity-datasource
    access: proxy
    jsonData:
      allowedHosts:
        - http://127.0.0.1
        - http://${DOMAIN}
        - http://localhost
EOF
    wrote=1
  fi

  if [[ $wrote -eq 0 ]]; then
    rm -f "$ds_file"
    return 0
  fi

  chown root:root "$ds_file"
  chmod 644 "$ds_file"
}

grafana_enable_plugin_api() {
  # Habilita/pina plugin (útil para plugins do tipo "app")
  local plugin="$1"
  local url="http://localhost:3000/api/plugins/${plugin}/settings"
  local payload='{"enabled":true,"pinned":true}'

  for _ in {1..20}; do
    if curl -fsS --max-time 10 \
        -u "admin:${GRAFANA_ADMIN_PASS}" \
        -H "Content-Type: application/json" \
        -X POST "$url" \
        -d "$payload" >>"$LOG" 2>&1; then
      return 0
    fi
    sleep 3
  done
  return 1
}


run_dnf_step1() {
  # Uso: run_dnf_step1 <0|1> <comando dnf ...>
  # 0 = comportamento normal (falha aborta o script)
  # 1 = comportamento tolerante para RHEL na etapa 1
  local tolerate_failure="${1:-0}"
  shift

  if dnf "$@" >>"$LOG" 2>&1; then
    return 0
  fi

  if [[ "$tolerate_failure" -eq 1 ]]; then
    log "    → AVISO: comando dnf falhou no RHEL durante a etapa 1. O script continuará. Verifique subscription-manager e repositórios se isso persistir."
    return 0
  fi

  return 1
}






stage_runtime_files_to_script_dir() {
  is_rhel_host || return 0

  local ca_target="${SCRIPT_DIR}/proxy-ca.pem"
  local env_target="${SCRIPT_DIR}/technova-itsm.env"

  case "${AUTO_STAGE_CA_TO_SCRIPT_DIR,,}" in
    yes|y|1|true)
      if [[ -n "$AUTO_STAGE_CA_SOURCE_FILE" ]]; then
        [[ -f "$AUTO_STAGE_CA_SOURCE_FILE" ]] || die "O arquivo definido em AUTO_STAGE_CA_SOURCE_FILE não foi encontrado: $AUTO_STAGE_CA_SOURCE_FILE"
        cp -f "$AUTO_STAGE_CA_SOURCE_FILE" "$ca_target"
        log "    → CA corporativa copiada automaticamente para ${ca_target}."
      elif [[ -n "$AUTO_STAGE_CA_SOURCE_B64" ]]; then
        echo "$AUTO_STAGE_CA_SOURCE_B64" | base64 -d > "$ca_target" || die "Não foi possível decodificar AUTO_STAGE_CA_SOURCE_B64"
        log "    → CA corporativa materializada automaticamente em ${ca_target}."
      fi
      ;;
  esac

  case "${AUTO_STAGE_ENV_TO_SCRIPT_DIR,,}" in
    yes|y|1|true)
      if [[ -n "$AUTO_STAGE_ENV_SOURCE_FILE" ]]; then
        [[ -f "$AUTO_STAGE_ENV_SOURCE_FILE" ]] || die "O arquivo definido em AUTO_STAGE_ENV_SOURCE_FILE não foi encontrado: $AUTO_STAGE_ENV_SOURCE_FILE"
        cp -f "$AUTO_STAGE_ENV_SOURCE_FILE" "$env_target"
        log "    → Arquivo de configuração copiado automaticamente para ${env_target}."
      elif [[ -n "$AUTO_STAGE_ENV_B64" ]]; then
        echo "$AUTO_STAGE_ENV_B64" | base64 -d > "$env_target" || die "Não foi possível decodificar AUTO_STAGE_ENV_B64"
        log "    → Arquivo de configuração materializado automaticamente em ${env_target}."
      fi
      ;;
  esac

  return 0
}

load_optional_runtime_config() {
  is_rhel_host || return 0

  local cfg
  for cfg in     "${SCRIPT_DIR}/technova-itsm.env"     "/root/technova-itsm.env"     "/etc/technova-itsm.env"
  do
    if [[ -f "$cfg" ]]; then
      # shellcheck disable=SC1090
      source "$cfg"
      log "    → Arquivo de configuração opcional carregado: $cfg"
      return 0
    fi
  done

  return 0
}

autodetect_corporate_ca() {
  is_rhel_host || return 0

  if [[ -n "$CORP_CA_CERT_FILE" || -n "$CORP_CA_CERT_B64" || -n "$CORP_CA_CERT_URL" ]]; then
    return 0
  fi

  local candidate
  for candidate in     "${SCRIPT_DIR}/proxy-ca.pem"     "${SCRIPT_DIR}/proxy-ca.crt"     "${SCRIPT_DIR}/corporate-ca.pem"     "${SCRIPT_DIR}/corporate-ca.crt"     "${SCRIPT_DIR}/technova-corporate-ca.pem"     "${SCRIPT_DIR}/technova-corporate-ca.crt"     "/root/proxy-ca.pem"     "/root/proxy-ca.crt"     "/root/corporate-ca.pem"     "/root/corporate-ca.crt"     "/etc/technova/proxy-ca.pem"     "/etc/technova/proxy-ca.crt"
  do
    if [[ -f "$candidate" ]]; then
      CORP_CA_CERT_FILE="$candidate"
      log "    → CA corporativa detectada automaticamente: $candidate"
      return 0
    fi
  done

  return 0
}

is_rhel_host() {
  local os_id os_name
  os_id="$(. /etc/os-release && printf '%s' "${ID:-}")"
  os_name="$(. /etc/os-release && printf '%s' "${NAME:-}")"

  [[ "$os_id" == "rhel" ]] || [[ "$os_name" == "Red Hat Enterprise Linux" ]]
}

set_ini_value() {
  local file="$1"
  local key="$2"
  local value="$3"

  touch "$file"
  if grep -qE "^${key}=" "$file"; then
    sed -i "s|^${key}=.*|${key}=${value}|" "$file"
  else
    echo "${key}=${value}" >> "$file"
  fi
}

trust_corporate_ca_if_provided() {
  is_rhel_host || return 0

  local target="/etc/pki/ca-trust/source/anchors/technova-corporate-ca.crt"

  if [[ -z "$CORP_CA_CERT_FILE" && -z "$CORP_CA_CERT_B64" && -z "$CORP_CA_CERT_URL" ]]; then
    return 0
  fi

  if [[ -n "$CORP_CA_CERT_FILE" ]]; then
    [[ -f "$CORP_CA_CERT_FILE" ]] || die "O arquivo definido em CORP_CA_CERT_FILE não foi encontrado: $CORP_CA_CERT_FILE"
    cp -f "$CORP_CA_CERT_FILE" "$target"
  elif [[ -n "$CORP_CA_CERT_B64" ]]; then
    echo "$CORP_CA_CERT_B64" | base64 -d > "$target" || die "Não foi possível decodificar CORP_CA_CERT_B64"
  else
    curl -fsSL "$CORP_CA_CERT_URL" -o "$target" >>"$LOG" 2>&1 || die "Não foi possível baixar o certificado definido em CORP_CA_CERT_URL"
  fi

  update-ca-trust >>"$LOG" 2>&1 || die "Falha ao atualizar o trust store com a CA corporativa"
  log "    → CA corporativa instalada no trust store do sistema."
}

configure_rhsm_proxy_if_provided() {
  is_rhel_host || return 0

  local dnf_conf="/etc/dnf/dnf.conf"

  if [[ -z "$RHSM_PROXY_HOST" || -z "$RHSM_PROXY_PORT" ]]; then
    return 0
  fi

  if [[ -n "$RHSM_PROXY_USER" && -n "$RHSM_PROXY_PASS" ]]; then
    subscription-manager config       --server.proxy_hostname="$RHSM_PROXY_HOST"       --server.proxy_port="$RHSM_PROXY_PORT"       --server.proxy_user="$RHSM_PROXY_USER"       --server.proxy_password="$RHSM_PROXY_PASS" >>"$LOG" 2>&1 || die "Falha ao configurar o proxy do subscription-manager"

    set_ini_value "$dnf_conf" "proxy" "http://${RHSM_PROXY_HOST}:${RHSM_PROXY_PORT}"
    set_ini_value "$dnf_conf" "proxy_username" "$RHSM_PROXY_USER"
    set_ini_value "$dnf_conf" "proxy_password" "$RHSM_PROXY_PASS"
  else
    subscription-manager config       --server.proxy_hostname="$RHSM_PROXY_HOST"       --server.proxy_port="$RHSM_PROXY_PORT" >>"$LOG" 2>&1 || die "Falha ao configurar o proxy do subscription-manager"

    set_ini_value "$dnf_conf" "proxy" "http://${RHSM_PROXY_HOST}:${RHSM_PROXY_PORT}"
  fi

  log "    → Proxy corporativo configurado para RHSM/DNF."
}

bootstrap_rhel_trust_and_proxy() {
  is_rhel_host || return 0
  stage_runtime_files_to_script_dir
  load_optional_runtime_config
  autodetect_corporate_ca
  trust_corporate_ca_if_provided
  configure_rhsm_proxy_if_provided
}


rhsm_is_registered() {
  subscription-manager identity >>"$LOG" 2>&1
}

rhsm_register_with_activation_key_if_needed() {
  is_rhel_host || return 0

  if rhsm_is_registered; then
    return 0
  fi

  if [[ -n "$RHSM_ORG_ID" && -n "$RHSM_ACTIVATION_KEY" ]]; then
    log "    → Host RHEL sem registro ativo. Tentando registrar com Org ID + Activation Key..."
    subscription-manager register --org="$RHSM_ORG_ID" --activationkey="$RHSM_ACTIVATION_KEY" --force >>"$LOG" 2>&1 ||       die "Falha ao registrar o RHEL usando RHSM_ORG_ID + RHSM_ACTIVATION_KEY"
    return 0
  fi

  die "RHEL detectado sem registro RHSM ativo e sem RHSM_ORG_ID/RHSM_ACTIVATION_KEY definidos."
}

rhsm_identity_summary() {
  subscription-manager identity 2>>"$LOG" || true
}

rhsm_repo_catalog_has_required_repos() {
  local catalog="$1"
  local base_repo="$2"
  local app_repo="$3"

  grep -q "$base_repo" <<<"$catalog" && grep -q "$app_repo" <<<"$catalog"
}

rhsm_preflight_or_die() {
  is_rhel_host || return 0

  bootstrap_rhel_trust_and_proxy
  rhsm_register_with_activation_key_if_needed

  subscription-manager refresh >>"$LOG" 2>&1 || true

  if ! rhsm_is_registered; then
    die "RHEL sem registro RHSM ativo após a tentativa de preparação."
  fi
}

prepare_rhel_repos_before_step3() {
  local distro_rhel=0
  local arch base_repo app_repo enabled_repos repo_catalog id_summary enable_rc=0

  if is_rhel_host; then
    distro_rhel=1
  fi

  [[ "$distro_rhel" -eq 1 ]] || return 0

  rhsm_preflight_or_die

  arch="$(uname -m)"
  base_repo="rhel-9-for-${arch}-baseos-rpms"
  app_repo="rhel-9-for-${arch}-appstream-rpms"

  if ! command -v subscription-manager >/dev/null 2>&1; then
    die "RHEL detectado, mas o comando subscription-manager não está disponível. Verifique a instalação e o registro do sistema antes de continuar."
  fi

  if ! repo_catalog="$(subscription-manager repos --list 2>>"$LOG")"; then
    die "Não foi possível consultar o catálogo de repositórios do RHSM no RHEL. Verifique subscription-manager, proxy e conectividade."
  fi

  if ! rhsm_repo_catalog_has_required_repos "$repo_catalog" "$base_repo" "$app_repo"; then
    id_summary="$(rhsm_identity_summary | tr '
' ' ' | sed 's/[[:space:]]\+/ /g')"
    die "RHSM registrado, porém o catálogo de repositórios não expôs ${base_repo} e ${app_repo}. O instalador não pode prosseguir. Valide org/activation key ou o mapeamento de subscrição no lado da Red Hat. Identidade atual: ${id_summary}"
  fi

  enabled_repos="$(subscription-manager repos --list-enabled 2>>"$LOG" || true)"

  if ! grep -q "${base_repo}" <<<"$enabled_repos" || ! grep -q "${app_repo}" <<<"$enabled_repos"; then
    log "    → BaseOS/AppStream ainda não aparecem como habilitados. Tentando habilitação não destrutiva no RHEL..."
    subscription-manager repos       --enable="${base_repo}"       --enable="${app_repo}" >>"$LOG" 2>&1 || enable_rc=$?

    if [[ $enable_rc -ne 0 ]]; then
      log "    → AVISO: subscription-manager retornou código ${enable_rc} ao habilitar BaseOS/AppStream. Vou validar o estado real antes de decidir."
    fi

    enabled_repos="$(subscription-manager repos --list-enabled 2>>"$LOG" || true)"
  fi

  if ! grep -q "${base_repo}" <<<"$enabled_repos"; then
    die "RHEL detectado sem o repositório obrigatório ${base_repo} habilitado após a validação do RHSM."
  fi

  if ! grep -q "${app_repo}" <<<"$enabled_repos"; then
    die "RHEL detectado sem o repositório obrigatório ${app_repo} habilitado após a validação do RHSM."
  fi

  dnf clean all >>"$LOG" 2>&1 || true

  if ! dnf makecache >>"$LOG" 2>&1; then
    die "O dnf não conseguiu recriar o cache dos repositórios do RHEL após validar BaseOS/AppStream."
  fi

  log "    → Validação RHEL concluída com sucesso: catálogo RHSM expôs BaseOS/AppStream, os repositórios ficaram habilitados e o dnf makecache foi executado."
}


# Linha inicial de contexto no log
echo "$(date +'%F %T') - Início da instalação: Technova Unified Ops Stack - versão ${SCRIPT_VERSION}" | tee -a "$LOG"
echo "$(date +'%F %T') - Componentes alvo: GLPI (auto), Zabbix ${ZABBIX_VERSION}, MariaDB ${MARIADB_SERIES}, PHP ${PHP_TARGET_VERSION}, Grafana (auto), Graylog ${GRAYLOG_SERIES}.x" | tee -a "$LOG"

# -------------------------------------------------------------------
# IDENTIDADE VISUAL / DISCLAIMER INICIAL
# -------------------------------------------------------------------
print_startup_banner() {
  local subtitle_line1 subtitle_line2 version_label

  case "$SYS_LANG" in
    pt)
      subtitle_line1="      Centralizando service desk, monitoramento, observabilidade"
      subtitle_line2="         e logs em uma única plataforma para a sua operação de TI"
      version_label="Versão"
      ;;
    es)
      subtitle_line1="      Centralizando mesa de servicio, monitoreo, observabilidad"
      subtitle_line2="         y logs en una única plataforma para su operación de TI"
      version_label="Versión"
      ;;
    *)
      subtitle_line1="      Centralizing service desk, monitoring, observability"
      subtitle_line2="         and logs in a single platform for your IT operations"
      version_label="Version"
      ;;
  esac

  [[ -t 1 ]] && clear || true

  cat <<'EOF'
████████╗███████╗ ██████╗██╗  ██╗███╗   ██╗ ██████╗ ██╗   ██╗ █████╗
╚══██╔══╝██╔════╝██╔════╝██║  ██║████╗  ██║██╔═══██╗██║   ██║██╔══██╗
   ██║   █████╗  ██║     ███████║██╔██╗ ██║██║   ██║██║   ██║███████║
   ██║   ██╔══╝  ██║     ██╔══██║██║╚██╗██║██║   ██║╚██╗ ██╔╝██╔══██║
   ██║   ███████╗╚██████╗██║  ██║██║ ╚████║╚██████╔╝ ╚████╔╝ ██║  ██║
   ╚═╝   ╚══════╝ ╚═════╝╚═╝  ╚═╝╚═╝  ╚═══╝ ╚═════╝   ╚═══╝  ╚═╝  ╚═╝
EOF
  echo
  echo "                           Unified Ops Stack"
  echo " ─────────────────────────────────────────────────────────────────────"
  echo "$subtitle_line1"
  echo "$subtitle_line2"
  echo " ─────────────────────────────────────────────────────────────────────"
  printf '                           %s %s

' "$version_label" "$SCRIPT_VERSION"
}

print_startup_disclaimer() {
  case "$SYS_LANG" in
    pt)
      cat <<EOF
Esta é a versão ${SCRIPT_VERSION} do script desenvolvido por André Rodrigues para a
instalação automatizada do GLPI 11.x.x, Zabbix 7.4.x, Grafana e Graylog 7.x.x,
em suas versões estáveis mais recentes, nos sistemas operacionais Oracle Linux 9.x,
Red Hat Enterprise Linux 9.x e Rocky Linux 9.x.

Além da instalação das plataformas, o script também realiza a aplicação de
atualizações do sistema operacional e a instalação de pré-requisitos, como
Apache, PHP e MariaDB.

Em caso de dúvidas, necessidade de suporte ou solicitação de permissões,
entre em contato pelo e-mail: technova.sti@outlook.com

Se este projeto ajudou você a implantar seu ambiente de forma prática e eficiente,
considere contribuir com qualquer valor via PIX: technova.sti@outlook.com :)

Pressione ENTER para continuar ou Ctrl+C para cancelar.
EOF
      ;;
    es)
      cat <<EOF
Esta es la versión ${SCRIPT_VERSION} del script desarrollado por André Rodrigues para la
instalación automatizada de GLPI 11.x.x, Zabbix 7.4.x, Grafana y Graylog 7.x.x,
en sus versiones estables más recientes, en los sistemas operativos Oracle Linux 9.x,
Red Hat Enterprise Linux 9.x y Rocky Linux 9.x.

Además de la instalación de las plataformas, el script también realiza la aplicación de
actualizaciones del sistema operativo y la instalación de requisitos previos, como
Apache, PHP y MariaDB.

En caso de dudas, necesidad de soporte o solicitud de permisos,
póngase en contacto por el correo electrónico: technova.sti@outlook.com

Si este proyecto le ayudó a implantar su entorno de forma práctica y eficiente,
considere contribuir con cualquier valor vía PIX: technova.sti@outlook.com :)

Presione ENTER para continuar o Ctrl+C para cancelar.
EOF
      ;;
    *)
      cat <<EOF
This is version ${SCRIPT_VERSION} of the script developed by André Rodrigues for the
automated installation of GLPI 11.x.x, Zabbix 7.4.x, Grafana and Graylog 7.x.x,
in their latest stable versions, on Oracle Linux 9.x,
Red Hat Enterprise Linux 9.x and Rocky Linux 9.x operating systems.

In addition to installing the platforms, the script also applies
operating system updates and installs prerequisites such as
Apache, PHP and MariaDB.

For questions, support needs or permission requests,
please contact: technova.sti@outlook.com

If this project helped you deploy your environment in a practical and efficient way,
please consider contributing any amount via PIX: technova.sti@outlook.com :)

Press ENTER to continue or Ctrl+C to cancel.
EOF
      ;;
  esac
}

print_startup_banner
print_startup_disclaimer
read -r
bootstrap_rhel_trust_and_proxy

# -------------------------------------------------------------------
# 1) ATUALIZAR SISTEMA E INSTALAR DEPENDÊNCIAS
# -------------------------------------------------------------------
log_step step1
distro_rhel=0
if is_rhel_host; then
  distro_rhel=1
fi

if [[ $distro_rhel -eq 1 ]]; then
  run_dnf_step1 1 update -y --skip-broken --nobest --exclude=redhat-backgrounds
  run_dnf_step1 1 clean all
  run_dnf_step1 1 makecache
  run_dnf_step1 1 install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm
  run_dnf_step1 1 install -y wget curl unzip firewalld policycoreutils-python-utils git net-snmp net-snmp-utils glibc-langpack-pt unixODBC OpenIPMI pv
else
  run_dnf_step1 0 update -y --skip-broken --nobest
  run_dnf_step1 0 clean all
  run_dnf_step1 0 makecache
  run_dnf_step1 0 install -y epel-release
  run_dnf_step1 0 install -y wget curl unzip firewalld policycoreutils-python-utils git net-snmp net-snmp-utils glibc-langpack-pt unixODBC OpenIPMI pv
fi

systemctl enable --now firewalld >>"$LOG" 2>&1

# -------------------------------------------------------------------
# 2) CONFIGURAR SELINUX COMO PERMISSIVO
# -------------------------------------------------------------------
log_step step2
setenforce 0 || true
sed -i 's/^SELINUX=.*/SELINUX=permissive/' /etc/selinux/config

# -------------------------------------------------------------------
# 3) INSTALAR APACHE, PHP E MARIADB (MariaDB 12.x – repo oficial)
# -------------------------------------------------------------------
log_step step3
prepare_rhel_repos_before_step3

# Configura repositório oficial da MariaDB para a série desejada (12.0.x)
curl -LsS "$MARIADB_REPO_SETUP_URL" \
  | bash -s -- --mariadb-server-version="${MARIADB_SERIES}" >>"$LOG" 2>&1

# Desabilita o módulo MariaDB da distro para evitar conflito de versões
dnf -y module disable mariadb >>"$LOG" 2>&1 || true

rpm -Uvh https://rpms.remirepo.net/enterprise/remi-release-9.rpm >>"$LOG" 2>&1 || true
dnf module reset php -y >>"$LOG" 2>&1
dnf module enable "php:${PHP_STREAM}" -y >>"$LOG" 2>&1

dnf install -y \
  httpd php php-cli php-fpm php-mysqlnd php-opcache \
  php-mbstring php-xml php-json php-curl php-gd php-zip \
  php-sodium php-ldap php-intl php-bz2 php-bcmath \
  "${MARIADB_PKG}" >>"$LOG" 2>&1

systemctl enable --now httpd php-fpm mariadb >>"$LOG" 2>&1

# Cliente de linha de comando para MariaDB/MySQL
if command -v mariadb >/dev/null 2>&1; then
  MYSQL_BIN="mariadb"
else
  MYSQL_BIN="mysql"
fi

# -------------------------------------------------------------------
# 4) CONFIGURAR APACHE PARA GLPI E ZABBIX
# -------------------------------------------------------------------
log_step step4
rm -f /etc/httpd/conf.d/welcome.conf
cat > /etc/httpd/conf.d/glpi_zabbix.conf <<APACHE
<VirtualHost *:80>
  ServerName $DOMAIN

  Alias /glpi $INSTALL_GLPI_DIR/public
  <Directory "$INSTALL_GLPI_DIR/public">
    DirectoryIndex index.php
    Options FollowSymLinks
    AllowOverride All
    Require all granted
    RewriteEngine On
    RewriteBase /glpi/
    RewriteCond %{REQUEST_FILENAME} !-f
    RewriteRule ^(.*)$ index.php [QSA,L]
  </Directory>

  Alias /zabbix /usr/share/zabbix/ui
  <Directory "/usr/share/zabbix/ui">
    DirectoryIndex index.php
    Options FollowSymLinks
    AllowOverride All
    Require all granted
    RewriteEngine On
    RewriteBase /zabbix/
    RewriteCond %{REQUEST_FILENAME} !-f
    RewriteRule ^(.*)$ index.php [QSA,L]
  </Directory>
</VirtualHost>
APACHE
systemctl reload httpd >>"$LOG" 2>&1

# -------------------------------------------------------------------
# 5) AJUSTAR php.ini PARA ZABBIX
# -------------------------------------------------------------------
log_step step5
if grep -q '^session.cookie_httponly' /etc/php.ini; then
  sed -i 's/^session.cookie_httponly.*/session.cookie_httponly = On/' /etc/php.ini
else
  echo 'session.cookie_httponly = On' >> /etc/php.ini
fi

for pair in post_max_size:16M max_execution_time:300 max_input_time:300; do
  key=${pair%%:*}
  value=${pair#*:}
  if grep -q "^$key" /etc/php.ini; then
    sed -i "s/^$key.*/$key = $value/" /etc/php.ini
  else
    echo "$key = $value" >> /etc/php.ini
  fi
done

systemctl restart php-fpm >>"$LOG" 2>&1

# -------------------------------------------------------------------
# 6) INICIALIZAR MARIADB E PROTEGER ROOT
# -------------------------------------------------------------------
log_step step6
$MYSQL_BIN -u root <<SQL
ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PASS';
DELETE FROM mysql.user WHERE User='';
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db LIKE 'test%';
FLUSH PRIVILEGES;
SQL

# -------------------------------------------------------------------
# 7) CRIAR BANCO DE DADOS PARA GLPI E ZABBIX
# -------------------------------------------------------------------
log_step step7
$MYSQL_BIN -u root -p"$MYSQL_ROOT_PASS" <<SQL
CREATE DATABASE IF NOT EXISTS \`$GLPI_DB\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$GLPI_USER'@'localhost' IDENTIFIED BY '$GLPI_PASS';
ALTER USER '$GLPI_USER'@'localhost' IDENTIFIED BY '$GLPI_PASS';
GRANT ALL PRIVILEGES ON \`$GLPI_DB\`.* TO '$GLPI_USER'@'localhost';

CREATE DATABASE IF NOT EXISTS \`$ZABBIX_DB\` CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
CREATE USER IF NOT EXISTS '$ZABBIX_USER'@'localhost' IDENTIFIED BY '$ZABBIX_PASS';
ALTER USER '$ZABBIX_USER'@'localhost' IDENTIFIED BY '$ZABBIX_PASS';
GRANT ALL PRIVILEGES ON \`$ZABBIX_DB\`.* TO '$ZABBIX_USER'@'localhost';

FLUSH PRIVILEGES;
SQL

# Garante que exista um arquivo de configuração do servidor MariaDB
MARIADB_CONF=""

if [[ -f /etc/my.cnf.d/mariadb-server.cnf ]]; then
  MARIADB_CONF="/etc/my.cnf.d/mariadb-server.cnf"
elif [[ -f /etc/my.cnf.d/server.cnf ]]; then
  MARIADB_CONF="/etc/my.cnf.d/server.cnf"
else
  MARIADB_CONF="/etc/my.cnf.d/server.cnf"
  mkdir -p /etc/my.cnf.d
  cat > "$MARIADB_CONF" <<EOF
[mysqld]
EOF
fi

if grep -q '^\s*bind-address' "$MARIADB_CONF"; then
  sed -i 's/^\s*bind-address.*/bind-address = 127.0.0.1/' "$MARIADB_CONF"
else
  sed -i '/^\[mysqld\]/a bind-address = 127.0.0.1' "$MARIADB_CONF"
fi

systemctl restart mariadb >>"$LOG" 2>&1

# -------------------------------------------------------------------
# 8) INSTALAR GLPI
# -------------------------------------------------------------------
log_step step8

# Obtém a última versão estável do GLPI via API do GitHub (ignora pré-releases como beta/RC)
GLPI_VER_DETECTED=$(curl -sS https://api.github.com/repos/glpi-project/glpi/releases/latest | \
                    grep -Po '"tag_name":\s*"\K[^"]+')

# Se a detecção falhar ou retornar versão pré-lançamento, usa versão padrão de fallback
if [[ -z "$GLPI_VER_DETECTED" || "$GLPI_VER_DETECTED" =~ (alpha|beta|RC|rc) ]]; then
  GLPI_VER_DETECTED="$GLPI_VERSION"
fi

# Atualiza a versão efetivamente usada para o resumo final
GLPI_VERSION_USED="$GLPI_VER_DETECTED"
GLPI_MAJOR="${GLPI_VERSION_USED%%.*}"

# Download do pacote TGZ e extração do GLPI
wget -qO /tmp/glpi.tgz "https://github.com/glpi-project/glpi/releases/download/${GLPI_VER_DETECTED}/glpi-${GLPI_VER_DETECTED}.tgz"
rm -rf "$INSTALL_GLPI_DIR"
mkdir -p "$INSTALL_GLPI_DIR"
tar -xzf /tmp/glpi.tgz -C "$INSTALL_GLPI_DIR" --strip-components=1
chown -R apache:apache "$INSTALL_GLPI_DIR"

# Define idioma do GLPI de acordo com o idioma do sistema
case "$SYS_LANG" in
  pt) GLPI_LANG="pt_BR";;
  es) GLPI_LANG="es_ES";;
  *)  GLPI_LANG="en_GB";;
esac

# Instalação do GLPI via CLI (executado como usuário apache)
runuser -u apache -- php "$INSTALL_GLPI_DIR/bin/console" db:install \
  -H localhost -d "$GLPI_DB" -u "$GLPI_USER" -p "$GLPI_PASS" -L "$GLPI_LANG" --no-interaction >>"$LOG" 2>&1

# Remove o instalador web do GLPI por segurança
rm -f "$INSTALL_GLPI_DIR/install/install.php"

# -------------------------------------------------------------------
# 9) INSTALAR O ZABBIX ${ZABBIX_VERSION}
# -------------------------------------------------------------------
log_step step9

# Detecta família do sistema para montar corretamente a URL do repositório Zabbix
if grep -qi 'rocky' /etc/os-release; then
  ZBX_OS_FAMILY="rocky"
elif grep -qi 'oracle' /etc/os-release; then
  ZBX_OS_FAMILY="oracle"
elif is_rhel_host; then
  ZBX_OS_FAMILY="rhel"
else
  ZBX_OS_FAMILY="rhel"
fi

case "$ZBX_OS_FAMILY" in
  rocky)
    ZABBIX_REPO="https://repo.zabbix.com/zabbix/${ZABBIX_VERSION}/release/rocky/9/noarch/zabbix-release-latest-${ZABBIX_VERSION}.el9.noarch.rpm"
    ;;
  oracle)
    ZABBIX_REPO="https://repo.zabbix.com/zabbix/${ZABBIX_VERSION}/release/oracle/9/noarch/zabbix-release-latest-${ZABBIX_VERSION}.el9.noarch.rpm"
    ;;
  *)
    # RHEL e compatíveis
    ZABBIX_REPO="https://repo.zabbix.com/zabbix/${ZABBIX_VERSION}/release/rhel/9/noarch/zabbix-release-latest-${ZABBIX_VERSION}.el9.noarch.rpm"
    ;;
esac

log "    → Registrando repositório oficial do Zabbix (${ZABBIX_VERSION}) para ${ZBX_OS_FAMILY}..."
ZABBIX_REPO_LOCAL=""
case "$ZBX_OS_FAMILY" in
  rocky)
    ZABBIX_REPO_LOCAL=$(download_zabbix_release_rpm       "https://repo.zabbix.com/zabbix/${ZABBIX_VERSION}/release/rocky/9/noarch/zabbix-release-latest-${ZABBIX_VERSION}.el9.noarch.rpm"       "https://repo.zabbix.com/zabbix/${ZABBIX_VERSION}/stable/rocky/9/x86_64/zabbix-release-latest-${ZABBIX_VERSION}.el9.noarch.rpm"       "https://repo.zabbix.com/zabbix/${ZABBIX_VERSION}/release/rhel/9/noarch/zabbix-release-latest-${ZABBIX_VERSION}.el9.noarch.rpm" || true)
    ;;
  oracle)
    ZABBIX_REPO_LOCAL=$(download_zabbix_release_rpm       "https://repo.zabbix.com/zabbix/${ZABBIX_VERSION}/release/oracle/9/noarch/zabbix-release-latest-${ZABBIX_VERSION}.el9.noarch.rpm"       "https://repo.zabbix.com/zabbix/${ZABBIX_VERSION}/release/rhel/9/noarch/zabbix-release-latest-${ZABBIX_VERSION}.el9.noarch.rpm" || true)
    ;;
  *)
    ZABBIX_REPO_LOCAL=$(download_zabbix_release_rpm       "https://repo.zabbix.com/zabbix/${ZABBIX_VERSION}/release/rhel/9/noarch/zabbix-release-latest-${ZABBIX_VERSION}.el9.noarch.rpm" || true)
    ;;
esac

if [[ -z "$ZABBIX_REPO_LOCAL" || ! -f "$ZABBIX_REPO_LOCAL" ]]; then
  log "    → ERRO: falha ao obter o pacote do repositório do Zabbix após múltiplas tentativas. Verifique DNS, rota e acesso a repo.zabbix.com."
  exit 1
fi

if ! rpm -Uvh "$ZABBIX_REPO_LOCAL" >>"$LOG" 2>&1; then
  log "    → ERRO: falha ao registrar o repositório do Zabbix usando o pacote local $ZABBIX_REPO_LOCAL"
  exit 1
fi

# Evita conflito com pacotes Zabbix 6.0 provenientes do EPEL / OL9 EPEL
ZBX_DNF_OPTS=""
if grep -qi 'oracle' /etc/os-release; then
  # Em Oracle Linux 9 o repositório equivalente ao EPEL é o ol9_developer_EPEL
  ZBX_DNF_OPTS="--disablerepo=ol9_developer_EPEL"
else
  ZBX_DNF_OPTS="--disablerepo=epel"
fi

log "    → Instalando pacotes Zabbix (${ZABBIX_VERSION}) sem conflito com EPEL..."
if ! dnf install -y $ZBX_DNF_OPTS \
      zabbix-server-mysql \
      zabbix-web-mysql \
      zabbix-apache-conf \
      zabbix-sql-scripts \
      zabbix-agent2 \
      zabbix-get >>"$LOG" 2>&1; then
  log "ERRO: Falha na instalação dos pacotes do Zabbix. Verifique sua conexão de rede e o repositório Zabbix."
  exit 1
fi

# -------------------------------------------------------------------
# 10) IMPORTAR ESQUEMA DO ZABBIX
# -------------------------------------------------------------------
log_step step10
if [[ ! -f /usr/share/zabbix/sql-scripts/mysql/server.sql.gz ]]; then
  log "ERRO: arquivo /usr/share/zabbix/sql-scripts/mysql/server.sql.gz não encontrado. Verifique o pacote zabbix-sql-scripts."
  exit 1
fi

zcat /usr/share/zabbix/sql-scripts/mysql/server.sql.gz \
    | $MYSQL_BIN -u "$ZABBIX_USER" -p"$ZABBIX_PASS" "$ZABBIX_DB" 2>>"$LOG" \
      || { log "ERRO: falha ao importar esquema do Zabbix"; exit 1; }

# -------------------------------------------------------------------
# 11) CONFIGURAR /etc/zabbix/zabbix_server.conf
# -------------------------------------------------------------------
log_step step11
sed -i "/^#\s*DBHost=/c\DBHost=localhost"                  /etc/zabbix/zabbix_server.conf
sed -i "/^#\s*DBName=/c\DBName=$ZABBIX_DB"                 /etc/zabbix/zabbix_server.conf
sed -i "/^#\s*DBUser=/c\DBUser=$ZABBIX_USER"               /etc/zabbix/zabbix_server.conf
sed -i "/^#\s*DBPassword=/c\DBPassword=$ZABBIX_PASS"       /etc/zabbix/zabbix_server.conf

grep -q '^DBHost='     /etc/zabbix/zabbix_server.conf || echo "DBHost=localhost"       >> /etc/zabbix/zabbix_server.conf
grep -q '^DBName='     /etc/zabbix/zabbix_server.conf || echo "DBName=$ZABBIX_DB"      >> /etc/zabbix/zabbix_server.conf
grep -q '^DBUser='     /etc/zabbix/zabbix_server.conf || echo "DBUser=$ZABBIX_USER"    >> /etc/zabbix/zabbix_server.conf
grep -q '^DBPassword=' /etc/zabbix/zabbix_server.conf || echo "DBPassword=$ZABBIX_PASS" >> /etc/zabbix/zabbix_server.conf

systemctl restart zabbix-server >>"$LOG" 2>&1 || true

# -------------------------------------------------------------------
# 12) CONFIGURAR INTERFACE WEB DO ZABBIX
# -------------------------------------------------------------------
log_step step12
mkdir -p /etc/zabbix/web

cat <<EOF > /etc/zabbix/web/zabbix.conf.php
<?php
global \$DB;
\$DB['TYPE']     = 'MYSQL';
\$DB['SERVER']   = 'localhost';
\$DB['PORT']     = '0';
\$DB['DATABASE'] = '$ZABBIX_DB';
\$DB['USER']     = '$ZABBIX_USER';
\$DB['PASSWORD'] = '$ZABBIX_PASS';
\$ZBX_SERVER      = 'localhost';
\$ZBX_SERVER_PORT = '10051';
\$ZBX_SERVER_NAME = 'Zabbix Server';
\$IMAGE_FORMAT_DEFAULT = IMAGE_FORMAT_PNG;

\$ZBX_DEFAULT_LANGUAGE = '$ZBX_LANG';
\$ZBX_DEFAULT_THEME    = 'dark-theme';
EOF

chown -R apache:apache /etc/zabbix/web
chmod 750 /etc/zabbix/web
chmod 640 /etc/zabbix/web/zabbix.conf.php

if command -v semanage &>/dev/null; then
  semanage fcontext -a -t httpd_sys_content_t "/etc/zabbix/web(/.*)?"
  restorecon -Rv /etc/zabbix/web >>"$LOG" 2>&1
fi

systemctl restart httpd php-fpm >>"$LOG" 2>&1

# -------------------------------------------------------------------
# 13) ATIVAR SERVIÇOS ZABBIX
# -------------------------------------------------------------------
log_step step13
systemctl enable --now zabbix-server zabbix-agent2 httpd php-fpm >>"$LOG" 2>&1

# -------------------------------------------------------------------
# 14) LOCALE + APACHE
# -------------------------------------------------------------------
log_step step14
localedef -i pt_BR -f UTF-8 pt_BR.UTF-8 >>"$LOG" 2>&1 || true

HTTPD_SYSCONFIG="/etc/sysconfig/httpd"
if [[ -f "$HTTPD_SYSCONFIG" ]]; then
  if ! grep -q '^LANG=' "$HTTPD_SYSCONFIG"; then
    echo "LANG=pt_BR.UTF-8" >> "$HTTPD_SYSCONFIG"
    log "    → Adicionado LANG=pt_BR.UTF-8 em $HTTPD_SYSCONFIG."
  else
    sed -i 's/^LANG=.*/LANG=pt_BR.UTF-8/' "$HTTPD_SYSCONFIG"
    log "    → Atualizado LANG=pt_BR.UTF-8 em $HTTPD_SYSCONFIG."
  fi
else
  echo "LANG=pt_BR.UTF-8" > "$HTTPD_SYSCONFIG"
  log "    → Criado $HTTPD_SYSCONFIG com LANG=pt_BR.UTF-8."
fi

systemctl restart httpd >>"$LOG" 2>&1

# -------------------------------------------------------------------
# 15) APLICAR IDIOMA/TEMA NO BANCO ZABBIX
# -------------------------------------------------------------------
log_step step15
#
# Ajustar idioma e tema apenas na tabela `users`. A tabela `users_gui_settings` não existe
# em versões recentes do Zabbix (ex.: 7.4), portanto a atualização foi removida para
# evitar erros de SQL. Utilizamos o operador OR para que o script continue caso
# a atualização falhe silenciosamente.
$MYSQL_BIN -uroot -p"$MYSQL_ROOT_PASS" "$ZABBIX_DB" <<EOF >>"$LOG" 2>&1 || true
UPDATE users
SET lang = '$ZBX_LANG',
    theme = 'dark-theme';
EOF

# Reinicia serviços para aplicar alterações
systemctl restart zabbix-server >>"$LOG" 2>&1 || true
systemctl restart httpd php-fpm >>"$LOG" 2>&1 || true

# -------------------------------------------------------------------
# 16) FIREWALL
# -------------------------------------------------------------------
log_step step16
firewall-cmd --permanent --add-port=10051/tcp >>"$LOG" 2>&1
firewall-cmd --permanent --add-service=http >>"$LOG" 2>&1
firewall-cmd --permanent --add-service=https >>"$LOG" 2>&1
firewall-cmd --permanent --add-port=3000/tcp >>"$LOG" 2>&1
firewall-cmd --permanent --add-port=9000/tcp >>"$LOG" 2>&1
firewall-cmd --permanent --remove-port=3306/tcp >>"$LOG" 2>&1 || true
firewall-cmd --reload >>"$LOG" 2>&1

# -------------------------------------------------------------------
# 17) CHECAR ZABBIX-SERVER
# -------------------------------------------------------------------
log_step step17

if ! systemctl is-active zabbix-server &>/dev/null; then
  log "    → ERRO: o serviço zabbix-server NÃO está ativo."
  systemctl status zabbix-server >>"$LOG" 2>&1 || true
  journalctl -u zabbix-server --no-pager -n 20 >>"$LOG" 2>&1 || true
  exit 1
fi

sleep 5

log "    → Saída de 'ss -tunlp' (antes do grep):"
ss -tunlp >>"$LOG" 2>&1

if ss -tunlp | grep -q "10051.*zabbix_server"; then
  log "    → Zabbix está ativo e escutando na porta 10051."
else
  log "    → ERRO: Zabbix não está escutando na porta 10051."
  log "    → Status do serviço zabbix-server:"
  systemctl status zabbix-server >>"$LOG" 2>&1 || true
  log "    → Últimos registros do journal do zabbix-server:"
  journalctl -u zabbix-server --no-pager -n 20 >>"$LOG" 2>&1 || true
  exit 1
fi

# -------------------------------------------------------------------
# 18) GRAYLOG + MONGODB + OPENSEARCH
# -------------------------------------------------------------------
log_step step18

detect_latest_graylog_release
log "    → Release mais recente do Graylog 7.x detectada nesta execução: ${GRAYLOG_LATEST_VERSION}"

run_dnf_step1 0 install -y java-17-openjdk-headless openssl dnf-plugins-core

cat > /etc/yum.repos.d/mongodb-org-${MONGODB_SERIES}.repo <<EOF
[mongodb-org-${MONGODB_SERIES}]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/9/mongodb-org/${MONGODB_SERIES}/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://pgp.mongodb.com/server-${MONGODB_SERIES}.asc
EOF

dnf install -y mongodb-org >>"$LOG" 2>&1
systemctl enable --now mongod >>"$LOG" 2>&1

curl -fsSL "${OPENSEARCH_REPO_URL}" -o /etc/yum.repos.d/opensearch-2.x.repo >>"$LOG" 2>&1
sed -i 's/^gpgcheck=.*/gpgcheck=0/' /etc/yum.repos.d/opensearch-2.x.repo
OPENSEARCH_INITIAL_ADMIN_PASSWORD=$(generate_admin_password)
echo "$OPENSEARCH_INITIAL_ADMIN_PASSWORD" > "$OPENSEARCH_ADMIN_PASS_FILE"
chmod 600 "$OPENSEARCH_ADMIN_PASS_FILE"
OPENSEARCH_INITIAL_ADMIN_PASSWORD="$OPENSEARCH_INITIAL_ADMIN_PASSWORD" dnf install -y opensearch >>"$LOG" 2>&1
configure_opensearch_single_node
systemd_set_timeout_startsec "opensearch" "10min"
systemctl daemon-reload >>"$LOG" 2>&1 || true
systemctl enable opensearch >>"$LOG" 2>&1 || true
systemctl restart opensearch >>"$LOG" 2>&1 || true
wait_for_service_active "opensearch" 900 || die "OpenSearch não ficou ativo no tempo esperado."
wait_for_http_ok "http://127.0.0.1:9200" 900 || die "OpenSearch não respondeu no tempo esperado."

rpm -Uvh "${GRAYLOG_REPO_RPM}" >>"$LOG" 2>&1 || true
dnf install -y graylog-server >>"$LOG" 2>&1
GRAYLOG_VERSION=$(rpm -q --qf '%{VERSION}-%{RELEASE}' graylog-server 2>>"$LOG" || echo "${GRAYLOG_LATEST_VERSION}")
GRAYLOG_ADMIN_PASS="${GRAYLOG_ADMIN_PASS_DEFAULT}"
echo "$GRAYLOG_ADMIN_PASS" > "$GRAYLOG_ADMIN_PASS_FILE"
chmod 600 "$GRAYLOG_ADMIN_PASS_FILE"
GRAYLOG_SECRET=$(generate_password_secret)
GRAYLOG_ROOT_SHA2=$(printf '%s' "$GRAYLOG_ADMIN_PASS" | sha256sum | awk '{print $1}')
set_prop_value /etc/graylog/server/server.conf password_secret "$GRAYLOG_SECRET"
set_prop_value /etc/graylog/server/server.conf root_password_sha2 "$GRAYLOG_ROOT_SHA2"
set_prop_value /etc/graylog/server/server.conf http_bind_address "0.0.0.0:9000"
set_prop_value /etc/graylog/server/server.conf http_publish_uri "http://${DOMAIN}:9000/"
set_prop_value /etc/graylog/server/server.conf elasticsearch_hosts "http://127.0.0.1:9200"
set_prop_value /etc/graylog/server/server.conf mongodb_uri "mongodb://127.0.0.1:27017/graylog"
systemctl enable --now graylog-server >>"$LOG" 2>&1
wait_for_service_active "graylog-server" 600 || die "Graylog Server não ficou ativo no tempo esperado."
wait_for_http_ok "http://127.0.0.1:9000/" 600 || die "Graylog Web não respondeu no tempo esperado."
log "18) Graylog instalado com sucesso (MongoDB, OpenSearch e Graylog Server)."

# -------------------------------------------------------------------
# 19) GRAFANA
# -------------------------------------------------------------------
log_step step19

cat > /etc/yum.repos.d/grafana.repo <<EOF
[grafana]
name=Grafana OSS
baseurl=https://packages.grafana.com/oss/rpm
repo_gpgcheck=0
enabled=1
gpgcheck=1
gpgkey=https://packages.grafana.com/gpg.key
EOF

rpm --import https://packages.grafana.com/gpg.key >>"$LOG" 2>&1 || true
dnf clean all >>"$LOG" 2>&1
dnf makecache >>"$LOG" 2>&1
dnf install -y --nogpgcheck grafana >>"$LOG" 2>&1

if command -v grafana-server &>/dev/null; then
  GRAFANA_VERSION=$(grafana-server -v 2>&1 | awk '{print $2; exit}')
fi

case "$SYS_LANG" in
  pt)   GRAFANA_LANG="pt-BR";;
  es)   GRAFANA_LANG="es-ES";;
  *)    GRAFANA_LANG="en-US";;
esac

if grep -q '^\[users\]' /etc/grafana/grafana.ini; then
  sed -i "/^\[users\]/,/^\[/ s|^;*\s*default_language\s*=.*|default_language = ${GRAFANA_LANG}|" /etc/grafana/grafana.ini
else
  printf '
[users]
default_language = %s
' "${GRAFANA_LANG}" >> /etc/grafana/grafana.ini
fi

if grep -q '^\[security\]' /etc/grafana/grafana.ini; then
  sed -i "/^\[security\]/a admin_password = ${GRAFANA_ADMIN_PASS}" /etc/grafana/grafana.ini
else
  cat >> /etc/grafana/grafana.ini <<EOF

[security]
admin_password = ${GRAFANA_ADMIN_PASS}
EOF
fi

systemd_set_timeout_startsec "grafana-server" "${GRAFANA_SYSTEMD_TIMEOUT:-5min}"
systemctl enable --now grafana-server >>"$LOG" 2>&1 || true
wait_for_service_active "grafana-server" 300 || die "grafana-server não ficou ativo no tempo esperado."
wait_for_http_ok "http://127.0.0.1:3000/api/health" 300 || die "API de health do Grafana não respondeu no tempo esperado."

if [[ "$ENABLE_GRAFANA_OPENSEARCH_DS" == "yes" ]]; then
  log "    → Integração opcional habilitada: Grafana -> OpenSearch"
  grafana cli plugins install grafana-opensearch-datasource >>"$LOG" 2>&1 || true
fi

if [[ "$ENABLE_GRAFANA_GLPI_INFINITY" == "yes" ]]; then
  log "    → Integração opcional habilitada: Grafana -> GLPI via Infinity/API"
  grafana cli plugins install yesoreyeram-infinity-datasource >>"$LOG" 2>&1 || true
fi

provision_grafana_optional_datasources

if [[ "$ENABLE_GRAFANA_OPENSEARCH_DS" == "yes" || "$ENABLE_GRAFANA_GLPI_INFINITY" == "yes" ]]; then
  systemctl restart grafana-server >>"$LOG" 2>&1 || true
  wait_for_service_active "grafana-server" 300 || die "grafana-server não ficou ativo após instalar/provisionar integrações opcionais."
  wait_for_http_ok "http://127.0.0.1:3000/api/health" 300 || die "Grafana não respondeu após instalar/provisionar integrações opcionais."
fi

log "19) Grafana instalado com sucesso."

# -------------------------------------------------------------------
# 20) REINICIAR SERVIÇOS INSTALADOS
# -------------------------------------------------------------------
log_step step20
SERVICES_TO_RESTART=(httpd php-fpm mariadb zabbix-server zabbix-agent2 grafana-server graylog-server opensearch mongod firewalld)
RESTARTED_SERVICES=()
for svc in "${SERVICES_TO_RESTART[@]}"; do
  if systemctl list-unit-files | grep -q "^${svc}\.service"; then
    systemctl restart "$svc" >>"$LOG" 2>&1 || true
    RESTARTED_SERVICES+=("$svc")
  fi
done
case "$SYS_LANG" in
  pt) echo "OS SEGUINTES SERVIÇOS INSTALADOS FORAM REINICIADOS: ${RESTARTED_SERVICES[*]}" ;;
  es) echo "SE HAN REINICIADO LOS SIGUIENTES SERVICIOS INSTALADOS: ${RESTARTED_SERVICES[*]}" ;;
  *)  echo "THE FOLLOWING INSTALLED SERVICES WERE RESTARTED: ${RESTARTED_SERVICES[*]}" ;;
esac

# -------------------------------------------------------------------
# 27) RESUMO FINAL
# -------------------------------------------------------------------
IP=$(hostname -I | awk '{print $1}')
END_TIME=$(date +%s)
DURATION=$((END_TIME-START_TIME))
MIN=$((DURATION/60))

if command -v php &>/dev/null; then
  PHP_VERSION_DETECTED=$(php -r 'echo PHP_VERSION;' 2>/dev/null)
else
  PHP_VERSION_DETECTED="desconhecida"
fi

if command -v mariadb &>/dev/null; then
  MARIADB_VERSION_DETECTED=$(mariadb --version 2>/dev/null | awk '{print $5}' | tr -d ',')
elif command -v mysql &>/dev/null; then
  MARIADB_VERSION_DETECTED=$(mysql --version 2>/dev/null | awk '{print $5}' | tr -d ',')
else
  MARIADB_VERSION_DETECTED="desconhecida"
fi

if command -v httpd &>/dev/null; then
  APACHE_VERSION_DETECTED=$(httpd -v 2>/dev/null | awk -F'/' '/Server version/ {print $2}' | awk '{print $1}')
else
  APACHE_VERSION_DETECTED="desconhecida"
fi

if command -v zabbix_server &>/dev/null; then
  ZABBIX_VERSION_DETECTED=$(zabbix_server --version 2>/dev/null | awk '/zabbix_server/ {print $3; exit}')
else
  ZABBIX_VERSION_DETECTED="$ZABBIX_VERSION"
fi

if [[ -z "${GRAFANA_VERSION}" || "${GRAFANA_VERSION}" == "latest" ]]; then
  if command -v grafana-server &>/dev/null; then
    GRAFANA_VERSION=$(grafana-server -v 2>&1 | awk '{print $2; exit}')
  fi
fi

case "$SYS_LANG" in
  pt)
    echo -e "\n============================================"
    echo    "      RESUMO DA INSTALAÇÃO COMPLETA        "
    echo    "============================================"
    echo    "Versão do script: ${SCRIPT_VERSION}"
    echo    "GLPI:         ${GLPI_VERSION_USED}                 -> http://${IP}/glpi"
    echo    "Zabbix:       ${ZABBIX_VERSION_DETECTED}           -> http://${IP}/zabbix"
    echo    "Grafana:      ${GRAFANA_VERSION}                  -> http://${IP}:3000"
    echo    "Graylog:      ${GRAYLOG_VERSION}                  -> http://${IP}:9000"
    echo    "Apache HTTPD: ${APACHE_VERSION_DETECTED}"
    echo    "PHP:          ${PHP_VERSION_DETECTED}"
    echo    "MariaDB:      ${MARIADB_VERSION_DETECTED}"
    echo    "MongoDB:      ${MONGODB_SERIES}.x"
    echo    "OpenSearch:   2.x"
    echo    ""
    echo    "Bancos de dados:"
    echo    " - GLPI:     ${GLPI_DB} / ${GLPI_USER} / ${GLPI_PASS}"
    echo    " - Zabbix:   ${ZABBIX_DB} / ${ZABBIX_USER} / ${ZABBIX_PASS}"
    echo    ""
    echo    "Credenciais padrão:"
    echo    " - GLPI Admin:    glpi / glpi"
    echo    " - Zabbix Admin:  Admin / zabbix"
    echo    " - Grafana Admin: admin / ${GRAFANA_ADMIN_PASS}"
    echo    " - Graylog Admin: admin / $(cat ${GRAYLOG_ADMIN_PASS_FILE} 2>/dev/null || echo senha_em_${GRAYLOG_ADMIN_PASS_FILE})"
    echo
    echo    "Integrações opcionais do Grafana:"
    echo    " - OpenSearch datasource: ${ENABLE_GRAFANA_OPENSEARCH_DS}"
    echo    " - GLPI via Infinity/API: ${ENABLE_GRAFANA_GLPI_INFINITY}"
    echo
    echo    "Tempo total: ${MIN} minutos"
    echo    "Por favor faça a alteração das senhas padrão descritas acima."
    ;;
  es)
    echo -e "\n============================================"
    echo    "      RESUMEN DE LA INSTALACIÓN COMPLETA   "
    echo    "============================================"
    echo    "Versión del script: ${SCRIPT_VERSION}"
    echo    "GLPI:         ${GLPI_VERSION_USED}                 -> http://${IP}/glpi"
    echo    "Zabbix:       ${ZABBIX_VERSION_DETECTED}           -> http://${IP}/zabbix"
    echo    "Grafana:      ${GRAFANA_VERSION}                  -> http://${IP}:3000"
    echo    "Graylog:      ${GRAYLOG_VERSION}                  -> http://${IP}:9000"
    echo    "Apache HTTPD: ${APACHE_VERSION_DETECTED}"
    echo    "PHP:          ${PHP_VERSION_DETECTED}"
    echo    "MariaDB:      ${MARIADB_VERSION_DETECTED}"
    echo    "MongoDB:      ${MONGODB_SERIES}.x"
    echo    "OpenSearch:   2.x"
    echo    ""
    echo    "Bases de datos:"
    echo    " - GLPI:     ${GLPI_DB} / ${GLPI_USER} / ${GLPI_PASS}"
    echo    " - Zabbix:   ${ZABBIX_DB} / ${ZABBIX_USER} / ${ZABBIX_PASS}"
    echo    ""
    echo    "Credenciales por defecto:"
    echo    " - GLPI Admin:    glpi / glpi"
    echo    " - Zabbix Admin:  Admin / zabbix"
    echo    " - Grafana Admin: admin / ${GRAFANA_ADMIN_PASS}"
    echo    " - Graylog Admin: admin / $(cat ${GRAYLOG_ADMIN_PASS_FILE} 2>/dev/null || echo senha_em_${GRAYLOG_ADMIN_PASS_FILE})"
    echo
    echo    "Integraciones opcionales de Grafana:"
    echo    " - OpenSearch datasource: ${ENABLE_GRAFANA_OPENSEARCH_DS}"
    echo    " - GLPI vía Infinity/API: ${ENABLE_GRAFANA_GLPI_INFINITY}"
    echo
    echo    "Tiempo total: ${MIN} minutos"
    echo    "Por favor cambie las contraseñas predeterminadas descritas anteriormente."
    ;;
  *)
    echo -e "\n============================================"
    echo    "      INSTALLATION SUMMARY COMPLETE        "
    echo    "============================================"
    echo    "Script version: ${SCRIPT_VERSION}"
    echo    "GLPI:         ${GLPI_VERSION_USED}                 -> http://${IP}/glpi"
    echo    "Zabbix:       ${ZABBIX_VERSION_DETECTED}           -> http://${IP}/zabbix"
    echo    "Grafana:      ${GRAFANA_VERSION}                  -> http://${IP}:3000"
    echo    "Graylog:      ${GRAYLOG_VERSION}                  -> http://${IP}:9000"
    echo    "Apache HTTPD: ${APACHE_VERSION_DETECTED}"
    echo    "PHP:          ${PHP_VERSION_DETECTED}"
    echo    "MariaDB:      ${MARIADB_VERSION_DETECTED}"
    echo    "MongoDB:      ${MONGODB_SERIES}.x"
    echo    "OpenSearch:   2.x"
    echo    ""
    echo    "Databases created:"
    echo    " - GLPI:     ${GLPI_DB} / ${GLPI_USER} / ${GLPI_PASS}"
    echo    " - Zabbix:   ${ZABBIX_DB} / ${ZABBIX_USER} / ${ZABBIX_PASS}"
    echo    ""
    echo    "Default logins:"
    echo    " - GLPI Admin:    glpi / glpi"
    echo    " - Zabbix Admin:  Admin / zabbix"
    echo    " - Grafana Admin: admin / ${GRAFANA_ADMIN_PASS}"
    echo    " - Graylog Admin: admin / $(cat ${GRAYLOG_ADMIN_PASS_FILE} 2>/dev/null || echo senha_em_${GRAYLOG_ADMIN_PASS_FILE})"
    echo    ""
    echo    "Total time: ${MIN} minutes"
    echo    "Please change the default passwords described above."
    ;;
esac
