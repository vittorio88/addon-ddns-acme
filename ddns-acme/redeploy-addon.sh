#!/bin/sh

ADDON_NAME="local_ddns-acme"

echo "Running re-deploy of add-on from local add-on directory."

echo "Uninstalling $ADDON_NAME"
ha addon uninstall $ADDON_NAME

echo "Restarting hypervisor to delete in-memory config options"
ha supervisor restart && \
echo "sleeping for 10 seconds" && \
sleep 10
	
echo "reinstalling $ADDON_NAME"
ha addon install $ADDON_NAME


