#!/bin/bash

# ============================================================
# ZABBIX AGENT 2 - INSTALAÇÃO AUTOMATICA
# Zabbix Server: 7.0.x
#
# Sistemas suportados:
#   Ubuntu 18.04 / 20.04 / 22.04 / 24.04 / 26.04
#   AlmaLinux 8 / 9 / 10
#   CentOS 8 / 9 / 10
#
# 
# ============================================================

set -e

ZABBIX_VERSION="7.0"
ZABBIX_PORT="10051"
AGENT_PORT="10050"

CONFIG_FILE="/etc/zabbix/zabbix_agent2.conf"

# ------------------------------------------------------------
# Colors
# ------------------------------------------------------------

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# ------------------------------------------------------------
# Root check
# ------------------------------------------------------------

if [ "$EUID" -ne 0 ]; then
    error "Execute este script como root."
    exit 1
fi

# ------------------------------------------------------------
# Detect OS
# ------------------------------------------------------------

if [ ! -f /etc/os-release ]; then
    error "Não foi possível identificar o sistema operacional."
    exit 1
fi

source /etc/os-release

OS_ID="${ID,,}"
OS_VERSION="${VERSION_ID%%.*}"

echo
echo "============================================================"
echo "        ZABBIX AGENT 2 - INSTALLER"
echo "============================================================"
echo

info "Sistema detectado: $PRETTY_NAME"
info "ID: $OS_ID"
info "Versão: $VERSION_ID"

# ------------------------------------------------------------
# Request Zabbix Server
# ------------------------------------------------------------

echo
read -rp "Digite o IP/DNS do Zabbix Server [ex: 172.90.10.20]: " ZABBIX_SERVER

if [ -z "$ZABBIX_SERVER" ]; then
    error "O endereço do Zabbix Server é obrigatório."
    exit 1
fi

# ------------------------------------------------------------
# Request Zabbix Hostname
# ------------------------------------------------------------

echo
echo "============================================================"
echo "IDENTIFICAÇÃO DO HOST NO ZABBIX"
echo "============================================================"
echo
echo "IMPORTANTE:"
echo "Digite EXATAMENTE o Hostname cadastrado ou que será"
echo "cadastrado no frontend do Zabbix."
echo
echo "O hostname do sistema operacional NÃO será usado"
echo "automaticamente."
echo

read -rp "Hostname do servidor no Zabbix: " ZABBIX_HOSTNAME

if [ -z "$ZABBIX_HOSTNAME" ]; then
    error "O Hostname do Zabbix é obrigatório."
    exit 1
fi

# Removing spaces
ZABBIX_HOSTNAME="$(echo "$ZABBIX_HOSTNAME" | xargs)"

if [ -z "$ZABBIX_HOSTNAME" ]; then
    error "Hostname inválido."
    exit 1
fi

# ------------------------------------------------------------
# Summary
# ------------------------------------------------------------

echo
echo "============================================================"
echo "CONFIGURAÇÃO"
echo "============================================================"
echo
echo "Sistema       : $PRETTY_NAME"
echo "Zabbix Server : $ZABBIX_SERVER"
echo "Porta Server  : $ZABBIX_PORT"
echo "Hostname      : $ZABBIX_HOSTNAME"
echo "Agent         : Zabbix Agent 2"
echo

read -rp "Continuar com a instalação? [s/N]: " CONFIRM

if [[ ! "$CONFIRM" =~ ^[SsYy]$ ]]; then
    warning "Instalação cancelada."
    exit 0
fi

# ============================================================
# UBUNTU
# ============================================================

