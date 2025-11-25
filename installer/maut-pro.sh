#!/bin/bash

# MAUT PANEL PRO EDITION - AUTO INSTALLER
# Owner: @maut_coder
# Powered by MAUT CODER

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging setup
LOG_DIR="/var/log/maut-panel"
INSTALL_LOG="$LOG_DIR/maut-install.log"
ERROR_LOG="$LOG_DIR/maut-error.log"

# Create log directory
mkdir -p "$LOG_DIR"
touch "$INSTALL_LOG"
touch "$ERROR_LOG"

# Function for logging
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$INSTALL_LOG"
    echo -e "${GREEN}[INFO]${NC} $1"
}

error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: $1" >> "$ERROR_LOG"
    echo -e "${RED}[ERROR]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root"
    exit 1
fi

# Banner
clear
echo -e "${PURPLE}"
echo " ███╗   ███╗ █████╗ ██╗   ██╗████████╗"
echo " ████╗ ████║██╔══██╗██║   ██║╚══██╔══╝"
echo " ██╔████╔██║███████║██║   ██║   ██║   "
echo " ██║╚██╔╝██║██╔══██║██║   ██║   ██║   "
echo " ██║ ╚═╝ ██║██║  ██║╚██████╔╝   ██║   "
echo " ╚═╝     ╚═╝╚═╝  ╚═╝ ╚═════╝    ╚═╝   "
echo -e "${CYAN}"
echo "    PANEL PRO EDITION - INSTALLER"
echo "      Powered by MAUT CODER"
echo -e "${NC}"
echo "========================================"

# System detection
detect_os() {
    if [[ -f /etc/redhat-release ]]; then
        OS="centos"
    elif [[ -f /etc/debian_version ]]; then
        OS="debian"
    elif [[ -f /etc/ubuntu_version ]]; then
        OS="ubuntu"
    else
        error "Unsupported operating system"
        exit 1
    fi
    log "Detected OS: $OS"
}

# Update system packages
update_system() {
    log "Updating system packages..."
    if [[ "$OS" == "centos" ]]; then
        yum update -y >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
    else
        apt-get update && apt-get upgrade -y >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
    fi
    
    if [ $? -eq 0 ]; then
        log "System updated successfully"
    else
        error "Failed to update system"
        exit 1
    fi
}

# Install dependencies
install_dependencies() {
    log "Installing dependencies..."
    if [[ "$OS" == "centos" ]]; then
        yum install -y curl wget git sudo net-tools bc jq openssl >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
    else
        apt-get install -y curl wget git sudo net-tools bc jq openssl >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
    fi
    
    if [ $? -eq 0 ]; then
        log "Dependencies installed successfully"
    else
        error "Failed to install dependencies"
        exit 1
    fi
}

# Create directory structure
create_directories() {
    log "Creating directory structure..."
    mkdir -p /opt/maut-panel/{scripts,config,backup,logs,temp}
    mkdir -p /etc/maut/{users,ssl,ports}
    mkdir -p /var/log/maut-panel
    
    # Set permissions
    chmod -R 755 /opt/maut-panel
    chmod -R 755 /etc/maut
    chmod -R 755 /var/log/maut-panel
    
    log "Directory structure created"
}

# Install Xray core
install_xray() {
    log "Installing Xray core..."
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
    
    if [ $? -eq 0 ]; then
        log "Xray installed successfully"
    else
        error "Failed to install Xray"
        exit 1
    fi
}

# Install acme.sh for SSL
install_acme() {
    log "Installing acme.sh for SSL certificates..."
    curl https://get.acme.sh | sh >> "$INSTALL_LOG" 2>> "$ERROR_LOG"
    
    if [ $? -eq 0 ]; then
        log "acme.sh installed successfully"
    else
        error "Failed to install acme.sh"
        exit 1
    fi
}

# Copy panel files
copy_panel_files() {
    log "Copying panel files..."
    
    # Create main panel script
    cat > /usr/local/bin/maut-panel << 'EOF'
#!/bin/bash
/opt/maut-panel/scripts/maut-main
EOF
    chmod +x /usr/local/bin/maut-panel
    
    # Copy all script files (they will be created in subsequent parts)
    cp -f ./scripts/* /opt/maut-panel/scripts/
    cp -f ./config/* /opt/maut-panel/config/
    
    # Set executable permissions
    chmod +x /opt/maut-panel/scripts/*
    
    log "Panel files copied successfully"
}

# Setup cron jobs
setup_cron() {
    log "Setting up cron jobs..."
    
    # Auto backup every day at 2 AM
    (crontab -l 2>/dev/null; echo "0 2 * * * /opt/maut-panel/scripts/maut-backup auto") | crontab -
    
    # Monitor every 5 minutes
    (crontab -l 2>/dev/null; echo "*/5 * * * * /opt/maut-panel/scripts/maut-monitor check") | crontab -
    
    # Auto kill multi-login every minute
    (crontab -l 2>/dev/null; echo "* * * * * /opt/maut-panel/scripts/maut-helper kill-multi-login") | crontab -
    
    # Update banner every minute
    (crontab -l 2>/dev/null; echo "* * * * * /opt/maut-panel/scripts/maut-banner update") | crontab -
    
    log "Cron jobs setup completed"
}

