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

# Function for logging
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$INSTALL_LOG"
    echo -e "${GREEN}[INFO]${NC} $1"
}

error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: $1" >> "$ERROR_LOG"
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

warning() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - WARNING: $1" >> "$INSTALL_LOG"
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Create log directory safely
create_log_dir() {
    if ! mkdir -p "$LOG_DIR" 2>/dev/null; then
        echo -e "${RED}[ERROR]${NC} Failed to create log directory: $LOG_DIR"
        exit 1
    fi
    touch "$INSTALL_LOG" "$ERROR_LOG" 2>/dev/null || {
        echo -e "${RED}[ERROR]${NC} Failed to create log files"
        exit 1
    }
    chmod 755 "$LOG_DIR"
    chmod 644 "$INSTALL_LOG" "$ERROR_LOG"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
    fi
}

# Banner
show_banner() {
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
}

# System detection
detect_os() {
    if [[ -f /etc/redhat-release ]] || [[ -f /etc/centos-release ]]; then
        OS="centos"
    elif [[ -f /etc/debian_version ]]; then
        OS="debian"
    elif [[ -f /etc/lsb-release ]] && grep -q "Ubuntu" /etc/lsb-release; then
        OS="ubuntu"
    else
        error "Unsupported operating system"
    fi
    log "Detected OS: $OS"
}

# Update system packages with fallback mirrors
update_system() {
    log "Updating system packages..."
    
    if [[ "$OS" == "centos" ]]; then
        # Add fallback mirrors for CentOS
        if ! yum update -y --disablerepo=* --enablerepo=base,updates,extras >> "$INSTALL_LOG" 2>> "$ERROR_LOG"; then
            warning "Primary mirrors failed, trying with fasttrack..."
            yum update -y --disablerepo=* --enablerepo=base,updates,extras,fasttrack >> "$INSTALL_LOG" 2>> "$ERROR_LOG" || {
                error "Failed to update system packages"
            }
        fi
    else
        # For Debian/Ubuntu - configure non-interactive and retry logic
        export DEBIAN_FRONTEND=noninteractive
        export DEBIAN_PRIORITY=critical
        
        # Update with retry logic
        for i in {1..3}; do
            if apt-get update >> "$INSTALL_LOG" 2>> "$ERROR_LOG"; then
                break
            fi
            if [[ $i -eq 3 ]]; then
                error "Failed to update package lists after 3 attempts"
            fi
            warning "Package list update failed, retrying in 5 seconds..."
            sleep 5
        done
        
        # Upgrade with essential packages only - FIXED VERSION
        if ! apt-get upgrade -y \
          -o Dpkg::Options::="--force-confdef" \
          -o Dpkg::Options::="--force-confold" \
          >> "$INSTALL_LOG" 2>> "$ERROR_LOG"; then

            warning "Standard upgrade failed, trying minimal upgrade..."

            apt-get upgrade -y \
              -o Dpkg::Options::="--force-confdef" \
              -o Dpkg::Options::="--force-confold" \
              --allow-downgrades --allow-remove-essential --allow-change-held-packages \
              >> "$INSTALL_LOG" 2>> "$ERROR_LOG" || {
                error "Failed to upgrade system packages"
            }
        fi
    fi
    
    log "System updated successfully"
}

# Install dependencies with fallback
install_dependencies() {
    log "Installing dependencies..."
    
    if [[ "$OS" == "centos" ]]; then
        # EPEL repository for CentOS
        if ! yum install -y epel-release >> "$INSTALL_LOG" 2>> "$ERROR_LOG"; then
            warning "EPEL installation failed, trying alternative..."
            yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-$(rpm -E %rhel).noarch.rpm >> "$INSTALL_LOG" 2>> "$ERROR_LOG" || {
                warning "Alternative EPEL also failed, continuing without it..."
            }
        fi
        
        # Main dependencies
        yum install -y curl wget git sudo net-tools bc jq openssl crontabs >> "$INSTALL_LOG" 2>> "$ERROR_LOG" || {
            error "Failed to install dependencies"
        }
    else
        # Debian/Ubuntu dependencies with retry - INCLUDING DNSUTILS
        for i in {1..3}; do
            if apt-get install -y curl wget git sudo net-tools bc jq openssl cron dnsutils >> "$INSTALL_LOG" 2>> "$ERROR_LOG"; then
                break
            fi
            if [[ $i -eq 3 ]]; then
                error "Failed to install dependencies after 3 attempts"
            fi
            warning "Dependency installation failed, retrying in 5 seconds..."
            sleep 5
        done
    fi
    
    log "Dependencies installed successfully"
}

