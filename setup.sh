#!/bin/bash

# Maestro Setup Script
# One-button installation for new users

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Banner
echo -e "${BLUE}"
cat << "EOF"
███╗   ███╗ █████╗ ███████╗███████╗████████╗██████╗  ██████╗
████╗ ████║██╔══██╗██╔════╝██╔════╝╚══██╔══╝██╔══██╗██╔═══██╗
██╔████╔██║███████║█████╗  ███████╗   ██║   ██████╔╝██║   ██║
██║╚██╔╝██║██╔══██║██╔══╝  ╚════██║   ██║   ██╔══██╗██║   ██║
██║ ╚═╝ ██║██║  ██║███████╗███████║   ██║   ██║  ██║╚██████╔╝
╚═╝     ╚═╝╚═╝  ╚═╝╚══════╝╚══════╝   ╚═╝   ╚═╝  ╚═╝ ╚═════╝
EOF
echo -e "${NC}"
echo -e "${GREEN}Welcome to Maestro Setup!${NC}"
echo -e "${BLUE}AI-Powered Development Platform${NC}\n"

# Helper functions
print_step() {
    echo -e "\n${BLUE}==>${NC} ${GREEN}$1${NC}"
}

print_error() {
    echo -e "${RED}ERROR:${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}WARNING:${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

# Check prerequisites
print_step "Checking prerequisites..."

# Check Node.js
if ! command -v node &> /dev/null; then
    print_error "Node.js is not installed. Please install Node.js >= 14.0.0 from https://nodejs.org/"
    exit 1
fi

NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 14 ]; then
    print_error "Node.js version is too old. Please upgrade to Node.js >= 14.0.0"
    exit 1
fi
print_success "Node.js $(node -v) detected"

# Check npm
if ! command -v npm &> /dev/null; then
    print_error "npm is not installed. Please install npm."
    exit 1
fi
print_success "npm $(npm -v) detected"

# Check Git
if ! command -v git &> /dev/null; then
    print_error "Git is not installed. Please install Git from https://git-scm.com/"
    exit 1
fi
print_success "Git $(git --version | cut -d' ' -f3) detected"

# Check GitHub CLI
if ! command -v gh &> /dev/null; then
    print_error "GitHub CLI (gh) is not installed. Please install it from https://cli.github.com/"
    exit 1
fi
print_success "$(gh --version | head -1) detected"

# Check gh auth status
if gh auth status &> /dev/null; then
    print_success "GitHub CLI is authenticated"
else
    print_warning "GitHub CLI is not authenticated. Run 'gh auth login' and select SSH for git protocol."
fi

# Check Claude Code (optional but recommended)
if ! command -v claude &> /dev/null; then
    print_warning "Claude Code CLI not found. Maestro works best with Claude Code installed."
    echo "          Visit: https://claude.com/claude-code"
else
    print_success "Claude Code CLI detected"
fi

# Install npm dependencies
print_step "Installing npm dependencies..."
npm install
print_success "Dependencies installed"

# Initialize git submodules
print_step "Initializing git submodules (project repositories)..."
if [ -f .gitmodules ]; then
    git submodule update --init --recursive
    print_success "Submodules initialized"
else
    print_warning "No .gitmodules file found. Skipping submodule initialization."
fi

# Create personal directories
print_step "Creating personal directories..."
for dir in docs memories projects todos; do
    mkdir -p "$dir/personal"
    print_success "$dir/personal created"
done

# Setup environment variables
print_step "Configuring environment variables..."

if [ -f .env ]; then
    print_warning ".env file already exists. Skipping environment setup."
    read -p "Do you want to reconfigure? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Skipping environment configuration."
    else
        rm .env
    fi
fi

if [ ! -f .env ]; then
    echo -e "\n${YELLOW}Please provide your configuration details:${NC}"

    # User information
    read -p "Your full name: " USER_NAME
    read -p "Your Github email: " USER_EMAIL

    # Create .env file
    cat > .env << EOF
# User Information
YOUR_NAME="$USER_NAME"
YOUR_EMAIL="$USER_EMAIL"

# Atlassian/Jira Configuration (fill these in to enable Jira/Confluence integrations)
ATLASSIAN_EMAIL=""
ATLASSIAN_API_TOKEN=""
ATLASSIAN_DOMAIN=""
EOF

    print_warning "Update .env with your Atlassian credentials to enable Jira/Confluence integrations."

    print_success ".env file created"
fi

# Verify setup
print_step "Verifying setup..."

CHECKS_PASSED=true

# Check if .env exists
if [ ! -f .env ]; then
    print_error ".env file not found"
    CHECKS_PASSED=false
else
    print_success ".env file exists"
fi

# Check if package.json exists
if [ ! -f package.json ]; then
    print_error "package.json not found"
    CHECKS_PASSED=false
else
    print_success "package.json exists"
fi

# Check if node_modules exists
if [ ! -d node_modules ]; then
    print_error "node_modules directory not found"
    CHECKS_PASSED=false
else
    print_success "node_modules directory exists"
fi

# Check if .claude directory exists
if [ ! -d .claude ]; then
    print_error ".claude directory not found"
    CHECKS_PASSED=false
else
    print_success ".claude configuration directory exists"
fi

# Check if key directories exist
for dir in projects memories; do
    if [ ! -d "$dir" ]; then
        print_error "$dir directory not found"
        CHECKS_PASSED=false
    else
        print_success "$dir directory exists"
    fi
done

# Final summary
echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
if [ "$CHECKS_PASSED" = true ]; then
    echo -e "${GREEN}✓ Setup completed successfully!${NC}\n"

    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Review your .env file and update any placeholders"
    echo "2. Configure MCP servers in .mcp.json (if using Jira/Confluence)"
    echo "3. Start Claude Code in this directory"
    echo "4. Try running: /help to see available commands"
    echo -e "\n${BLUE}Documentation:${NC}"
    echo "  • CLAUDE.md        - AI context and configuration"
    echo "  • README.md        - Usage and workflows"
    echo "  • .claude/commands/ - Available slash commands"
    echo "  • .claude/agents/   - Specialized agents"
    echo "  • .claude/skills/   - Domain-specific skills"
    echo -e "\n${GREEN}Happy coding with Maestro!${NC}"
else
    echo -e "${RED}✗ Setup completed with errors${NC}"
    echo "Please review the errors above and run the setup script again."
    exit 1
fi

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
