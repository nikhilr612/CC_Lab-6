#!/bin/bash

# =============================================================================
# CC Lab-6: Jenkins CI/CD with Docker & NGINX — Full Walkthrough Script
# Run from the directory that CONTAINS your CC_LAB-6/ folder.
# Usage: bash lab6_walkthrough.sh
# =============================================================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

# Prints the prompt + command, then runs it
run_cmd() {
    echo -e "${BOLD}\$ $*${RESET}"
    eval "$@"
    local code=$?
    echo ""
    return $code
}

pause() {
    echo -e "${YELLOW}>>> Press ENTER to continue...${RESET}"
    read -r
}

screenshot_prompt() {
    local num="$1"; shift
    echo ""
    echo -e "${GREEN}${BOLD}┌──────────────────────────────────────────────────────────────┐${RESET}"
    echo -e "${GREEN}${BOLD}│  📸  SCREENSHOT ${num}: $*${RESET}"
    echo -e "${GREEN}${BOLD}└──────────────────────────────────────────────────────────────┘${RESET}"
    echo -e "${YELLOW}>>> Take the screenshot, then press ENTER to continue...${RESET}"
    read -r
}

section() {
    echo ""
    echo -e "${CYAN}${BOLD}================================================================${RESET}"
    echo -e "${CYAN}${BOLD}  $*${RESET}"
    echo -e "${CYAN}${BOLD}================================================================${RESET}"
    echo ""
}

browser_step() {
    echo -e "${CYAN}  [BROWSER]${RESET} $*"
}

# =============================================================================
# GATHER INFO UPFRONT
# =============================================================================
section "Setup: Collecting your details"

echo -e "This script runs every terminal command for you and prints each one,"
echo -e "so you can screenshot this terminal directly.\n"

read -rp "Enter your GitHub repository URL (e.g. https://github.com/user/CC_Lab-6.git): " REPO_URL
read -rp "Enter your SRN (e.g. PES1UG2XCSXXX): " SRN
read -rp "Enter your CC_LAB-6 folder name exactly as it appears on disk (e.g. CC_LAB-6 or CC_Lab-6): " LAB_FOLDER

echo ""
echo -e "  Repo URL   : ${BOLD}$REPO_URL${RESET}"
echo -e "  SRN        : ${BOLD}$SRN${RESET}"
echo -e "  Lab folder : ${BOLD}$LAB_FOLDER${RESET}"
echo ""
pause

# =============================================================================
# PRE-FLIGHT
# =============================================================================
section "Pre-flight: Verifying Prerequisites"

run_cmd "docker --version"
if ! docker info &>/dev/null; then
    echo -e "${RED}Docker daemon is not running. Start Docker Desktop then re-run.${RESET}"
    exit 1
fi

run_cmd "docker ps"
run_cmd "git --version"
run_cmd "docker pull nginx"

echo -e "${GREEN}✔ Prerequisites OK.${RESET}"
pause

# =============================================================================
# TASK 1 — Set Up Jenkins Using Docker
# =============================================================================
section "TASK 1 — Set Up Jenkins Using Docker"

run_cmd "docker ps -a --filter name=jenkins"

JENKINS_RUNNING=$(docker ps --filter name=^/jenkins$ --format '{{.Names}}' 2>/dev/null)
JENKINS_EXISTS=$(docker ps -a --filter name=^/jenkins$ --format '{{.Names}}' 2>/dev/null)

if [ -n "$JENKINS_RUNNING" ]; then
    echo -e "${GREEN}✔ Jenkins is already running — skipping image pull and container creation.${RESET}\n"

elif [ -n "$JENKINS_EXISTS" ]; then
    echo -e "Jenkins container exists but is stopped. Starting it...\n"
    run_cmd "docker start jenkins"
    echo "Waiting 10 s for Jenkins to boot..."; sleep 10

else
    echo -e "No Jenkins container found — performing fresh install.\n"
    echo -e "${YELLOW}Make sure Dockerfile.jenkins is in the current directory, then press ENTER.${RESET}"
    pause

    run_cmd "docker pull jenkins/jenkins:lts"
    run_cmd "docker build -t jenkins-docker -f Dockerfile.jenkins ."
    run_cmd "docker run -d \
  -p 8080:8080 \
  -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  --name jenkins \
  jenkins-docker"

    echo "Waiting 15 s for Jenkins to initialise..."; sleep 15
