# Borg Backup Scripts

This is my template for my borg backup scripts. I use this instead of borgmatic
or vorta (or whatever) for reasons.

[Borg Backup](https://borgbackup.readthedocs.io/en/stable/)

## Installing

Clone this repo or copy the files. I put them in `./config/borg-scripts`

I made an alias to make it easy to run the script, using `backup`.

    alias backup='~/.config/borg-scripts/borg-backup.sh'

## Using

Edit `borg-repo.cfg` to put the correct values for `BORG_NNNN` variables.

Test the script with:

    ./borg-backup.sh -t example

Which should show a dry run without backing anything up. Or:

    ./borg-backup.sh -b example

which will perform a test backup up of these scripts (you can delete the test
backup later).

## Customize

Make your own backup set by copying `borg-set-example.cfg` to your own set
name. For example `borg-set-mybackup.cfg`. Then edit it to customize it for
your backup set. Then invoke with:

    ./borg-backup.sh -b mybackup

## Help

    Usage:
      borg-backup -b SET_NAME [-n compact] [-n prune]
      borg-backup -t SET_NAME
      borg-backup -l
      borg-backup -h

    Options:
      -h            show help
      -l            list available backup set configurations
      -b SET_NAME   backup the configuration named SET_NAME
      -t SET_NAME   dry-run backup of SET_NAME
      -n prune      skip prune operation
      -n compact    skip compact operation
