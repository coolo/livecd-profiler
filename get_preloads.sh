ret=0
if ! lockfile -0 -r1 lock 2> /dev/null; then
   exit 0
fi

proj=openSUSE:Factory:Live/standard
for cd in kiwi-profiled-livecd-gnome kiwi-profiled-livecd-kde; do
   status=`curl -s http://buildservice.suse.de:5352/build/$proj/i586/$cd/_status | grep code= | sed -e 's,.*code="\(.*\)".*,\1,'`
   case $status in
      finished|succeeded|building|scheduled|dispatching)
        ;;
      *)
	binaries=`curl -s http://buildservice.suse.de:5352/build/$proj/i586/$cd/ | grep filename=`
	if test -n "$binaries"; then
	   echo "wiping $cd"
  	   osc wipebinaries openSUSE:Factory:Live $cd
           osc wipebinaries openSUSE:Factory:Live promo-dvd-parts
	fi
        ;;
   esac
done

ulimit -c unlimited
ret=0
sh gather_preload.sh x86_64/kiwi-image-livecd-x11 $proj || ret=1
sh gather_preload.sh i586/kiwi-image-livecd-x11 $proj || ret=1
sh gather_preload.sh x86_64/kiwi-image-livecd-kde $proj || ret=1
sh gather_preload.sh i586/kiwi-image-livecd-kde $proj || ret=1
sh gather_preload.sh x86_64/kiwi-image-livecd-gnome $proj || ret=1
sh gather_preload.sh i586/kiwi-image-livecd-gnome $proj || ret=1
if test "$ret" = 0; then 
  rm -f lock
  exit 0
fi
#cp i586_kiwi-image-livecd-gnome/rpmversion i586_kiwi-image-livecd-x11/rpmversion
#cp i586_kiwi-image-livecd-gnome/rpmversion x86_64_kiwi-image-livecd-x11/rpmversion

for flavor in x11 gnome kde; do 
  lines=`cat *-$flavor/rpmversion | sort -u | wc -l`
  if test "$lines" -gt 1; then
    echo "$lines different versions"
    continue
  fi
  rpmv=`cat *-$flavor/rpmversion | sort -u`
  rm -rf openSUSE:Factory:Live 
  osc checkout openSUSE:Factory:Live/preload-lists-$flavor
  for arch in x86_64 i586; do
    if test -f "$arch"_kiwi-image-livecd-$flavor/trace; then
      cp "$arch"_kiwi-image-livecd-$flavor/trace openSUSE:Factory:Live/preload-lists-$flavor/livecd-$flavor-$arch || true
      cp "$arch"_kiwi-image-livecd-$flavor/clic openSUSE:Factory:Live/preload-lists-$flavor/clic-$flavor-$arch || true
    fi
  done
  sed -i -e "s,Provides:.*cliclists.*,Provides: cliclists-$flavor = $rpmv," openSUSE:Factory:Live/preload-lists-$flavor/preload-lists-$flavor.spec
  commit=$(git log -n 1 HEAD | head -n 1)
  osc commit -m "$commit $rpmv" openSUSE:Factory:Live/preload-lists-$flavor
  rm -rf openSUSE:Factory:Live
done
git commit -a -m "new run $rpmv"
git push
rm -f lock