fi

run_cmd "docker logs jenkins 2>&1 | tail -50"
run_cmd "docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword"

screenshot_prompt "SS1" "Terminal — Jenkins startup log with initial admin password"

echo ""
echo -e "Now complete the Jenkins browser setup:"
browser_step "Go to http://localhost:8080"
browser_step "Paste the password printed above"
browser_step "Select Plugins to Install → search GitHub → tick GitHub options → Install"
browser_step "Create first admin account — username: ${BOLD}$SRN${RESET}"
browser_step "Finish the setup wizard"
pause

screenshot_prompt "SS2" "Browser — Jenkins dashboard at http://localhost:8080 (SRN visible)"

# =============================================================================
# TASK 2 — Push Files to GitHub & Create Freestyle Job
# =============================================================================
section "TASK 2 — Push Lab Files to GitHub"

if [ ! -d "$LAB_FOLDER" ]; then
    echo -e "${RED}Directory '$LAB_FOLDER' not found in $(pwd). Are you in the right folder?${RESET}"
    exit 1
fi

run_cmd "cd \"$LAB_FOLDER\""
cd "$LAB_FOLDER"

run_cmd "git init"
run_cmd "git checkout -b main 2>/dev/null || git checkout main"
run_cmd "git remote remove origin 2>/dev/null; git remote add origin \"$REPO_URL\""
run_cmd "git add ."
run_cmd "git commit -m 'Initial Jenkins lab setup'"
run_cmd "git push -u origin main"

cd ..

echo ""
echo -e "Now create the Freestyle job in Jenkins:"
browser_step "Dashboard → New Item"
browser_step "Job name: ${BOLD}${SRN}-backend-build${RESET}  → Freestyle Project → OK"
browser_step "Source Code Management → Git → URL: $REPO_URL → Branch: */main"
browser_step "Build Triggers → Poll SCM → Schedule: H/5 * * * *"
browser_step "Build Steps → Execute Shell → paste:"
echo ""
echo -e "  ┌──────────────────────────────────────────────────┐"
echo -e "  │  cd $LAB_FOLDER                                  │"
echo -e "  │  docker build -t backend-app backend             │"
echo -e "  └──────────────────────────────────────────────────┘"
echo ""
browser_step "Save → Build Now"
pause

screenshot_prompt "SS3" "Browser — Jenkins Console Output (build SUCCESS)"
screenshot_prompt "SS4" "Browser — Build History showing stable (green ✔) build"

# =============================================================================
# TASK 3 — Parameterized Jenkins Job
# =============================================================================
section "TASK 3 — Parameterized Jenkins Job"

echo -e "Add a choice parameter so Jenkins can deploy 1 or 2 backend containers.\n"
browser_step "Open job ${SRN}-backend-build → Configure"
browser_step "Tick 'This project is parameterized'"
browser_step "Add Parameter → Choice Parameter"
browser_step "  Name: Backend_Count     Choices (one per line):  1   then  2"
echo ""
browser_step "Replace Execute Shell with:"
echo ""
echo -e "  ┌──────────────────────────────────────────────────────────────────┐"
echo -e "  │  cd $LAB_FOLDER                                                  │"
echo -e "  │  docker build -t backend-app backend                             │"
echo -e "  │  docker rm -f backend1 backend2 || true                          │"
echo -e "  │  if [ \"\$BACKEND_COUNT\" = \"1\" ]; then                             │"
echo -e "  │    docker run -d --name backend1 backend-app                     │"
echo -e "  │  else                                                            │"
echo -e "  │    docker run -d --name backend1 backend-app                     │"
echo -e "  │    docker run -d --name backend2 backend-app                     │"
echo -e "  │  fi                                                              │"
echo -e "  └──────────────────────────────────────────────────────────────────┘"
echo ""
browser_step "Save → Build with Parameters → select 1 → Build"
browser_step "After that build finishes: Build with Parameters → select 2 → Build"
pause