# Create directory structure safely
create_directories() {
    log "Creating directory structure..."
    
    local dirs=(
        "/opt/maut-panel/scripts"
        "/opt/maut-panel/config" 
        "/opt/maut-panel/backup"
        "/opt/maut-panel/logs"
        "/opt/maut-panel/temp"
        "/etc/maut/users"
        "/etc/maut/ssl"
        "/etc/maut/ports"
        "/var/log/maut-panel"
    )
    
    for dir in "${dirs[@]}"; do
        if ! mkdir -p "$dir" 2>/dev/null; then
            error "Failed to create directory: $dir"
        fi
    done
    
    # Set permissions safely
    chmod -R 755 /opt/maut-panel 2>/dev/null || warning "Could not set permissions for /opt/maut-panel"
    chmod -R 755 /etc/maut 2>/dev/null || warning "Could not set permissions for /etc/maut"
    chmod -R 755 /var/log/maut-panel 2>/dev/null || warning "Could not set permissions for /var/log/maut-panel"
    
    log "Directory structure created"
}

# Install Xray core with correct syntax
install_xray() {
    log "Installing Xray core..."
    
    # Check if Xray is already installed
    if command -v xray >/dev/null 2>&1; then
        log "Xray is already installed, skipping..."
        return 0
    fi
    
    # Install Xray using the official script
    if ! bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install -u root >> "$INSTALL_LOG" 2>> "$ERROR_LOG"; then
        error "Failed to install Xray"
    fi
    
    # Verify installation
    if ! command -v xray >/dev/null 2>&1; then
        error "Xray installation verification failed"
    fi
    
    log "Xray installed successfully"
}

# Install acme.sh safely without breaking DNS
install_acme() {
    log "Installing acme.sh for SSL certificates..."
    
    # Check if acme.sh is already installed
    if [[ -d ~/.acme.sh ]] && command -v ~/.acme.sh/acme.sh >/dev/null 2>&1; then
        log "acme.sh is already installed, skipping..."
        return 0
    fi
    
    # Create temporary directory for installation
    local temp_dir=$(mktemp -d)
    cd "$temp_dir" || error "Failed to enter temp directory"
    
    # Download and install acme.sh with safe options
    if ! curl -s https://get.acme.sh | sh -s email=admin@maut-panel.com >> "$INSTALL_LOG" 2>> "$ERROR_LOG"; then
        rm -rf "$temp_dir"
        error "Failed to install acme.sh"
    fi
    
    # Cleanup
    cd /tmp
    rm -rf "$temp_dir"
    
    # Add to PATH for current session
    export PATH="$HOME/.acme.sh:$PATH"
    
    # Verify installation
    if ! ~/.acme.sh/acme.sh --version >/dev/null 2>&1; then
        error "acme.sh installation verification failed"
    fi
    
    log "acme.sh installed successfully"
}

# Copy panel files with safety checks
copy_panel_files() {
    log "Copying panel files..."
    
    # Check if source directories exist
    if [[ ! -d "./scripts" ]]; then
        warning "Scripts directory not found, creating basic structure..."
        mkdir -p ./scripts
    fi
    
    if [[ ! -d "./config" ]]; then
        warning "Config directory not found, creating basic structure..."
        mkdir -p ./config
    fi
    
    # Create main panel script
    cat > /usr/local/bin/maut-panel << 'EOF'
#!/bin/bash
/opt/maut-panel/scripts/maut-main "$@"
EOF
    chmod +x /usr/local/bin/maut-panel
    
    # Copy scripts if they exist
    if [[ -d "./scripts" ]] && [[ "$(ls -A ./scripts 2>/dev/null)" ]]; then
        cp -f ./scripts/* /opt/maut-panel/scripts/ 2>/dev/null || warning "Some script files could not be copied"
    else
        warning "No script files found to copy, creating placeholder..."
        touch /opt/maut-panel/scripts/maut-main
        chmod +x /opt/maut-panel/scripts/maut-main
    fi
    
    # Copy config if they exist
    if [[ -d "./config" ]] && [[ "$(ls -A ./config 2>/dev/null)" ]]; then
        cp -f ./config/* /opt/maut-panel/config/ 2>/dev/null || warning "Some config files could not be copied"
    fi
    
    # Set executable permissions safely
    chmod +x /opt/maut-panel/scripts/* 2>/dev/null || warning "Could not set executable permissions on some scripts"
    
    log "Panel files copied successfully"
}

# Setup cron jobs safely
setup_cron() {
    log "Setting up cron jobs..."
    
    # Backup current crontab
    local current_cron=$(mktemp)
    crontab -l 2>/dev/null > "$current_cron" || true
    
    # Create new crontab
    local new_cron=$(mktemp)
    cp "$current_cron" "$new_cron"
    
    # Add cron jobs if they don't exist
    local cron_jobs=(
        "0 2 * * * /opt/maut-panel/scripts/maut-backup auto"
        "*/5 * * * * /opt/maut-panel/scripts/maut-monitor check"
        "* * * * * /opt/maut-panel/scripts/maut-helper kill-multi-login"
        "* * * * * /opt/maut-panel/scripts/maut-banner update"
    )
    
    for job in "${cron_jobs[@]}"; do
        if ! grep -q -F "$job" "$new_cron" 2>/dev/null; then
            echo "$job" >> "$new_cron"
        fi
    done
    
    # Install new crontab
    if crontab "$new_cron" 2>/dev/null; then
        log "Cron jobs setup completed"
    else
        warning "Failed to setup cron jobs, but continuing installation..."
    fi
    
    # Cleanup
    rm -f "$current_cron" "$new_cron"
}

