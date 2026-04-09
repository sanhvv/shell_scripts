1. make folder for textfile_collector
sudo mkdir -p /var/lib/node_exporter/textfile_collector

2. change docker-compose.yml in ~/xlm_monitoring

Node-exporter
    command:
      - "--collector.textfile.directory=/textfile_collector"
    volumes:
      - "/var/lib/node_exporter/textfile_collector:/textfile_collector:ro"

3. Re-run docker compose

docker compose -f ~/xlm_monitoring/docker-compose.yml up -d --no-deps node-exporter

#docker compose up -d --no-deps node-exporter


4. add crontab job

* * * * * /home/xsights/shell_scripts/mtr_monitoring/mtr_monitoring_edgepc.sh >> /var/log/xsights/cron_mtr_monitoring_edgepc.log 2>&1  # MTR