screenshot_prompt "SS5" "Browser — Build with Parameters page (Backend_Count dropdown)"
screenshot_prompt "SS6" "Browser — Console output for BOTH builds (2 screenshots)"

echo -e "\nVerifying containers are running:"
run_cmd "docker ps --filter name=backend"

# =============================================================================
# TASK 4 — Jenkins Pipeline
# =============================================================================
section "TASK 4 — Jenkins Pipeline for Automated Deployment"

echo -e "Create the Pipeline job that reads your Jenkinsfile from GitHub.\n"
browser_step "Dashboard → New Item"
browser_step "Name: LAB6-PIPELINE-NGINX  → Pipeline → OK"
browser_step "Pipeline section → Definition: Pipeline script from SCM → SCM: Git"
browser_step "Repository URL: $REPO_URL   Branch: */main"
browser_step "Script Path: ${BOLD}${LAB_FOLDER}/Jenkinsfile${RESET}"
browser_step "Save → Build Now"
echo ""
browser_step "Wait for ALL stages to turn green in Stage View"
pause

echo -e "\nVerifying all containers after pipeline run:"
run_cmd "docker ps"

echo ""
echo -e "Open ${CYAN}http://localhost${RESET} and refresh 5-6 times."
echo -e "You should see responses alternate between two different backend container IDs."
pause

screenshot_prompt "SS7" "Browser — Jenkins Stage View (all stages green)"
screenshot_prompt "SS8" "Browser — Console Output for the pipeline build"
screenshot_prompt "SS9" "Browser — http://localhost first response (one backend ID)"
screenshot_prompt "SS10" "Browser — http://localhost second response (different ID after refresh)"

# =============================================================================
# TASK 5 — NGINX Load Balancing Strategies
# =============================================================================
section "TASK 5 — NGINX Load Balancing Strategies"

NGINX_CONF="${LAB_FOLDER}/nginx/default.conf"

if [ ! -f "$NGINX_CONF" ]; then
    echo -e "${RED}Cannot find $NGINX_CONF — make sure the file exists in your repo.${RESET}"
    exit 1
fi

# Helper: write conf, display it, commit, push, then prompt for screenshots
apply_strategy() {
    local label="$1"
    local directive="$2"   # empty = round-robin (no keyword)
    local commit_msg="$3"
    local ss_conf_num="$4"
    local ss_browser_num="$5"

    echo ""
    echo -e "${BOLD}── Strategy: $label ─────────────────────────────────────────────${RESET}"
    echo ""

    if [ -z "$directive" ]; then
        cat > "$NGINX_CONF" <<EOF
upstream backend_servers {
    server backend1:8080;
    server backend2:8080;
}

server {
    listen 80;

    location / {
        proxy_pass http://backend_servers;
    }
}
EOF
    else
        cat > "$NGINX_CONF" <<EOF
upstream backend_servers {
    ${directive};
    server backend1:8080;
    server backend2:8080;
}

server {
    listen 80;

    location / {
        proxy_pass http://backend_servers;
    }
}
EOF
    fi

    run_cmd "cat \"$NGINX_CONF\""

    screenshot_prompt "$ss_conf_num" "Terminal — nginx/default.conf showing $label config"

    cd "$LAB_FOLDER"
    run_cmd "git add nginx/default.conf"
    run_cmd "git commit -m \"$commit_msg\""
    run_cmd "git push origin main"
    cd ..

    echo ""
    browser_step "Jenkins Dashboard → LAB6-PIPELINE-NGINX → Build Now"
    browser_step "Wait for pipeline to complete successfully"
    browser_step "Refresh http://localhost multiple times and observe backend responses"
    pause

    screenshot_prompt "$ss_browser_num" "Browser — http://localhost responses after $label pipeline run"
}

apply_strategy "Round-Robin (default)" "" \
    "Reset to round-robin load balancing" \
    "SS11" "SS12"

apply_strategy "Least Connections" "least_conn" \
    "Changed to least_conn load balancing" \
    "SS13" "SS14"

apply_strategy "IP Hash" "ip_hash" \
    "Changed to ip_hash load balancing" \
    "SS15" "SS16"