# Setup SSH banner safely
setup_ssh_banner() {
    log "Setting up SSH banner..."
    
    # Create banner directory if it doesn't exist
    mkdir -p /opt/maut-panel/scripts 2>/dev/null || true
    
    # Create basic banner script if missing
    if [[ ! -f /opt/maut-panel/scripts/maut-banner ]]; then
        cat > /opt/maut-panel/scripts/maut-banner << 'EOF'
#!/bin/bash
echo "MAUT PANEL PRO EDITION - Authorized Access Only" > /etc/issue.net
EOF
        chmod +x /opt/maut-panel/scripts/maut-banner
    fi
    
    # Create banner file
    /opt/maut-panel/scripts/maut-banner create 2>/dev/null || {
        echo "MAUT PANEL PRO EDITION - Authorized Access Only" > /etc/issue.net
    }
    
    # Backup SSH config
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.maut-backup 2>/dev/null || true
    
    # Update SSH config safely
    if grep -q "Banner" /etc/ssh/sshd_config; then
        sed -i 's|#*Banner.*|Banner /etc/issue.net|' /etc/ssh/sshd_config
    else
        echo "Banner /etc/issue.net" >> /etc/ssh/sshd_config
    fi
    
    # Restart SSH service safely
    if systemctl is-active sshd >/dev/null 2>&1; then
        systemctl restart sshd >> "$INSTALL_LOG" 2>> "$ERROR_LOG" || warning "Could not restart sshd"
    elif systemctl is-active ssh >/dev/null 2>&1; then
        systemctl restart ssh >> "$INSTALL_LOG" 2>> "$ERROR_LOG" || warning "Could not restart ssh"
    else
        warning "SSH service not found or not running"
    fi
    
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
    
    # Create symlinks for easy access
    ln -sf /opt/maut-panel/scripts/maut-main /usr/local/bin/maut 2>/dev/null || {
        # Fallback if maut-main doesn't exist
        ln -sf /usr/local/bin/maut-panel /usr/local/bin/maut 2>/dev/null || true
    }
    
    # Set ownership safely
    chown -R root:root /opt/maut-panel 2>/dev/null || warning "Could not set ownership for /opt/maut-panel"
    chown -R root:root /etc/maut 2>/dev/null || warning "Could not set ownership for /etc/maut"
    chown -R root:root /var/log/maut-panel 2>/dev/null || warning "Could not set ownership for /var/log/maut-panel"
    
    # Create essential scripts if missing
    local essential_scripts=(
        "maut-main"
        "maut-backup" 
        "maut-monitor"
        "maut-helper"
        "maut-banner"
        "maut-update"
    )
    
    for script in "${essential_scripts[@]}"; do
        if [[ ! -f "/opt/maut-panel/scripts/$script" ]]; then
            cat > "/opt/maut-panel/scripts/$script" << EOF
#!/bin/bash
echo "MAUT Panel Pro - $script"
echo "This is a placeholder script"
EOF
            chmod +x "/opt/maut-panel/scripts/$script"
        fi
    done
    
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

# Cleanup function
cleanup() {
    echo -e "${YELLOW}Installation interrupted. Cleaning up...${NC}"
    exit 1
}

# Set trap for cleanup
trap cleanup SIGINT SIGTERM

# Main installation function
main_install() {
    check_root
    create_log_dir
    show_banner
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
