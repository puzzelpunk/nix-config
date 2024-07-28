{ lib, pkgs, homeserverConfig, ... }:

with lib;
with pkgs.stdenv;

# TODO: move db pass and secrets to age, then setup for search and replace

''
# Configuration file for Synapse.
#
# This is a YAML file: see [1] for a quick introduction. Note in particular
# that *indentation is important*: all the elements of a list or dictionary
# should have the same indentation.
#
# [1] https://docs.ansible.com/ansible/latest/reference_appendices/YAMLSyntax.html
#
# For more information on how to configure Synapse, including a complete accounting of
# each option, go to docs/usage/configuration/config_documentation.md or
# https://element-hq.github.io/synapse/latest/usage/configuration/config_documentation.html

server_name: "${homeserverConfig.subdomain}.${homeserverConfig.domain}"
pid_file: /data/homeserver.pid
listeners:
  - port: ${builtins.toString homeserverConfig.port}
    tls: false
    type: http
    x_forwarded: true
    resources:
      - names: [client, federation]
        compress: false
database:
  name: psycopg2
  args:
    user: ${homeserverConfig.postgres.user}
    password: ${homeserverConfig.postgres.pass}
    database: ${homeserverConfig.postgres.name}
    host: ${homeserverConfig.postgres.host}
    cp_min: 5
    cp_max: 10
log_config: "/data/${homeserverConfig.subdomain}.${homeserverConfig.domain}.log.config"
media_store_path: /data/media_store
registration_shared_secret: "n;OXhlEF_3:a&GjQMX,NQZhys-~oG1KmQYXe+Gb&7O0m.1Kdrr"
report_stats: true
macaroon_secret_key: "D.#0UVV4Hc1.dd0ojrWkWf^,c@:NHRP,PMTt4:R8hC:ACm1wzR"
form_secret: "GEpZSh#yB:4:8es12wf;&NTBk&NYMPyj6;rK,D6Iit7oVz2QIO"
signing_key_path: "/data/${homeserverConfig.subdomain}.${homeserverConfig.domain}.signing.key"
trusted_key_servers:
  - server_name: "matrix.org"
''