if [ "$OS_ID" = "ubuntu" ]; then

    case "$OS_VERSION" in

        18)
            UBUNTU_VERSION="18.04"
            ;;

        20)
            UBUNTU_VERSION="20.04"
            ;;

        22)
            UBUNTU_VERSION="22.04"
            ;;

        24)
            UBUNTU_VERSION="24.04"
            ;;

        26)
            UBUNTU_VERSION="26.04"
            ;;

        *)
            error "Versão Ubuntu não suportada pelo script: $VERSION_ID"
            exit 1
            ;;
    esac

    info "Ubuntu $UBUNTU_VERSION detectado."

    # --------------------------------------------------------
    # Removing hold settings Zabbix
    # --------------------------------------------------------

    info "Verificando repositórios Zabbix antigos..."

    find /etc/apt/sources.list.d/ \
        -type f \
        \( -name "*zabbix*.list" -o -name "*zabbix*.sources" \) \
        -delete 2>/dev/null || true

    # --------------------------------------------------------
    # Remove release package antigo
    # --------------------------------------------------------

    if dpkg-query -W -f='${Status}' zabbix-release 2>/dev/null | \
        grep -q "install ok installed"; then

        info "Removendo zabbix-release antigo..."

        apt-get remove -y zabbix-release || true
    fi

    # --------------------------------------------------------
    # Download repository
    # --------------------------------------------------------

    TEMP_DIR="$(mktemp -d)"

    cd "$TEMP_DIR"

    ZABBIX_REPO_URL="https://repo.zabbix.com/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest+ubuntu${UBUNTU_VERSION}_all.deb"

    info "Baixando repositório oficial:"
    echo "$ZABBIX_REPO_URL"

    if ! command -v wget >/dev/null 2>&1; then
        apt-get update
        apt-get install -y wget
    fi

    wget -q --show-progress "$ZABBIX_REPO_URL"

    REPO_PACKAGE="$(basename "$ZABBIX_REPO_URL")"

    dpkg -i "$REPO_PACKAGE"

    rm -rf "$TEMP_DIR"

    # --------------------------------------------------------
    # Update repositories
    # --------------------------------------------------------

    info "Atualizando repositórios APT..."

    apt-get update

    # --------------------------------------------------------
    # Install Agent 2
    # --------------------------------------------------------

    info "Instalando Zabbix Agent 2..."

    apt-get install -y zabbix-agent2

# ============================================================
# ALMALINUX
# ============================================================

elif [ "$OS_ID" = "almalinux" ]; then

    case "$OS_VERSION" in

        8)
            EL_VERSION="8"
            ;;

        9)
            EL_VERSION="9"
            ;;

        10)
            EL_VERSION="10"
            ;;

        *)
            error "Versão AlmaLinux não suportada: $VERSION_ID"
            exit 1
            ;;
    esac

    info "AlmaLinux $EL_VERSION detectado."

    ZABBIX_RELEASE_URL="https://repo.zabbix.com/zabbix/7.0/alma/${EL_VERSION}/x86_64/zabbix-release-latest-7.0.el${EL_VERSION}.noarch.rpm"

    info "Instalando repositório Zabbix:"
    echo "$ZABBIX_RELEASE_URL"

    rpm -Uvh --replacepkgs "$ZABBIX_RELEASE_URL"

    dnf clean all
    dnf makecache

    info "Instalando Zabbix Agent 2..."

    dnf install -y zabbix-agent2

# ============================================================
# CENTOS
# ============================================================

elif [ "$OS_ID" = "centos" ]; then

    case "$OS_VERSION" in

        8)
            EL_VERSION="8"
            ;;

        9)
            EL_VERSION="9"
            ;;

        10)
            EL_VERSION="10"
            ;;

        *)
            error "Versão CentOS não suportada: $VERSION_ID"
            echo
            echo "CentOS 7 não é tratado por este instalador."
            exit 1
            ;;
    esac

    info "CentOS $EL_VERSION detectado."

    ZABBIX_RELEASE_URL="https://repo.zabbix.com/zabbix/7.0/centos/${EL_VERSION}/x86_64/zabbix-release-latest-7.0.el${EL_VERSION}.noarch.rpm"

    info "Instalando repositório Zabbix:"
    echo "$ZABBIX_RELEASE_URL"

    rpm -Uvh --replacepkgs "$ZABBIX_RELEASE_URL"

    dnf clean all
    dnf makecache

    info "Instalando Zabbix Agent 2..."

    dnf install -y zabbix-agent2

else

    error "Sistema operacional não suportado: $PRETTY_NAME"
    exit 1

fi

# ============================================================
# CONFIGURATION
# ============================================================

echo
info "Configurando Zabbix Agent 2..."

if [ ! -f "$CONFIG_FILE" ]; then
    error "Arquivo de configuração não encontrado:"
    echo "$CONFIG_FILE"
    exit 1
fi

# ------------------------------------------------------------
# Backup
# ------------------------------------------------------------

BACKUP_FILE="${CONFIG_FILE}.backup.$(date +%Y%m%d-%H%M%S)"

cp "$CONFIG_FILE" "$BACKUP_FILE"

success "Backup criado:"
echo "$BACKUP_FILE"

# ------------------------------------------------------------
# Function to configure parameter
# ------------------------------------------------------------

set_parameter() {

    PARAMETER="$1"
    VALUE="$2"

    if grep -Eq "^[#[:space:]]*${PARAMETER}=" "$CONFIG_FILE"; then

        sed -i -E \
            "s|^[#[:space:]]*${PARAMETER}=.*|${PARAMETER}=${VALUE}|" \
            "$CONFIG_FILE"

    else

        echo "${PARAMETER}=${VALUE}" >> "$CONFIG_FILE"

    fi
}

