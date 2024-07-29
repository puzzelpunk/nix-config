{ config, lib, pkgs, options, ... }: 
let
  postgresql_home_dir = "/Volumes/Server/cybercrescendo/postgresql";
  postgresql_data_dir = "${postgresql_home_dir}/data";
  postgresql_backup_dir = "${postgresql_home_dir}/backup";
in {
  # Create the PostgreSQL data directory.
  systemd.services.postgresql-data-dir = {
    description = "Create PostgreSQL data directory";
    wantedBy = [ "multi-user.target" ];
    before = [ "postgresql.service" ];
    serviceConfig = {
      Type = "oneshot";
    };
    script = ''
      DATA_DIR="${postgresql_data_dir}"
      mkdir -p $DATA_DIR
      chown -R postgres:postgres $DATA_DIR
    '';
  };

  # Ensure the PostgreSQL data directory exists before starting PostgreSQL.
  systemd.services.postgresql = {
    requires = ["postgresql-data-dir.service"];
    after = ["postgresql-data-dir.service"];
  };

  # Create the PostgreSQL backup directory.
  systemd.services.postgresql-backup-dir = {
    description = "Create PostgreSQL backup directory";
    wantedBy = [ "multi-user.target" ];
    before = [ "postgresql-backup.service" ];
    serviceConfig = {
      Type = "oneshot";
    };
    script = ''
      BACKUP_DIR="${postgresql_backup_dir}"
      mkdir -p $BACKUP_DIR
      chown -R postgres:postgres $BACKUP_DIR
    '';
  };

  # Ensure the PostgreSQL backup directory exists before starting PostgreSQL backup.
  systemd.services.postgresqlBackup = {
    requires = ["postgresql-backup-dir.service"];
    after = ["postgresql-backup-dir.service"];
  };

  services.postgresql = {
    enable = true;
    dataDir = postgresql_data_dir;
  };

  services.postgresqlBackup = {
    enable = true;
    location = postgresql_backup_dir;
    startAt = "*-*-* 01:15:00";
  };
}