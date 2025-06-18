mosquitto_sub -C 1 -v \
--url "mqtt://${MQQT_USER}:${MQQT_PWD}@mosquitto/axis/+/event/connection" | \
awk -F'/' '{print "[{\"{#AXIS_SERIAL}\":\"" $2 "\"}]"; exit}'