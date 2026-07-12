# This branch has two instances of paperless-ngx
 - one in ENV2
 - one in ENV3
They **do not** share their database/directories!

# Defaults
 - As per the official paperless-ngx documentation (https://docs.paperless-ngx.com/setup/#less-powerful-devices), we're defaulting to the SQLite database backend for the Pi.
 - However, we've left the other settings as they were. If you're a regular paperless-ngx user and can give qualified feedback which settings actually make sense for this demo, feel free to provide feedback.
 - Instead of the interactive configuration you might be familiar with from installing paperless-ngx' Docker version, this demo tries to preseed all the variables - see `./base_install_branch_specific.conf` for the defaults. You can permanently override the defaults by copying the file to `./base_install_branch_specific_custom.conf` - this will never be overwritten by a `git pull`.

# Security
 - Please read the official paperless-ngx documentation (https://docs.paperless-ngx.com/setup/#additional-considerations) for instructions on how to
   - run paperless-ngx behind a reverse proxy like nginx to add SSL (https) encryption - this is a must if you intend to make your paperless-ngx instance available via the internet!
   - further lock down, protect, and restrict access to your paperless-ngx instance using e.g. fail2ban
 - Also see this github discussion https://github.com/paperless-ngx/paperless-ngx/discussions/211 where it mentions Authelia for further techniques to add additional layers of protection.

# Backup
 - Please read the official paperless-ngx documentation (https://docs.paperless-ngx.com/administration/#backup) for instructions on how to backup and restore your paperless-ngx instance data.
 - Additional hints for alternative approaches to backup and restore can be found, in German, at https://decatec.de/home-server/paperless-ngx-backup-und-restore-manuell-oder-per-skript/
