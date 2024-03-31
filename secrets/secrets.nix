let 
  main = builtins.readFile ../_/id_rsa.pub;
  borgbackup = builtins.readFile ../_/id_rsa.borgbackup.pub;
in {
  "cf_account_id".publicKeys = [ main ];
  "cf_api_token".publicKeys = [ main ];
  "cf_tunnel_password".publicKeys = [ main ];
  "cf_zone_id".publicKeys = [ main ];
  "borgbackup".publicKeys = [ borgbackup ];
  "nextcloud_mysql_password".publicKeys = [ main ];
  "nextcloud_mysql_root_password".publicKeys = [ main ];
  "vscode_hashed_password".publicKeys = [ main ];
}