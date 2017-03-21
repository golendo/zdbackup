### ZDBackup

auto snapshot tool for zfs datasets

usage:
```
zdbackup.sh [OPTION] Dataset

Options:
-p, --prefix                specify the prefix to use
-i, --interval              specify the interval of the backups (yMwdhms)
-n, --backups               specify the count of the backups. The oldest backups gets deleted. 0 = no backup gets deleted
-c, --timestamp             sets the 'current time' of the script (unix timestamp)
```

example:
```bash
/zdbackup.sh -p hourly -i 1h24m9s -n 48 my/local/zfs-dataset
```

> zdbackup does not modify your crontab, but it prevents an too early execution.
> It would be fine to put all your zdbackup calls in one bash script and create a cronjob with your smallest interval.

In combination with [zdsync](https://www.github.com/golendo/zdsync) you can create an awesome cronjob like this hourly one:
```bash
#! /bin/bash
CurrentTime=$(date +%s)

zdsync.sh -s "ssh root@remote01.example.org" -p remote01 -c $CurrentTime storage storage/backup/online/remote01
zdbackup.sh -p hourly -i 1h -n 48 -c $CurrentTime storage/backup/online/remote01
zdbackup.sh -p daily -i 1d -n 7 -c $CurrentTime storage/backup/online/remote01
zdbackup.sh -p weekly -i 1w -n 8 -c $CurrentTime storage/backup/online/remote01
zdbackup.sh -p monthly -i 1M -c $CurrentTime storage/backup/online/remote01
```
