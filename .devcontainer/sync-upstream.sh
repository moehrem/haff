#!/bin/bash

# Upstream-Synchronisierungs-Script für Home Assistant Core Fork
# Dieses Script synchronisiert die lokale dev branch mit dem upstream Repository
# und bewahrt lokale Änderungen an Konfigurationsdateien

set -e

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Konfiguration: Dateien die lokal behalten werden sollen
LOCAL_FILES=(
    ".devcontainer/devcontainer.json"
    ".vscode/launch.json"
    ".devcontainer/haff.code-workspace"
    ".devcontainer/post-create.sh"
    ".devcontainer/sync-upstream.sh"
    ".gitignore"
)

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  Home Assistant Upstream Sync Script${NC}"
echo -e "${BLUE}============================================${NC}\n"

# 1. Überprüfe ob wir in einem Git Repository sind
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${RED}❌ Fehler: Nicht in einem Git Repository!${NC}"
    exit 1
fi

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo -e "${YELLOW}Aktueller Branch: ${CURRENT_BRANCH}${NC}"

if [ "$CURRENT_BRANCH" != "dev" ]; then
    echo -e "${YELLOW}⚠️  Warnung: Du bist nicht auf dem 'dev' Branch!${NC}"
    read -p "Möchtest du fortfahren? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${RED}Abgebrochen.${NC}"
        exit 1
    fi
fi

# 2. Überprüfe auf uncommitted changes
echo -e "\n${BLUE}Schritt 1: Überprüfe lokale Änderungen...${NC}"
CHANGES=$(git status -s | grep -v "^??" | wc -l)
if [ "$CHANGES" -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Du hast $CHANGES Dateien mit lokalen Änderungen.${NC}"
else
    echo -e "${GREEN}✓ Keine Änderungen an versionierten Dateien.${NC}"
fi

# 3. Stash lokale Änderungen
echo -e "\n${BLUE}Schritt 2: Sichere lokale Änderungen...${NC}"
STASH_MESSAGE="Auto-stash before upstream sync - $(date '+%Y-%m-%d %H:%M:%S')"

# Stash nur die konfigurierten lokalen Dateien
HAS_CHANGES=false
for file in "${LOCAL_FILES[@]}"; do
    if git diff --quiet HEAD -- "$file" 2>/dev/null || git ls-files --error-unmatch "$file" >/dev/null 2>&1; then
        HAS_CHANGES=true
        break
    fi
done

if [ "$HAS_CHANGES" = true ]; then
    # Stash alle lokalen Änderungen (nicht nur die aufgelisteten)
    git stash push -m "$STASH_MESSAGE" 2>/dev/null && \
    echo -e "${GREEN}✓ Lokale Änderungen gesichert.${NC}" || \
    echo -e "${YELLOW}ℹ️  Keine Änderungen zum Stashen.${NC}"
else
    echo -e "${GREEN}✓ Keine lokalen Änderungen zum Stashen.${NC}"
fi

# 4. Überprüfe upstream remote
echo -e "\n${BLUE}Schritt 3: Überprüfe upstream Remote...${NC}"
if ! git remote get-url upstream > /dev/null 2>&1; then
    echo -e "${YELLOW}Upstream Remote existiert nicht. Wird hinzugefügt...${NC}"
    git remote add upstream https://github.com/home-assistant/core.git
fi
echo -e "${GREEN}✓ Upstream Remote ist konfiguriert.${NC}"

# 5. Hole Updates vom upstream
echo -e "\n${BLUE}Schritt 4: Hole Updates von upstream/dev...${NC}"
if git fetch upstream dev; then
    echo -e "${GREEN}✓ Updates heruntergeladen.${NC}"
else
    echo -e "${RED}❌ Fehler beim Abrufen von upstream!${NC}"
    exit 1
fi

# 5a. Überprüfe auf neue Commits
COMMITS_BEHIND=$(git rev-list --count HEAD..upstream/dev)
if [ "$COMMITS_BEHIND" -gt 0 ]; then
    echo -e "${YELLOW}Du bist $COMMITS_BEHIND Commits hinter upstream/dev.${NC}"
else
    echo -e "${GREEN}✓ Du bist auf dem aktuellsten Stand.${NC}"
    echo -e "${GREEN}✓ Synchronisierung abgeschlossen!${NC}"
    exit 0
fi

# 6. Rebase auf upstream
echo -e "\n${BLUE}Schritt 5: Rebase auf upstream/dev...${NC}"
if git rebase upstream/dev; then
    echo -e "${GREEN}✓ Rebase erfolgreich.${NC}"
else
    echo -e "${RED}❌ Fehler beim Rebase! Es gibt wahrscheinlich Konflikte.${NC}"
    echo -e "${YELLOW}Behebe die Konflikte und führe dann aus: git rebase --continue${NC}"
    exit 1
fi

# 7. Stelle lokale Änderungen wieder her
echo -e "\n${BLUE}Schritt 6: Stelle lokale Änderungen wieder her...${NC}"
if git stash pop 2>/dev/null; then
    echo -e "${GREEN}✓ Lokale Änderungen wiederhergestellt.${NC}"
else
    echo -e "${YELLOW}ℹ️  Keine gesicherten Änderungen zum Wiederherstellen.${NC}"
fi

# 8. Zusammenfassung
echo -e "\n${BLUE}============================================${NC}"
echo -e "${GREEN}✓ Synchronisierung abgeschlossen!${NC}"
echo -e "${BLUE}============================================${NC}\n"

echo -e "${YELLOW}Zusammenfassung:${NC}"
echo "  • Branch: $CURRENT_BRANCH"
echo "  • Upstream: upstream/dev"
echo "  • Commits integriert: $COMMITS_BEHIND"
echo ""
echo -e "${YELLOW}Lokale Dateien behalten:${NC}"
for file in "${LOCAL_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "  ✓ $file"
    fi
done

echo ""
echo -e "${BLUE}Status:${NC}"
git status -s || echo "  Alles ist auf dem aktuellsten Stand."
