#!/usr/bin/env node

/**
 * Maestro Setup Script
 * One-button installation for new users
 */

const { execSync } = require("child_process");
const fs = require("fs").promises;

const readline = require("readline");

// ANSI color codes
const colors = {
  reset: "\x1b[0m",
  red: "\x1b[0;31m",
  green: "\x1b[0;32m",
  yellow: "\x1b[1;33m",
  blue: "\x1b[0;34m",
};

// Helper functions for colored output
function printBanner() {
  console.log(`${colors.blue}
███╗   ███╗ █████╗ ███████╗███████╗████████╗██████╗  ██████╗
████╗ ████║██╔══██╗██╔════╝██╔════╝╚══██╔══╝██╔══██╗██╔═══██╗
██╔████╔██║███████║█████╗  ███████╗   ██║   ██████╔╝██║   ██║
██║╚██╔╝██║██╔══██║██╔══╝  ╚════██║   ██║   ██╔══██╗██║   ██║
██║ ╚═╝ ██║██║  ██║███████╗███████║   ██║   ██║  ██║╚██████╔╝
╚═╝     ╚═╝╚═╝  ╚═╝╚══════╝╚══════╝   ╚═╝   ╚═╝  ╚═╝ ╚═════╝
${colors.reset}`);
  console.log(`${colors.green}Welcome to Maestro Setup!${colors.reset}`);
  console.log(`${colors.blue}AI-Powered Development Platform${colors.reset}\n`);
}

function printStep(message) {
  console.log(
    `\n${colors.blue}==>${colors.reset} ${colors.green}${message}${colors.reset}`,
  );
}

function printError(message) {
  console.log(`${colors.red}ERROR:${colors.reset} ${message}`);
}

function printWarning(message) {
  console.log(`${colors.yellow}WARNING:${colors.reset} ${message}`);
}

function printSuccess(message) {
  console.log(`${colors.green}✓${colors.reset} ${message}`);
}

// Helper to run shell commands
function runCommand(command, options = {}) {
  try {
    return execSync(command, {
      encoding: "utf8",
      stdio: options.silent ? "pipe" : "inherit",
      ...options,
    });
  } catch (error) {
    if (options.ignoreError) {
      return null;
    }
    throw error;
  }
}

// Helper to check if command exists
function commandExists(command) {
  try {
    const isWindows = process.platform === "win32";
    const checkCmd = isWindows ? `where ${command}` : `which ${command}`;
    runCommand(checkCmd, { silent: true });
    return true;
  } catch {
    return false;
  }
}

// Helper to get command version
function getCommandVersion(command, versionFlag = "--version") {
  try {
    const output = runCommand(`${command} ${versionFlag}`, { silent: true });
    return output.trim();
  } catch {
    return "unknown";
  }
}

// Async readline question helper
function question(query) {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });

  return new Promise((resolve) => {
    rl.question(query, (answer) => {
      rl.close();
      resolve(answer);
    });
  });
}

// Check prerequisites
async function checkPrerequisites() {
  printStep("Checking prerequisites...");

  // Check Node.js
  if (!commandExists("node")) {
    printError(
      "Node.js is not installed. Please install Node.js >= 14.0.0 from https://nodejs.org/",
    );
    process.exit(1);
  }

  const nodeVersion = process.version.slice(1).split(".")[0];
  if (parseInt(nodeVersion) < 14) {
    printError(
      "Node.js version is too old. Please upgrade to Node.js >= 14.0.0",
    );
    process.exit(1);
  }
  printSuccess(`Node.js ${process.version} detected`);

  // Check npm
  if (!commandExists("npm")) {
    printError("npm is not installed. Please install npm.");
    process.exit(1);
  }
  const npmVersion = getCommandVersion("npm", "-v");
  printSuccess(`npm ${npmVersion} detected`);

  // Check Git
  if (!commandExists("git")) {
    printError(
      "Git is not installed. Please install Git from https://git-scm.com/",
    );
    process.exit(1);
  }
  const gitVersion = getCommandVersion("git", "--version").split(" ")[2];
  printSuccess(`Git ${gitVersion} detected`);

  // Check GitHub CLI
  if (!commandExists("gh")) {
    printError(
      "GitHub CLI (gh) is not installed. Please install it from https://cli.github.com/",
    );
    process.exit(1);
  }
  const ghVersion = getCommandVersion("gh", "--version").split("\n")[0];
  printSuccess(`${ghVersion} detected`);

  // Check gh auth status
  try {
    const authStatus = runCommand("gh auth status", { silent: true });
    printSuccess("GitHub CLI is authenticated");
  } catch {
    printWarning(
      "GitHub CLI is not authenticated. Run 'gh auth login' and select SSH for git protocol.",
    );
  }

  // Check Claude Code (optional)
  if (!commandExists("claude")) {
    printWarning(
      "Claude Code CLI not found. Maestro works best with Claude Code installed.",
    );
    console.log("          Visit: https://claude.com/claude-code");
  } else {
    printSuccess("Claude Code CLI detected");
  }
}

