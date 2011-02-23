ret=0
if ! lockfile -0 -r1 lock 2> /dev/null; then
   exit 0
fi

proj=openSUSE:11.4:Live
repo=standard
for cd in kiwi-profiled-livecd-gnome kiwi-profiled-livecd-kde kiwi-image-livecd-gnome kiwi-image-livecd-kde; do
 for arch in i586 x86_64; do 
   status=`curl -s http://buildservice.suse.de:5352/build/$proj/$repo/$arch/$cd.$arch/_status | grep code= | sed -e 's,.*code="\(.*\)".*,\1,'`
   case $status in
      finished|succeeded|building|scheduled|dispatching|disabled)
        ;;
      *)
	binaries=`curl -s http://buildservice.suse.de:5352/build/$proj/$repo/$arch/$cd.$arch/ | grep filename=`
	if test -n "$binaries"; then
	   echo "wiping $cd"
  	   osc wipebinaries $proj $cd.$arch
           osc wipebinaries $proj promo-dvd-parts -a $arch
	fi
        ;;
   esac
  done
done

ulimit -c unlimited
ret=0
#sh gather_preload.sh x86_64/kiwi-image-livecd-x11 $proj || ret=1
#sh gather_preload.sh i586/kiwi-image-livecd-x11 $proj || ret=1
sh gather_preload.sh x86_64 kiwi-image-livecd-kde $proj/$repo || ret=1
sh gather_preload.sh i586 kiwi-image-livecd-kde $proj/$repo || ret=1
sh gather_preload.sh x86_64 kiwi-image-livecd-gnome $proj/$repo || ret=1
sh gather_preload.sh i586 kiwi-image-livecd-gnome $proj/$repo || ret=1

if test "$ret" = 0; then 
  rm -f lock
  exit 0
fi

for flavor in gnome kde; do 
  commit=$(git log -n 1 HEAD | head -n 1)
  for arch in x86_64 i586; do
    rpmv=`cat "$arch"_kiwi-image-livecd-$flavor/rpmversion | sort -u`
    if test -f "$arch"_kiwi-image-livecd-$flavor/trace; then
      rm -rf $proj
      osc checkout $proj/preload-lists-$flavor-$arch
      cp "$arch"_kiwi-image-livecd-$flavor/trace $proj/preload-lists-$flavor-$arch/livecd || true
      cp "$arch"_kiwi-image-livecd-$flavor/clic $proj/preload-lists-$flavor-$arch/clic || true
      sed -i -e "s,Provides:.*cliclists.*,Provides: cliclists-$flavor = $rpmv," $proj/preload-lists-$flavor-$arch/preload-lists-$flavor.spec
      (cd $proj/preload-lists-$flavor-$arch && osc commit -m "$commit $rpmv")
    fi
  done
  rm -rf $proj
done
git commit -a -m "new run"
git push
rm -f lock

