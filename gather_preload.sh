set -e

mkiso () 
{
  echo "mkiso"
  cd CD1
  boot=$(ls -1d boot/* | grep -v grub)
  /usr/bin/mkisofs -R -J -pad -joliet-long -A undefined -no-emul-boot -boot-load-size 4 -boot-info-table -b $boot/loader/isolinux.bin -c $boot/boot.catalog -hide $boot/boot.catalog -hide-joliet $boot/boot.catalog -o ../$1 ./ 2> /dev/null
  cd ..
}

bootemu ()
{
  forp=$PWD/$1
  mkdir -p $forp
  rm -f $forp/uptime
  # path on portia
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

cd=$1
proj=$2
status=`curl -s http://buildservice.suse.de:5352/build/$proj/$cd/_status | grep code= | sed -e 's,.*code="\(.*\)".*,\1,'`
case $status in 
   finished|succeeded|disabled)
	;;
   *)
	#echo "already rebuilding $cd: $status"
	exit 0
	;;
esac
nfile=`curl -s http://buildservice.suse.de:5352/build/$proj/$cd/ | grep filename= | grep -v src.rpm | grep -v promo | grep -v infos | cut -d\" -f2`
if test -f download/$cd/$nfile; then
  #echo "already have $cd/$nfile"
  exit 0
fi
rm -f newlive.iso
#rm -rf download/$cd/
mkdir -p download/$cd/
outdir=${cd/\//_}
echo "downloading $proj/$cd/*.rpm"
rsync --delete -a --exclude=logfile --exclude=*promo* --exclude=*.src.rpm --exclude=*infos* buildservice2.suse.de::opensuse-internal/build/$proj/$cd/ download/$cd/
isofile=$(ls -1t download/$cd/*.rpm | tail -n 1)
rm -rf CD1
rpm2cpio $isofile | cpio -i
icfg=$(ls -1 CD1/boot/*/loader/isolinux.cfg)
cp $icfg $icfg.orig
sed -i -e "s,preloadlog=/dev/null,,; s,showopts,showopts preloadlog=/dev/ttyS0 vga=0x317," $icfg
sed -i -e "s,timeout 200,timeout 5," $icfg
mkiso newlive.iso
bootemu $outdir
sed -i -e 's,\*n,,g' $outdir/trace

mv $icfg.orig $icfg
sed -i -e "s,showopts,showopts cliclog=/dev/ttyS0 vga=0x317," $icfg
sed -i -e "s,timeout 200,timeout 5," $icfg
mkiso newlive.iso
bootemu clic
mv clic/trace $outdir/clic
rm -rf clic

rm -rf CD1
mv newlive.iso $outdir.iso

rpm -qp --qf "%{VERSION}-%{RELEASE}\n" $isofile > $outdir/rpmversion

exit 1
