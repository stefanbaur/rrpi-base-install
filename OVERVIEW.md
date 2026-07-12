# This branch has two instances of paperless-ngx
 - one in ENV2
 - one in ENV3
They **do not** share their database/directories!

# Defaults
 - As per the official paperless-ngx documentation (https://docs.paperless-ngx.com/setup/#less-powerful-devices), we're defaulting to the SQLite database backend for the Pi.
 - However, we've left the other settings as they were. If you're a regular paperless-ngx user and can give qualified feedback which settings actually make sense for this demo, feel free to provide feedback.
 - Instead of the interactive configuration you might be familiar with from installing paperless-ngx' Docker version, this demo tries to preseed all the variables - see `./base_install_branch_specific.conf` for the defaults. You can permanently override the defaults by copying the file to `./base_install_branch_specific_custom.conf` - this will never be overwritten by a `git pull`.
