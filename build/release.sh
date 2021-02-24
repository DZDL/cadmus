#!/usr/bin/env bash
if [[ -z "$1" ]]
  then
    echo "This script generates a release for Cadmus. You must be inside a virtualenv as described in the readme."
    echo "Prerequisites include Docker, binutils, wget, zip, desktop-file-utils and various others."
    echo "Usage: run './release.sh <version number>'"
    exit 1
fi

cd ..
if [[ -d target/ubuntu ]]
then
	echo "Remove target/ubuntu directory before running, it's probably owned by root due to docker"
	exit 1
fi

# STEP 1: Clone repo and Cmake
echo '========== START: CLONING REPO AND CMAKE =========='
git clone https://github.com/werman/noise-suppression-for-voice.git
cd noise-suppression-for-voice
cmake -Bbuild-x64 -H. -DCMAKE_BUILD_TYPE=Release
cd build-x64
make
cp bin/ladspa/librnnoise_ladspa.so ../../src/main/resources/base/librnnoise_ladspa.so
cd ../../
rm -rf noise-suppression-for-voice
mkdir releases/
mkdir releases/$1
echo '========== END: CLONING REPO AND CMAKE =========='

# STEP 2: Build FBS VM
echo '========== START: BUILD FBS VM =========='
python3.6 -m pip install -r requirements.txt
sudo fbs buildvm fedora

echo '========== END: BUILD FBS VM =========='

# STEP 3: Build docker run command identical to fbs, but inject our own bashrc
echo '========== START: BUILD DOCKER IDENTICAL FBS BUT WITH BASHRC =========='
docker_run="docker run -it"
for i in `ls -A | grep -v target` ; do
  docker_run="$docker_run -v `readlink -f $i`:/root/cadmus/$i"
done
docker_run="$docker_run -v `readlink -f ./target/ubuntu`:/root/cadmus/target -v `readlink -f ./build/resources/.bashrc`:/root/.bashrc cadmus/ubuntu "
echo $docker_run
eval $docker_run
echo '========== END: BUILD DOCKER IDENTICAL FBS BUT WITH BASHRC =========='

# STEP 4: Copy artifacts to released directory
echo '========== START: COPY ARTIFACTS TO RELEASE DIRECTORY =========='
cp target/ubuntu/cadmus.deb releases/$1
cd target/ubuntu
zip -r ../../releases/$1/cadmus.zip cadmus
cd ../../
echo '========== END: COPY ARTIFACTS TO RELEASE DIRECTORY =========='

# STEP 5: Build AppImage
echo '========== START: BUILD APPIMAGE =========='
cd build/resources
git clone https://github.com/AppImage/pkg2appimage.git
cp Cadmus.yml ./pkg2appimage/recipes
cd pkg2appimage
cp ../../../releases/$1/cadmus.deb .
./pkg2appimage recipes/Cadmus.yml
cp out/* ../../../releases/$1/cadmus.AppImage
cd ..
rm -rf pkg2appimage
echo "Release artifacts are in: ../releases/$1"
echo '========== END: BUILD APPIMAGE =========='

# todo: create GitHub release & upload artifacts