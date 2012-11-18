#!/bin/bash
# Peter Senna Tschudin - released under GPL2
# v 0.1 18/11/2012

URL="http://www.kernel.org/pub/linux/kernel/v3.x/stable-review"
FILE=/tmp/stable-review.html
LASTMD5=/home/peter/stable-kernel/bin/lastmd5.md5
MAXAGE=240 # 4 minutes
LOCKFILE=/tmp/IMRUNNING888

stable[0]="patch-3.0"
stable[1]="patch-3.4"
stable[2]="patch-3.6"
stable[3]="" # Only for safety
i=0

GIT=/home/peter/stable-kernel/linux-stable
OUTDIR=/home/peter/stable-kernel/linux-stable-out
BUILDLOG=/home/peter/stable-kernel/linux-stable-buildlog
CONCURRENT=8

COMPILESUCCESS=$BUILDLOG/SUCCESSBUILD
COMPILEFAIL=$BUILDLOG/FAILBUILD

function exit1 {
	rm $LOCKFILE
	echo ---------- End: $(date) ----------
	exit 1
}

if [ -f $LOCKFILE ];then
	echo The file $LOCKFILE is used as lockfile. If you are sure that there are not other copies of me running, remove $LOCKFILE and try again.
	exit 1
fi

date > $LOCKFILE

# Start date
echo ---------- Start: $(date) ----------

# Is downloaded index older enough to download it again?
if [ -f $FILE ]; then
	now=$(date +"%s")
	fileage=$(stat -c "%Y" $FILE)
	let "diff=$now - $fileage"

	if [ $diff -gt $MAXAGE ];then
		rm -f $FILE
	fi
fi

# Have the index changed, since last download?
if [ ! -f $FILE ]; then
	wget $URL -O $FILE
	if [ $? != 0 ]; then
		echo Error getting index!
		exit1
	fi
	md5sum --check --quiet $LASTMD5 &> /dev/null
	if [ $? == 0 ];then
		echo Same md5sum of $FILE. If you really want to run me remove $LASTMD5 and try again...
		exit1
	fi
else
	echo $FILE has less than $MAXAGE seconds of life. If you really want to run me remove $FILE and try again.
	exit 0
fi

#The index has changed. Update it.
md5sum $FILE > $LASTMD5

#Latest -rc patch versions
while true; do
	latestrc[i]=$(cat $FILE |grep "${stable[i]}"|cut -d ">" -f 2 |cut -d "<" -f 1|cut -d . -f -3|cut -d . -f 3|sort -g |tail -n 1)

	let "i += 1"
	if [ ! "${stable[i]}" ]; then
		latestrc[i]=""
		break
	fi
done
i=0

#Latest patches URLs
while true; do
	latesturl[i]="$URL/${stable[i]}.${latestrc[i]}.gz"
	#echo ${latesturl[i]}

	let "i += 1"
	if [ ! "${stable[i]}" ]; then
                break
	fi
done
i=0

#Tag to apply the patches
while true; do
	prevstable=$(echo ${latestrc[i]}|cut -d - -f 1)
	let "prevstable -= 1"

	stabletag[i]="v$(echo ${stable[i]}|cut -d - -f 2-).$(echo $prevstable)"
	#echo "${stabletag[i]}"

	let "i += 1"
	if [ ! "${stable[i]}" ]; then
		break
	fi
done
i=0

# Update git 
cd $GIT
git checkout master
git pull
if [ $? != 0 ];then
	echo ERROR on git pull
	exit1
fi

#Making kernels
while true; do
	pversion=peter-${stable[i]}.${latestrc[i]}
	echo ----------
	echo $pversion
	echo ----------

	cat $COMPILESUCCESS $COMPILEFAIL | grep $pversion &> /dev/null
	if [ $? == 0 ];then
		echo Kernel $pversion was already built...
		let "i += 1"
		if [ ! "${stable[i]}" ]; then
			break
		fi
		continue
	fi

	patchgz=$(echo ${latesturl[i]}|awk -F/ '{print $(NF)}')
	outdir=$OUTDIR/$pversion

	mkdir $outdir

	cd /tmp
	wget ${latesturl[i]}
	if [ $? != 0 ];then
		echo ERROR downloading
		exit1
	fi

	cd $GIT
	git checkout ${stabletag[i]}
	if [ $? != 0 ];then
		echo ERROR git checkout ${stabletag[i]}
		exit1
	fi

	git checkout -b $pversion

	zcat /tmp/$patchgz |git apply
	if [ $? != 0 ];then
		echo ERROR git apply /tmp/$patch
		exit1
	fi

	git commit -a -m 'stable -rc patch applyed'
	make allyesconfig O=$outdir
	cd $outdir
	make -j$CONCURRENT > $BUILDLOG/$pversion.1 2> $BUILDLOG/$pversion.2
	if [ $? == 0 ];then
		echo $pversion >> $COMPILESUCCESS
	else
		echo $pversion >> $COMPILEFAIL
	fi

	cd $GIT
	git checkout master
	git branch -D $pversion

	let "i += 1"
        if [ ! "${stable[i]}" ]; then
		break
	fi

done
i=0

# End date
echo ---------- End: $(date) ----------
