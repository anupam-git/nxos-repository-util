#!/bin/sh

createAmd64Mirrors() {
  echo "CREATING REPOSITORY MIRRORS"

  echo "  - Adding Key for Ubuntu Xenial"
  gpg --no-default-keyring --keyring trustedkeys.gpg --keyserver keys.gnupg.net --recv-keys 40976EAF437D05B5 3B4FE6ACC0B21F32 2>&1 | sed -e 's/^/    * /'
  echo "  - Creating AMD64 Mirror for Ubuntu Bionic : bionic"
  # aptly mirror create -architectures="amd64" xenial http://archive.ubuntu.com/ubuntu xenial main universe multiverse restricted 2>&1 | sed -e 's/^/    * /'
  aptly mirror create -filter="cryptsetup|gcc|make|chromium-browser|mobile-broadband-provider-info|pm-utils|pulseaudio-module-bluetooth|grub2-common|ubuntu-drivers-common|x11-session-utils|xinit|xorg|acpi-support|acpid|alsa-base|bluez-cups|dc|linux-sound-base|linux-image-generic|rfkill|sbsigntool|inputattach|kerneloops-daemon|mscompress|pcmciautils|policykit-desktop-privileges|fwupd|fwupdate|fwupdate-signed|pm-utils|pulseaudio-module-bluetooth|mobile-broadband-provider-info|pulseaudio" -filter-with-deps -architectures="amd64" bionic http://archive.ubuntu.com/ubuntu bionic main universe multiverse restricted 2>&1 | sed -e 's/^/    * /'

  # echo "  - Creating AMD64 Mirror for Ubuntu Xenial - Updates : xenial-updates"
  # aptly mirror create -architectures="amd64" xenial-updates http://archive.ubuntu.com/ubuntu xenial-updates main universe multiverse restricted 2>&1 | sed -e 's/^/    * /'

  # echo "  - Creating AMD64 Mirror for Ubuntu Xenial - Security : xenial-security"
  # aptly mirror create -architectures="amd64" xenial-security http://archive.ubuntu.com/ubuntu xenial-security # main universe multiverse restricted 2>&1 | sed -e 's/^/    * /'

  echo
  echo "  - Adding Key for KDENeon Bionic"
  gpg --no-default-keyring --keyring trustedkeys.gpg --keyserver keys.gnupg.net --recv-keys E6D4736255751E5D 2>&1 | sed -e 's/^/    * /'
  echo "  - Creating AMD64 Mirror for KDENeon Bionic : kdeneon-bionic"
  # aptly mirror create -architectures="amd64" kdeneon-xenial https://archive.neon.kde.org/user/ xenial main 2>&1 | sed -e 's/^/    * /'
  aptly mirror create -filter="phonon-backend-gstreamer|gstreamer1.0-pulseaudio|frameworkintegration|kimageformat-plugins|qt5-image-formats-plugins|sddm|baloo-kf5|breeze|kde-cli-tools|khotkeys|kinfocenter|kio|kio-extras|kmenuedit|ksysguard|kwin|oxygen-sounds|plasma-desktop|powerdevil|systemsettings|plasma-widgets-addons|kde-config-gtk-style|polkit-kde-agent-1|bluedevil|kwin-addons|kscreen|milou|plasma-nm|kde-config-sddm|user-manager|plasma-pa|konsole|kcalc|ark|dolphin|kde-spectacle|kate|qapt-deb-installer|oxygen-icon-theme|partitionmanager|python-qt4-dbus|gtk2-engines-oxygen|gtk3-engines-breeze|kdeconnect|qpdfview|upower|udisks2|xdg-utils|cdrdao|libqca2-plugin-ossl|qtdeclarative5-xmllistmodel-plugin|libqt5qml-graphicaleffects|xdg-user-dirs" -filter-with-deps -architectures="amd64" kdeneon-bionic https://archive.neon.kde.org/dev/stable/ bionic main 2>&1 | sed -e 's/^/    * /'

  echo
  echo "  - Adding Key for NXOS"
  wget -O - http://repo.nxos.org/public.key | gpg --no-default-keyring --keyring trustedkeys.gpg --import 2>&1 | sed -e 's/^/    * /'
  echo "  - Creating Mirror for NXOS : nxos"
  aptly mirror create nxos http://repo.nxos.org/ nxos main 2>&1 | sed -e 's/^/    * /'
}

updateMirrors() {
  echo "UPDATING MIRRORS"

  case "$1" in
    all)
      TO_BE_UPDATED="xenial xenial-security xenial-update kdeneon-xenial nxos"
    ;;
    
    *)
      TO_BE_UPDATED=$@
    ;;
  esac

  for mirror in $TO_BE_UPDATED
  do
    echo "  - Updating $mirror"
    aptly mirror update $mirror 2>&1 | sed -e 's/^/    * /'
  done
}

upload() {
  NXOS_SERVER_URL=http://88.198.66.58/
  REPO=$1
  FILE=$(realpath $2)

  case "$REPO" in
    development|testing)
      if [ -z "$APTLY_USERNAME" -o -z "$APTLY_API_KEY" ]; then
        echo "Requires APTLY_USERNAME and APTLY_API_KEY to be set before uploading file"
        exit 1
      fi

      echo "DELETING Remote Upload Folder"
      curl -sS -u$APTLY_USERNAME:$APTLY_API_KEY -X DELETE $NXOS_SERVER_URL/aptly-api/files/$REPO-$APTLY_USERNAME 2>&1 | sed -e 's/^/    - /'

      echo
      echo "UPLOADING $FILE"
      curl -sS -u$APTLY_USERNAME:$APTLY_API_KEY -X POST -F file=@$FILE $NXOS_SERVER_URL/aptly-api/files/$REPO-$APTLY_USERNAME 2>&1 | sed -e 's/^/    - /'


      echo
      echo "PUBLISHING to $REPO"
      curl -sS -u$APTLY_USERNAME:$APTLY_API_KEY -X POST $NXOS_SERVER_URL/aptly-api/repos/$REPO/file/$REPO-$APTLY_USERNAME 2>&1 | sed -e 's/^/    - /'

      echo
      echo "UPDATING $REPO"
      curl -sS -u$APTLY_USERNAME:$APTLY_API_KEY -X PUT -H 'Content-Type: application/json' --data '{"local": [{"Component": "main"}]}' $NXOS_SERVER_URL/aptly-api/publish/:$REPO/nxos
    ;;

    *)
      echo "Invalid Repository"
      exit 1
    ;;
  esac
}

HELPTEXT="nxos-repository-util : A Simple Tool to manage NXOS repository with Aptly

USAGE :
  nxos-repository-util [OPTION]

OPTIONS :
  -h | --help
  create-amd64-mirrors
  update-mirrors [all | (list of space seperated mirrors)]
  upload [development | testing] [file]
"

case "$1" in
  --help|-h)
    echo "$HELPTEXT"
    exit 0
  ;;

  create-amd64-mirrors)
    shift
    createAmd64Mirrors $@
  ;;

  update-mirrors)
    shift

    if [ $# -eq 0 ]; then
      echo "Error parsing the arguments"
      echo "$HELPTEXT"
      exit 1
    else
      updateMirrors $@
    fi
  ;;

  upload)
    shift

    if [ $# -ne 2 ]; then
      echo "Invalid Number of Arguments"
      echo "$HELPTEXT"
      exit 1
    else
      upload $@
    fi
  ;;

  *)
    echo "Error parsing the arguments"
    echo "$HELPTEXT"
    exit 1
  ;;
esac

exit 0