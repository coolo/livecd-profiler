set -e

mkiso () 
{
  echo "mkiso"
  cd CD1
  boot=$(ls -1d boot/* | grep -v grub)
  volumeid=`grep "Application id" isoinfo.txt | cut -d: -f2`
  volumeid=`echo $volumeid`
  /usr/bin/genisoimage -R -J -pad -joliet-long -p "KIWI - http://kiwi.berlios.de" -publisher "SUSE LINUX Products GmbH" -A "$volumeid" -V "$volid" -no-emul-boot -boot-load-size 4 -boot-info-table -b $boot/loader/isolinux.bin -c $boot/boot.catalog -hide $boot/boot.catalog -hide-joliet $boot/boot.catalog -o ../$1 .
  cd ..
}

bootemu ()
{
  forp=$PWD/$1
  mkdir -p $forp
  rm -f $forp/uptime
  # path on portia
  ulimit -t 1200
  qemu="/usr/local/bin/qemu-system-x86_64"
  if ! test -x $qemu; then
     qemu=qemu-kvm
  else
     qemu="$qemu -enable-kvm"
  fi
  # -hda fat:rw:$forp
  $qemu -soundhw pcspk -monitor telnet:0.0.0.0:1025,server,nowait -serial file:$forp/trace -cdrom newlive.iso -boot d -m 512 -vnc :70 &
  qemupid=$!
  lastsize=0
  for i in `seq 0 15`; do
    echo $((i/2)) min $lastsize
    sleep 30
    if ! test -s $forp/trace; then continue; fi
    csize=`stat -c %s $forp/trace`
    if test $csize == $lastsize; then break; fi  
    lastsize=$csize
  done
  exec 3<>/dev/tcp/localhost/1025
  echo "screendump default" >&3
  sleep 1
  convert default $forp/default.jpg
  echo "sendkey ctrl-alt-f1" >&3
  sleep 1
  echo "screendump default" >&3
  sleep 1
  convert default $forp/tty1.jpg
  echo "sendkey ctrl-alt-f2" >&3
  sleep 1
  echo "screendump default" >&3
  sleep 1
  convert default $forp/tty2.jpg
  echo "sendkey ctrl-alt-f3" >&3
  sleep 1
  echo "screendump default" >&3
  sleep 1
  convert default $forp/tty3.jpg
  rm default
  echo "quit" >&3
  dos2unix $forp/trace
}

arch=$1
cd=$2
proj=$3
status=`curl -s http://src-opensuse.suse.de:5352/build/$proj/$arch/$cd.$arch/_status | grep code= | sed -e 's,.*code="\(.*\)".*,\1,'`
case $status in 
   finished|succeeded|disabled)
	;;
   *)
	#echo "already rebuilding $cd: $status"
#	exit 0
	;;
esac
nfile=`curl -s http://src-opensuse.suse.de:5352/build/$proj/$arch/$cd.$arch/ | grep filename= | egrep "$cd-unpackaged-[0-9].*rpm" | grep -v src.rpm | cut -d\" -f2`
ofile=`curl -s http://src-opensuse.suse.de:5352/build/$proj/$arch/$cd.$arch/ | grep filename= | egrep "$cd-[0-9].*rpm" | grep -v src.rpm | cut -d\" -f2`
outdir="$arch"_"$cd"
if ! test -f download/$cd.$arch/$nfile; then
  mkdir -p download/$cd.$arch/
  echo "downloading $proj/$arch/$cd.$arch/*.rpm"
  rsync --delete -av --include=$nfile --include=$ofile --exclude=* --delete-excluded backend-opensuse.suse.de::opensuse-internal/build/$proj/$arch/$cd.$arch/ download/$cd.$arch/
fi
isofile=$(ls -1t download/$cd.$arch/*.rpm | tail -n 1)
rpmversion=`rpm -qp --qf "%{VERSION}-%{RELEASE}\n" $isofile`
orpmversion=`cat $outdir/rpmversion`
if test "$rpmversion" = "$orpmversion"; then
  # already there
  exit 0
fi
rm -rf CD1
for rpm in download/$cd.$arch/*.rpm; do rpm2cpio $rpm | cpio -i; done
icfg=$(ls -1 CD1/boot/*/loader/isolinux.cfg)
cp $icfg $icfg.orig
if false; then
sed -i -e "s,preloadlog=/dev/null,,; s,showopts,showopts preloadlog=/dev/ttyS0 vga=0x317," $icfg
sed -i -e "s,timeout 200,timeout 5," $icfg
rm -f newlive.iso
mkiso newlive.iso
bootemu $outdir
sed -i -e 's,\*n,,g' $outdir/trace
fi

mv $icfg.orig $icfg
sed -i -e "s,showopts,showopts cliclog=/dev/ttyS0 vga=0x317 kiwidebug=1," $icfg
sed -i -e "s,timeout 200,timeout 5," $icfg
mkiso newlive.iso
bootemu clic
mv clic/trace $outdir/clic
rm -rf clic

rm -rf CD1
mv newlive.iso $outdir.iso

echo $rpmversion > $outdir/rpmversion

exit 1
