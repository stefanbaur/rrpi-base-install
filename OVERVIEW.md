# This branch has two instances of mailcow
 - one in ENV2
 - one in ENV3
They **do not** share their database/directories!

# Defaults
 - Instead of the interactive configuration you might be familiar with from installing mailcow's Docker version, this demo tries to preseed all the variables.

# Security
 - Your initial login credentials for mailcow both in ENV2 and ENV3 can be found in `/data/mailcow-login.txt` once the installation has finished. Please change them immediately.
 - Please read the official mailcow documentation (https://docs.mailcow.email/post_installation/firststeps-ssl/) for instructions on how to enable SSL (https) encryption - this is a must if you intend to make your mailcow instance's web GUI available via the internet!

# Backup
 - Please read the official mailcow documentation (https://docs.mailcow.email/backup_restore/b_n_r-coldstandby/#you-should-know) for instructions on how to backup and restore your mailcow instance's data.
