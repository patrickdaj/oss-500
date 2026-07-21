# OSS-500 Zeek site policy (nid-zeek).
# Zeek LOGS BEHAVIOR — it produces conn/dns/http/ssl/files/... logs for hunting and
# enrichment; it does not block. This policy turns on JSON output (SIEM-friendly),
# richer protocol logging, and intel/notice framework hooks.

@load base/protocols/conn
@load base/protocols/dns
@load base/protocols/http
@load base/protocols/ssl
@load base/protocols/ftp
@load base/protocols/ssh
@load base/frameworks/notice
@load base/frameworks/files
@load policy/protocols/ssl/log-hostcerts-only

# Emit logs as JSON so they ship straight into OpenSearch/Wazuh (siem-hunt).
@load policy/tuning/json-logs.zeek

# Capture JA3 TLS fingerprints for behavioral hunting (rare-cert / SNI-mismatch).
@load policy/protocols/ssl/ja3

# Intel framework: match connections/DNS/files against IOC feeds. Drop indicator
# files in the intel dir and load them here — this is Zeek's IOC-matching side.
# @load frameworks/intel/seen
# redef Intel::read_files += { "/usr/local/zeek/share/zeek/site/intel.dat" };

# Example custom detection on a protocol event: log a NOTICE when a host resolves
# an unusually long DNS name (possible DNS tunneling / exfil) — Zeek is scriptable.
event dns_request(c: connection, msg: dns_msg, query: string, qtype: count, qclass: count)
{
    if ( |query| > 100 )
        NOTICE([$note=Weird::Activity,
                $msg=fmt("OSS500: very long DNS query (possible tunneling): %s", query),
                $conn=c]);
}
