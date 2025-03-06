# Borg Backup Scripts

This is my template for my borg backup scripts. I use this instead of borgmatic
or vorta (or whatever) for reasons.

[Borg Backup](https://borgbackup.readthedocs.io/en/stable/)

See [notes about installing borg](#notes-about-installing-borg) below.

## Installing

Clone this repo or copy the files. I put them in `./config/borg-scripts`

I added the following to my aliases file to make it easier to run the scripts
from anywhere (this is completely optional):

    borg-agent='~/.config/borg-scripts/borg-agent'
    borg-backup='~/.config/borg-scripts/borg-backup'
    borg-logs='~/.config/borg-scripts/borg-logs'

## Using

Edit `borg-repo.cfg` to put the correct values for `BORG_NNNN` variables.

Test the script with:

    ./borg-backup -t example

Which should show a dry run without backing anything up. Or:

    ./borg-backup -b example

which will perform an actual backup up of these scripts (you can delete the
test backup later).

## Customize

Make your own backup set by copying `borg-set-example.cfg` to your own set
name. For example `borg-set-mybackup.cfg`. Then edit it to customize it for
your backup set. Then invoke with:

    ./borg-backup -b mybackup

## Launch Agent

There is a script `./borg-agent` that will install a LaunchAgent (on MacOS) to
run a backup on a schedule.

## Logs

There is a script `./borg-logs` to help with examining and managing the log
file.

## Help

Run the script with `-h` to get some help.

    ./borg-backup -h
    ./borg-agent -h
    ./borg-logs -h

Also, there are man pages in `man/` directory. You can install these on your
system. See the script `install-man`. Then you can use man to see some
documentation:

    man borg-backup

Or if you don't want to install the man pages, you can just view them directly
like:

    man man/borg-backup.1

## Borg Version

These scripts are assuming the 1.4.x version of borg. I have not tried 2.x yet.

## MacOS Security

MacOS has security that tries to sandbox apps and programs to have access only
to the data they need to function. When you run a program like borg that tries
to read a lot of files, you get asked for permission to grant access to either
specific directories, or full disk access. I already gave my terminal full disk
access so I never encountered this when running borg from the command line. But
when I ran it as a launch agent, I ran into this problem and had to grant it
access to my user folders, so that it can read all the files to back them up.

To make sure this is not going to cause a problem for the launch agent, after
installing a launch agent for a backup set, you can do a test run.

    borg-agent -r mybackup

This will cause it to start running the backup set under launchd, and you will
then see if you are prompted for any access permissions. It's better to get it
out of the way now rather than have your automated backup stall halfway through
when you are not around to fix it.

## Notes About Installing Borg

This applies to MacOS for now. I originally installed borg backup using
[MacPorts](https://www.macports.org). When I ran from command line there was
no problem reading all the files. This is because I previously gave terminal
"full disk access" permission. When run under launchd (as a launch agent), I
was repeatedly prompted to give "python3" access to this or that folder. But I
wanted to authorize "borg" not python3. With this approach, every python3
program would have full disk access. I think the reason this happens is because
the MacPorts-installed borgbackup uses the macports managed python3 to run.

*(Added note: I also installed the homebrew version and had the same
side-effect - Mac security asking me to approve python to have disk access)*

Next, I downloaded the borg prebuilt binary from the
[releases page](https://github.com/borgbackup/borg/releases). I downloaded the
single file binary `borg-macos1012` and installed it in `/usr/local/bin` so it
would be on my path. This worked fine, but every time borg started, even just
`borg --version` it would take 10-20 seconds to start. This was an annoyance.
The reason is because borg is really a python program built with pyinstaller.
For the single file binary, it is uncompressing all of the program and a python
interpreter every time it is invoked. This goes into a temporary folder and
disappears when the program terminates.

Then, from the releases page, I downloaded `borg-macos1012.tgz`, and unzipped
it. This is the same program, but in a set of folder instead of being all
compressed into a single file. In this case, I put the unzipped `borg-dir` into
`/usr/local/share`, and then symlinked `/usr/local/bin/borg` to the `borg.exe`
in the borg-dir folder. Now I still have `borg` on my path but it runs pretty
much immediately.

BTW in both cases of downloading the binary from the GitHub releases page, I
had to use `xattr` to remove the quarantine attribute from either the single
file, or recursively over the unzipped directory structure.

## Apple Silicon (Mx)

The above does not work on a Mac with Apple silicon like an M1, M2, etc. The
prebuilt binaries only work on x86. Maybe it can be made to work with Rosetta
but I didn't try that. For my computer that has an M3, I just used the homebrew
version and had to approve python3 disk access.
