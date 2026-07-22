# PCAP drop directory (nid-suricata, nid-zeek)

No capture is committed here (binary PCAPs don't belong in git, and we ship nothing
malicious). Provide your own for replay:

```bash
# Capture a benign test flow (run the curl from a host on the monitored network):
sudo tcpdump -i eth0 -w pcaps/test.pcap &
curl -s http://testmynids.org/uid/index.html
kill %1

# Replay through Suricata (fires local.rules + ET Open test sigs):
docker compose -p oss500-netdet exec suricata suricata -r /pcaps/test.pcap -l /var/log/suricata

# Replay through Zeek (produces conn/http/dns logs):
docker compose -p oss500-netdet exec zeek zeek -r /pcaps/test.pcap /usr/local/zeek/share/zeek/site/local.zeek
```

Public sample captures: the Suricata and Zeek projects and malware-traffic-analysis.net
publish safe example PCAPs for practice.