// Install npm dependencies
async function installDependencies() {
  printStep("Installing npm dependencies...");
  try {
    runCommand("npm install");
    printSuccess("Dependencies installed");
  } catch (error) {
    printError("Failed to install dependencies");
    throw error;
  }
}

// Initialize git submodules
async function initializeSubmodules() {
  printStep("Initializing git submodules (project repositories)...");

  try {
    await fs.access(".gitmodules");
    runCommand("git submodule update --init --recursive");
    printSuccess("Submodules initialized");
  } catch {
    printWarning(
      "No .gitmodules file found. Skipping submodule initialization.",
    );
  }
}

// Create personal directories
async function createPersonalDirs() {
  printStep("Creating personal directories...");
  for (const dir of ["docs", "memories", "projects", "todos"]) {
    await fs.mkdir(`${dir}/personal`, { recursive: true });
    printSuccess(`${dir}/personal created`);
  }
}

// Setup environment variables
async function setupEnvironment() {
  printStep("Configuring environment variables...");

  const envPath = ".env";
  let shouldSetup = true;

  try {
    await fs.access(envPath);
    printWarning(".env file already exists. Skipping environment setup.");
    const reconfigure = await question("Do you want to reconfigure? (y/N): ");

    if (reconfigure.toLowerCase() === "y") {
      await fs.unlink(envPath);
    } else {
      console.log("Skipping environment configuration.");
      shouldSetup = false;
    }
  } catch {
    // File doesn't exist, proceed with setup
  }

  if (shouldSetup) {
    console.log(
      `\n${colors.yellow}Please provide your configuration details:${colors.reset}`,
    );

    // User information
    const userName = await question("Your full name: ");
    const userEmail = await question("Your Github email: ");

    // Create .env file
    const envContent = `# User Information
YOUR_NAME="${userName}"
YOUR_EMAIL="${userEmail}"

# Atlassian/Jira Configuration (fill these in to enable Jira/Confluence integrations)
ATLASSIAN_EMAIL=""
ATLASSIAN_API_TOKEN=""
ATLASSIAN_DOMAIN=""
`;

    printWarning(
      "Update .env with your Atlassian credentials to enable Jira/Confluence integrations.",
    );

    await fs.writeFile(envPath, envContent);
    printSuccess(".env file created");
  }
}

// Verify setup
async function verifySetup() {
  printStep("Verifying setup...");

  let checksPassed = true;

  // Check if .env exists
  try {
    await fs.access(".env");
    printSuccess(".env file exists");
  } catch {
    printError(".env file not found");
    checksPassed = false;
  }

  // Check if package.json exists
  try {
    await fs.access("package.json");
    printSuccess("package.json exists");
  } catch {
    printError("package.json not found");
    checksPassed = false;
  }

  // Check if node_modules exists
  try {
    await fs.access("node_modules");
    printSuccess("node_modules directory exists");
  } catch {
    printError("node_modules directory not found");
    checksPassed = false;
  }

  // Check if .claude directory exists
  try {
    await fs.access(".claude");
    printSuccess(".claude configuration directory exists");
  } catch {
    printError(".claude directory not found");
    checksPassed = false;
  }

  // Check if key directories exist
  for (const dir of ["projects", "memories"]) {
    try {
      await fs.access(dir);
      printSuccess(`${dir} directory exists`);
    } catch {
      printError(`${dir} directory not found`);
      checksPassed = false;
    }
  }

  return checksPassed;
}

// Display final summary
function displaySummary(checksPassed) {
  console.log(
    `\n${colors.blue}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${colors.reset}`,
  );

  if (checksPassed) {
    console.log(
      `${colors.green}✓ Setup completed successfully!${colors.reset}\n`,
    );

    console.log(`${colors.yellow}Next steps:${colors.reset}`);
    console.log("1. Review your .env file and update any placeholders");
    console.log(
      "2. Configure MCP servers in .mcp.json (if using Jira/Confluence)",
    );
    console.log("3. Start Claude Code in this directory");
    console.log("4. Try running: /help to see available commands");

    console.log(`\n${colors.blue}Documentation:${colors.reset}`);
    console.log("  • CLAUDE.md        - AI context and configuration");
    console.log("  • README.md        - Usage and workflows");
    console.log("  • .claude/commands/ - Available slash commands");
    console.log("  • .claude/agents/   - Specialized agents");
    console.log("  • .claude/skills/   - Domain-specific skills");
    console.log(`\n${colors.green}Happy coding with Maestro!${colors.reset}`);
  } else {
    console.log(`${colors.red}✗ Setup completed with errors${colors.reset}`);
    console.log(
      "Please review the errors above and run the setup script again.",
    );
    process.exit(1);
  }

  console.log(
    `${colors.blue}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${colors.reset}\n`,
  );
}

// Main setup function
async function main() {
  try {
    printBanner();
    await checkPrerequisites();
    await installDependencies();
    await initializeSubmodules();
    await createPersonalDirs();

    await setupEnvironment();
    const checksPassed = await verifySetup();
    displaySummary(checksPassed);
  } catch (error) {
    printError(`Setup failed: ${error.message}`);
    process.exit(1);
  }
}

// Run the setup
main();