# ------------------------------------------------------------
# Configure
# ------------------------------------------------------------

set_parameter "Server" "$ZABBIX_SERVER"
set_parameter "ServerActive" "${ZABBIX_SERVER}:${ZABBIX_PORT}"
set_parameter "Hostname" "$ZABBIX_HOSTNAME"

# ------------------------------------------------------------
# Show configuration
# ------------------------------------------------------------

echo
echo "============================================================"
echo "CONFIGURAÇÃO FINAL"
echo "============================================================"

grep -E "^(Server|ServerActive|Hostname)=" "$CONFIG_FILE"

echo "============================================================"
echo

# ============================================================
# FIREWALL
# ============================================================

info "Verificando firewall..."

# ------------------------------------------------------------
# UFW
# ------------------------------------------------------------

if command -v ufw >/dev/null 2>&1; then

    if ufw status 2>/dev/null | grep -q "Status: active"; then

        info "UFW está ativo."

        ufw allow from "$ZABBIX_SERVER" to any port "$AGENT_PORT" proto tcp

        success "Porta $AGENT_PORT liberada somente para $ZABBIX_SERVER."

    fi
fi

# ------------------------------------------------------------
# FIREWALLD
# ------------------------------------------------------------

if command -v firewall-cmd >/dev/null 2>&1; then

    if firewall-cmd --state 2>/dev/null | grep -q "running"; then

        info "firewalld está ativo."

        firewall-cmd --permanent \
            --add-rich-rule="rule family=\"ipv4\" source address=\"${ZABBIX_SERVER}\" port protocol=\"tcp\" port=\"${AGENT_PORT}\" accept"

        firewall-cmd --reload

        success "firewalld configurado para aceitar $AGENT_PORT somente de $ZABBIX_SERVER."

    fi
fi

# ============================================================
# SERVICE
# ============================================================

info "Ativando Zabbix Agent 2..."

systemctl enable zabbix-agent2

systemctl restart zabbix-agent2

sleep 3

# ============================================================
# SERVICE TEST
# ============================================================

if systemctl is-active --quiet zabbix-agent2; then

    success "Zabbix Agent 2 está em execução."

else

    error "Zabbix Agent 2 não iniciou corretamente."

    systemctl status zabbix-agent2 --no-pager

    echo
    echo "Verifique os logs:"
    echo "journalctl -u zabbix-agent2 -xe"

    exit 1
fi

# ============================================================
# PORT TEST
# ============================================================

echo
info "Verificando porta local 10050..."

if command -v ss >/dev/null 2>&1; then

    if ss -lnt | grep -q ":${AGENT_PORT} "; then
        success "Agent está escutando na porta $AGENT_PORT."
    else
        warning "A porta $AGENT_PORT não apareceu no socket."
    fi

fi

# ============================================================
# ZABBIX SERVER CONNECTIVITY
# ============================================================

echo
info "Testando conexão com Zabbix Server $ZABBIX_SERVER:$ZABBIX_PORT..."

if timeout 5 bash -c "</dev/tcp/${ZABBIX_SERVER}/${ZABBIX_PORT}" 2>/dev/null; then

    success "Conexão TCP com Zabbix Server:10051 OK."

else

    warning "Não foi possível estabelecer conexão TCP com $ZABBIX_SERVER:$ZABBIX_PORT."

    echo
    echo "Possíveis causas:"
    echo " - Firewall"
    echo " - Rota"
    echo " - IP do Zabbix Server incorreto"
    echo " - Porta 10051 bloqueada"
    echo " - Zabbix Server indisponível"

fi

# ============================================================
# FINAL
# ============================================================

echo
echo "============================================================"
echo "        INSTALAÇÃO CONCLUÍDA"
echo "============================================================"
echo
echo "Sistema       : $PRETTY_NAME"
echo "Agent         : Zabbix Agent 2"
echo "Zabbix Server : $ZABBIX_SERVER"
echo "Porta         : $ZABBIX_PORT"
echo "Hostname      : $ZABBIX_HOSTNAME"
echo
echo "Configuração  : $CONFIG_FILE"
echo
echo "IMPORTANTE:"
echo
echo "1. Crie/confirme este mesmo Hostname no frontend:"
echo
echo "   $ZABBIX_HOSTNAME"
echo
echo "2. Associe o template apropriado."
echo
echo "3. Para Active Checks, o Hostname deve ser exatamente igual."
echo
echo "4. O servidor deve conseguir comunicar com o Zabbix Server"
echo "   através da porta TCP 10051."
echo
echo "============================================================"
echo

exit 0
