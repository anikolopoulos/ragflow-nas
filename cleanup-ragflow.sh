#!/bin/bash

echo "=== RAGFlow Cleanup Script ==="
echo "This will remove all unnecessary troubleshooting files"
echo "Press Ctrl+C to cancel, or Enter to continue..."
read

# Remove troubleshooting scripts
echo "Removing troubleshooting scripts..."
rm -f fix-and-restart.sh
rm -f fix-config-live.sh
rm -f fix-config-startup.sh
rm -f fix-es-config.sh
rm -f fix-opensearch-compat.sh
rm -f fix-opensearch-compatibility.sh
rm -f fix-opensearch-config.sh
rm -f fix-to-localhost.sh
rm -f fix-to-public.sh
rm -f init-fix.sh
rm -f patch-ragflow.sh
rm -f permanent-fix.sh
rm -f remove-patch.sh
rm -f setup-do-elasticsearch.sh
rm -f simple-opensearch-fix.sh
rm -f startup-fix.sh
rm -f update-template.sh
rm -f use-elasticsearch-image.sh

# Remove wrapper and entrypoint scripts
echo "Removing wrapper scripts..."
rm -f custom-entrypoint.sh
rm -f entrypoint-wrapper.sh
rm -f entrypoint-wrapper-fixed.sh
rm -f ragflow-entrypoint.sh
rm -f ragflow-wrapper.sh
rm -f smart-entrypoint.sh

# Remove test docker-compose files
echo "Removing test docker-compose files..."
rm -f docker-compose-final-fixed.yml
rm -f docker-compose-final.yml
rm -f docker-compose-with-es.yml
rm -f docker-compose.debug.yml
rm -f do-elasticsearch-fixed.yml
rm -f elasticsearch-qnap.yml
rm -f docker-compose-shared-es.yml

# Remove temporary configuration files
echo "Removing temporary configs..."
rm -f current_config.yaml
rm -f service_conf_fixed.yaml
rm -f service_conf.yaml.template  # duplicate in root

# Remove backup files
echo "Removing backup files..."
rm -f .env-ragflow-nas.bak
rm -f .env-ragflow-nas.backup
rm -f service_conf.yaml.template.bak

# Remove troubleshooting directories
echo "Removing troubleshooting directories..."
rm -rf config-fixes/
rm -rf docker-entrypoint-initdb.d/
rm -rf utils/

# Remove temporary nginx config
rm -f /tmp/ragflow-nginx.conf

# Optional: Remove archive files (uncomment if you want to remove them)
# echo "Removing archive files..."
# rm -f ragflow-amd64-full.tar
# rm -f ragflow-full.tar
# rm -f ragflow.zip

# Clean up old task executor logs (keep the main ragflow_server.log)
echo "Cleaning up old task executor logs..."
find logs/ -name "task_executor_*.log" -type f -delete 2>/dev/null

echo ""
echo "=== Cleanup Complete ==="
echo ""
echo "Remaining essential files:"
echo "- docker-compose.yml (main configuration)"
echo "- .env-ragflow-nas (environment variables)"
echo "- conf/ directory (configuration)"
echo "- Data directories: data/, elasticsearch/, mysql/, minio/, redis/"
echo "- logs/ directory (application logs)"
echo ""
echo "Note: Archive files (*.tar, *.zip) were NOT removed."
echo "Remove them manually if no longer needed."