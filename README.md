# ubuntu-zfs-root-enc-home
Copyright 2021 Justin Hoppensteadt
Additional per user encryption of home dir for Ubuntu systems with ZFS root

Existing solutions either don't work on Ubuntu 21.10, or are manual processes
that are not suitable for large, or production, environments.

## Installation and usage
1. Copy sbin/* to /sbin, chmod 0755 them, chown root:root them as well
2. Manually merge the files in pam.d into your pam setup. This will be different
   on various flavors/releases. I'll try to automate this in the future
3. Do not be logged in as the user you want to migrate, best run logged in as
   root on the console (no X)
4. Read convert.sh and *understand* what it is going to do
5. Make sure you are running a zfs root with bpool and rpool conventions
6. Make sure that the user to be converted was either created using the normal
   Ubuntu systems management tools, adduser, gnome-control-center, etc. The
   user's home directory should be visible when running `zfs list`, and should
   have the following convention for the volume name
   "rpool/USERDATA/$USER_$RANDOM" where USER is the user, and RANDOM is a string
   that can be described by this pcre `/[\w\d]{6}/`
7. Run `./convert.sh --help` and decide if you need to add any arguments,
   referenced as $ARGUMENTS below
8. Don't skip 4, 5, 6, or 7
9. On the console, as root, run `./convert.sh $ARGUMENTS $USER`, $USER is the user to be
   converted.

# Special thanks
This project automates code from, adds to, was inspired by, etc
- https://talldanestale.dk/2020/04/06/zfs-and-homedir-encryption/
- https://www.1stbyte.com/2021/04/12/encrypt-your-zfs-home-directory-in-ubuntu-20-04/
- https://medium.com/@andaag/how-i-moved-a-ext4-ubuntu-install-to-encrypted-zfs-62af1170d46c
- https://github.com/rlaager/zfscrypt
- https://github.com/openzfs/zfs
- https://ubuntu.com


# Special thanks to me
- btc: bc1qqxrjrzw9mwa49tv6wucrz22xr5ga4kg8ptl9x5
