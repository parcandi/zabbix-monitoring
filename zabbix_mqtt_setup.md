## Zabbix Monitoring Setup — README

### Overview

This document describes the setup of the Zabbix monitoring environment, including services, configurations, password management, templates, hosts, triggers, actions, and Slack integration.

---

### Services

| Service           | Image                                             | Notes                                   |
| ----------------- | ------------------------------------------------- | --------------------------------------- |
| Zabbix Server     | `zabbix/zabbix-server-pgsql:ubuntu-7.2-latest`    | Main Zabbix server                      |
| Zabbix Web        | `zabbix/zabbix-web-nginx-pgsql:ubuntu-7.2-latest` | Web frontend                            |
| Zabbix Agent2     | `custom agent2 image with mosquitto-clients`      | Runs MQTT discovery and item collection |
| Zabbix SNMP Traps | `zabbix/zabbix-snmptraps:ubuntu-7.2-latest`       | SNMP trap listener                      |
| Mosquitto         | `eclipse-mosquitto:latest`                        | MQTT broker                             |
| Postgres          | `postgres:16-alpine`                              | Zabbix DB                               |

---

### Configuration Files

#### Mosquitto `mosquitto.conf`

```
listener 1883 0.0.0.0
allow_anonymous false
password_file /mosquitto/config/mosquittopwd
```

- **Purpose**: Secures the broker; requires user authentication.
- **Password file**: Mounted via Docker volume from host `./mosquitto/mosquittopwd`

#### Zabbix Agent2 `mqtt.conf`

```
Plugins.MQTT.Timeout=10
Plugins.MQTT.Default.Url=tcp://mosquitto:1883
Plugins.MQTT.Default.User=root
Plugins.MQTT.Default.Password=<your-password>
Plugins.MQTT.Default.Topic=#
```

- **Purpose**: Configures default MQTT broker connection for all MQTT item keys.
- **Mounted path**: `./zbx_env/etc/zabbix/zabbix_agentd.d/mqtt.conf` → `/etc/zabbix/zabbix_agentd.d/mqtt.conf`

#### Custom Discovery Script

- Path: `./discovery/axis_discovery.sh`
- Mounted to: `/usr/local/bin/discovery/axis_discovery.sh`
- Purpose: Runs `mosquitto_sub`, extracts serial numbers from MQTT topics for LLD (Low level discovery).

---

### Zabbix Configuration

#### Templates

- Template: `Template Axis MQTT` (Import from `templates/zbx_export_templates.yaml`)
- Contains:
  - Discovery rule using the custom discovery script
  - Prototypes for:
    - `axis.{#AXIS_SERIAL}.connected` (dependent item extracting `connected` field)
    - Triggers on `connected=0` with recovery if reconnected

#### Hosts

- Host: `Axis-MQTT`
- Interfaces: Agent interface only (used by Zabbix Agent2)
- Template linked: `Template Axis MQTT`

#### Actions

- Action: `Notify Slack on Axis camera problem`
- Conditions: Trigger in Axis-Cameras Host Group
- Operations: Send to Slack media type → channel name of private Slack channel (if private "channel-name", if public use "#channel-name")

#### Slack integration

- `bot_token` set in global macros
- Global macro `{$ZABBIX.URL}` set to Zabbix frontend URL
- Global macro `{$SLACK_BOT_TOKEN}` set to bot token
- Slack bot invited to private Slack channel
- `Send to` in media: Slack channel ID or name (if public)
- Bot needs permissions:
  - chat:write
  - chat:write.customize
  - im:write
  - reactions:write

---

### Where to set/change passwords

- **Mosquitto password**: in `mosquittopwd`, regenerate with `mosquitto_passwd` and restart container `docker exec -it zabbix-monitoring-mosquitto-1 sh -c "touch /mosquitto/config/mosquittopwd && mosquitto_passwd -b /mosquitto/config/mosquittopwd <user> <password> && chmod 0700 /mosquitto/config/mosquittopwd"`
- **MQTT discovery script**: in `.env`
- **MQTT agent config**: in `mqtt.conf`
- **DB user/passwords**: update `.env` secrets and recreate containers
- **Slack bot token**: in Zabbix global macros
