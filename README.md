# BTRFS Observer
A small background script, which regulary check if your BTRFS-based disk has some errors like corrupted blocks etc.

## How to install
1. Download the installer and run it:
```bash
wget https://raw.githubusercontent.com/Mir04ka/btrfs-observer/refs/heads/master/scripts/install.sh
sudo bash install.sh
```

2. Specify interval between checkouts(in seconds) and disks you want to check(1 disk per line):
```bash
Timeout(seconds): 3600
Enter disks (one per line, Ctrl+D to finish):
/dev/nvme0n1p3
/dev/sdb1
```

3. Press Ctrl+D to finish and wait for result:
```bash
BTRFS observer installed!
```

This moment an informal notification should appear:

<img width="337" height="99" alt="image" src="https://github.com/user-attachments/assets/abf0234e-0709-414b-9ef7-681933534c2b" />


## Requirements
- Linux-based OS

## Tested OS
- KDE fedora 42

## TODO
- [ ] RAM optimisation
- [ ] Logs spamming fix
- [ ] Check if disk mounted before running
- [ ] Memory to notify if errors count is rising