echo -e "\n${YELLOW}Note: With ip_hash all refreshes should hit the SAME backend."
echo -e "If you see 502 Bad Gateway, take a screenshot of that too — it is acceptable.${RESET}"

# =============================================================================
# COMMON ERRORS — terminal commands only (browser steps noted inline)
# =============================================================================
section "Common Errors & Quick Fixes (for reference)"

echo -e "${BOLD}Error 1 — Docker socket permission denied${RESET}"
echo -e "  Run these two commands, then re-run Jenkins with --user root:"
echo ""
echo -e "  ${BOLD}\$ docker stop jenkins${RESET}"
echo -e "  ${BOLD}\$ docker rm jenkins${RESET}"
echo -e "  ${BOLD}\$ docker run -d -p 8080:8080 -p 50000:50000 \\${RESET}"
echo -e "      ${BOLD}-v jenkins_home:/var/jenkins_home \\${RESET}"
echo -e "      ${BOLD}-v /var/run/docker.sock:/var/run/docker.sock \\${RESET}"
echo -e "      ${BOLD}--user root --name jenkins jenkins-docker${RESET}"
echo ""

echo -e "${BOLD}Error 2 — Jenkinsfile not found${RESET}"
echo -e "  Check Script Path in pipeline config matches: ${LAB_FOLDER}/Jenkinsfile"
echo ""

echo -e "${BOLD}Error 3 — Corrupted workspace${RESET}"
echo -e "  ${BOLD}\$ docker exec -u root jenkins rm -rf /var/jenkins_home/workspace/${SRN}-backend-build${RESET}"
echo ""

echo -e "${BOLD}Error 4 — host not found in upstream backend1:8080${RESET}"
echo -e "  Add  sleep 3  after deploying backends in your Jenkinsfile."
echo -e "  Add  sleep 2  after starting nginx but before copying config."
echo -e "  Then commit, push, and re-run the pipeline."
echo ""

# =============================================================================
# SCREENSHOT CHECKLIST
# =============================================================================
section "Screenshot Checklist"

echo -e "  ${GREEN}SS1${RESET}  Terminal — Jenkins startup log (initial admin password)"
echo -e "  ${GREEN}SS2${RESET}  Browser  — Jenkins dashboard (SRN username visible)"
echo -e "  ${GREEN}SS3${RESET}  Browser  — Console Output of Task-2 build (SUCCESS)"
echo -e "  ${GREEN}SS4${RESET}  Browser  — Build History showing stable green build"
echo -e "  ${GREEN}SS5${RESET}  Browser  — Build with Parameters page (Backend_Count dropdown)"
echo -e "  ${GREEN}SS6${RESET}  Browser  — Console output for BOTH parameterised builds"
echo -e "  ${GREEN}SS7${RESET}  Browser  — Stage View (LAB6-PIPELINE-NGINX, all stages green)"
echo -e "  ${GREEN}SS8${RESET}  Browser  — Console Output for the pipeline build"
echo -e "  ${GREEN}SS9${RESET}  Browser  — http://localhost first backend response"
echo -e "  ${GREEN}SS10${RESET} Browser  — http://localhost second backend response (after refresh)"
echo -e "  ${GREEN}SS11${RESET} Terminal — nginx/default.conf (Round-Robin config)"
echo -e "  ${GREEN}SS12${RESET} Browser  — Responses after Round-Robin pipeline run"
echo -e "  ${GREEN}SS13${RESET} Terminal — nginx/default.conf (least_conn config)"
echo -e "  ${GREEN}SS14${RESET} Browser  — Responses after least_conn pipeline run"
echo -e "  ${GREEN}SS15${RESET} Terminal — nginx/default.conf (ip_hash config)"
echo -e "  ${GREEN}SS16${RESET} Browser  — Responses after ip_hash pipeline run"
echo ""

echo -e "${GREEN}${BOLD}╔═══════════════════════════════════════════════════╗${RESET}"
echo -e "${GREEN}${BOLD}║   Lab-6 walkthrough complete. Good luck! ✔        ║${RESET}"
echo -e "${GREEN}${BOLD}╚═══════════════════════════════════════════════════╝${RESET}"
echo ""
