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

which will perform an actual backup up of these scripts (you can delete the
test backup later).

## Customize

Make your own backup set by copying `borg-set-example.cfg` to your own set
name. For example `borg-set-mybackup.cfg`. Then edit it to customize it for
your backup set. Then invoke with:

    ./borg-backup.sh -b mybackup

## Launch Agent

There is a script `./install-agent.sh` that will install a LaunchAgent
(on MacOS) to run a backup on a schedule.

## Help

Run the script with `-h` to get some help.

    ./borg-backup.sh -h
    ./install-agent.sh -h

Also, there are man pages in `man/` directory. You can install these on your
system. See the script `install-man.sh`. Then you can use man to see some
documentation:

    man borg-backup

Or if you don't want to install the man pages, you can just view them directly
like:

    man man/borg-backup.1
