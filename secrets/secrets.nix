let 
  main = builtins.readFile ../_/id_rsa.pub;
in {
  "cf_account_id".publicKeys = [ main ];
  "cf_account_api".publicKeys = [ main ];
  "cf_account_email".publicKeys = [ main ];
  "cf_cc_tunnel_credentials".publicKeys = [ main ];
  "nextcloud_admin_password".publicKeys = [ main ];
  # "glitchtip_key".publicKeys = [ main ];
  # "vscode_hashed_password".publicKeys = [ main ];
}