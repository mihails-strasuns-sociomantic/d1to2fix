# Arch Linux PKGBUILD system only allows access
# to URLs and files unpacked into the same directory, thus
# extra shell script is needed to prepare files

git clone .. d1to2fix
tar -cJf d1to2fix.tar.xz ./d1to2fix
makepkg