# Setup SSH banner
setup_ssh_banner() {
    log "Setting up SSH banner..."
    
    # Create banner file
    /opt/maut-panel/scripts/maut-banner create
    
    # Update SSH config
    if grep -q "Banner" /etc/ssh/sshd_config; then
        sed -i 's|#*Banner.*|Banner /etc/issue.net|' /etc/ssh/sshd_config
    else
        echo "Banner /etc/issue.net" >> /etc/ssh/sshd_config
    fi
    
    # Restart SSH service
    systemctl restart sshd || systemctl restart ssh
    log "SSH banner configured"
}

# Initialize default configuration
init_config() {
    log "Initializing default configuration..."
    
    # Default theme
    cat > /opt/maut-panel/config/maut-theme.conf << 'EOF'
THEME_NAME="default"
COLOR_PRIMARY="\033[0;31m"
COLOR_SECONDARY="\033[0;33m"
COLOR_ACCENT="\033[0;36m"
COLOR_SUCCESS="\033[0;32m"
COLOR_WARNING="\033[1;33m"
COLOR_ERROR="\033[0;31m"
COLOR_INFO="\033[0;34m"
COLOR_RESET="\033[0m"
EOF

    # Default ports
    cat > /opt/maut-panel/config/maut-ports.conf << 'EOF'
SSH_PORT=22
VMESS_PORT=8443
VLESS_PORT=2083
TROJAN_PORT=2087
SHADOWSOCKS_PORT=8444
EOF

    # Empty users database
    touch /opt/maut-panel/config/maut-users.db
    chmod 600 /opt/maut-panel/config/maut-users.db
    
    log "Default configuration initialized"
}

# Final setup and permissions
final_setup() {
    log "Finalizing installation..."
    
    # Create symlink for easy access
    ln -sf /opt/maut-panel/scripts/maut-main /usr/local/bin/maut
    
    # Set ownership
    chown -R root:root /opt/maut-panel
    chown -R root:root /etc/maut
    chown -R root:root /var/log/maut-panel
    
    # Create update script
    cat > /opt/maut-panel/scripts/maut-update << 'EOF'
#!/bin/bash
echo "MAUT Panel Update Script"
echo "This will be implemented in the update script"
EOF
    chmod +x /opt/maut-panel/scripts/maut-update
    
    log "Final setup completed"
}

# Display installation summary
show_summary() {
    clear
    echo -e "${GREEN}"
    echo "╔════════════════════════════════════════╗"
    echo "║        MAUT PANEL PRO INSTALLED       ║"
    echo "║            SUCCESSFULLY!              ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    echo -e "${CYAN}INSTALLATION SUMMARY:${NC}"
    echo -e "${GREEN}✓${NC} System updated"
    echo -e "${GREEN}✓${NC} Dependencies installed"
    echo -e "${GREEN}✓${NC} Xray core installed"
    echo -e "${GREEN}✓${NC} SSL manager (acme.sh) installed"
    echo -e "${GREEN}✓${NC} Directory structure created"
    echo -e "${GREEN}✓${NC} Panel files copied"
    echo -e "${GREEN}✓${NC} Cron jobs configured"
    echo -e "${GREEN}✓${NC} SSH banner setup"
    echo -e "${GREEN}✓${NC} Default configuration initialized"
    echo ""
    echo -e "${YELLOW}USAGE:${NC}"
    echo -e "  Run the panel: ${GREEN}maut-panel${NC} or ${GREEN}maut${NC}"
    echo ""
    echo -e "${PURPLE}MAUT PANEL PRO - Powered by MAUT CODER${NC}"
    echo -e "${BLUE}Owner: @maut_coder${NC}"
    echo ""
    
    log "Installation completed successfully"
}

# Main installation function
main_install() {
    detect_os
    update_system
    install_dependencies
    create_directories
    install_xray
    install_acme
    copy_panel_files
    setup_cron
    setup_ssh_banner
    init_config
    final_setup
    show_summary
}

# Start installation
main_install
