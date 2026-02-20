#!/bin/bash
sudo chown -R vscode:vscode /workspaces/haff/config/custom_components
ln -sf /workspaces/DiveraControl/custom_components/diveracontrol /workspaces/haff/config/custom_components
ln -sf /workspaces/tetraconnect/custom_components/tetraconnect /workspaces/haff/config/custom_components
ln -sf /workspaces/webIO/custom_components/hass-webio /workspaces/haff/config/custom_components
