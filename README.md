How to use this script
----------------------

* Download this script

  $git clone git://github.com/petersenna/stable-help.git
  $cd stable-help

* Edit the bin/check_updates.sh and change the path of the 'ROOTDIR' variable
on line number 7. It should point to the base folder of this script.

* Download the stable kernel inside this script folder

  $git clone git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git

* Run this script

  $./bin/check_updates.sh
