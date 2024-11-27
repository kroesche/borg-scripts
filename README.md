# Borg Backup Scripts

This is my template for my borg backup scripts. I use this instead of borgmatic
or vorta (or whatever) for reasons.

## How to Use

Clone this repo or copy the files. I put them in `./config/borg-scripts`

Edit `borg-repo.cfg` to put the correct values for `BORG_NNNN` variables.

Test the script with:

    ./borg-backup.sh example test

Which should show a dry run without backing anything up. Or:

    ./borg-backup.sh example backup

which will perform a test backup up these scripts (you can delete the test
backup later).

Make your own backup set by copying `borg-set-example.cfg` to your own set
name. For example `borg-set-mybackup.cfg`. Then edit it to customize it for
your backup set. Then invoke with:

    ./borg-backup.sh mybackup backup
