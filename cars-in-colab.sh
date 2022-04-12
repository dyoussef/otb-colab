#!/bin/bash
set -e
PROGNAME=$0
usage() {
    cat << EOF >&2
Usage: $PROGNAME [-f]

       -f: install from scratch (compiling OTB ~20min)
EOF
    exit 1
}

FROM_SCRATCH=0
while getopts f o; do
    case $o in
	(f) FROM_SCRATCH=1;;
	(*) usage
    esac
done
shift "$((OPTIND - 1))"

# install ubuntu packages
echo ">> (1/5) Install Ubuntu packages (expected duration: ~2min)"
SECONDS=0
add-apt-repository -y  ppa:ubuntugis/ubuntugis-unstable 1>/dev/null 2>&1
apt-get update 1>/dev/null 2>&1 && apt-get install --no-install-recommends -y \
    cmake-curses-gui \
    git \
    wget \
    file \
    apt-utils \
    gcc \
    g++ \
    make \
    unzip \
    ninja-build \
    libboost-date-time-dev \
    libboost-filesystem-dev \
    libboost-graph-dev \
    libboost-program-options-dev \
    libboost-system-dev \
    libboost-thread-dev \
    libgdal-dev \
    libinsighttoolkit4-dev \
    libopenthreads-dev \
    libossim-dev \
    libtinyxml-dev \
    libmuparser-dev \
    libmuparserx-dev \
    libsvm-dev \
    swig \
    libfftw3-dev 1>/dev/null 2>&1 \
    && rm -rf /var/lib/apt/lists/*
echo "Elapsed time: ${SECONDS} seconds"

SECONDS=0
if [ "$FROM_SCRATCH" -eq 0 ]
then
    # download pre-compiled-otb
    echo ">> (2/5) Download pre-compiled-otb (expected duration: <1s)"
    wget https://raw.githubusercontent.com/dyoussef/otb-colab/main/otb.tar.gz 1>/dev/null 2>&1

else
    # create orfeo toolbox archive
    echo ">> (2/5) Create pre-compiled-otb (expected duration: ~20min)"
    SECONDS=0
    mkdir -p /opt/otb && cd /opt/otb && \
	wget -q https://www.orfeo-toolbox.org/packages/archives/OTB/OTB-7.4.0.zip -O /tmp/OTB-7.4.0.zip && \
	unzip -q /tmp/OTB-7.4.0.zip && rm /tmp/OTB-7.4.0.zip

    mkdir -p /opt/otb/build && cd /opt/otb/build && cmake \
	"-DBUILD_COOKBOOK:BOOL=OFF" "-DBUILD_EXAMPLES:BOOL=OFF" "-DBUILD_SHARED_LIBS:BOOL=ON" \
	"-DBUILD_TESTING:BOOL=OFF" "-DOTB_USE_6S:BOOL=OFF" "-DOTB_USE_CURL:BOOL=ON" \
	"-DOTB_USE_GLEW:BOOL=OFF" "-DOTB_USE_GLFW:BOOL=OFF" "-DOTB_USE_GLUT:BOOL=OFF" \
	"-DOTB_USE_GSL:BOOL=OFF" "-DOTB_USE_LIBKML:BOOL=OFF" "-DOTB_USE_LIBSVM:BOOL=ON" \
	"-DOTB_USE_MPI:BOOL=OFF" "-DOTB_USE_MUPARSER:BOOL=ON" "-DOTB_USE_MUPARSERX:BOOL=ON" \
	"-DOTB_USE_OPENCV:BOOL=OFF" "-DOTB_USE_OPENGL:BOOL=OFF" "-DOTB_USE_OPENMP:BOOL=OFF" \
	"-DOTB_USE_QT:BOOL=OFF" "-DOTB_USE_QWT:BOOL=OFF" "-DOTB_USE_SIFTFAST:BOOL=ON" \
	"-DOTB_USE_SPTW:BOOL=OFF" "-DOTB_WRAP_PYTHON:BOOL=ON" "-DCMAKE_BUILD_TYPE=Release" \
	"-DOTB_USE_SHARK:BOOL=OFF" "-DBUILD_EXAMPLES:BOOL=OFF" \
	-DCMAKE_INSTALL_PREFIX="/usr/local/otb" -GNinja .. 1>/dev/null 2>&1 && \
	ninja install && \
	rm -rf /opt/otb
    cd /usr/local && tar cvfz otb.tar.gz otb && mv otb.tar.gz /content/.
    cd /content
fi
echo "Elapsed time: ${SECONDS} seconds"

# untar pre-compiled otb
echo ">> (3/5) Untar pre-compiled-otb	(expected duration: <1s)"
SECONDS=0
tar --strip-components 1 -xvf otb.tar.gz -C /usr 1>/dev/null 2>&1
echo "Elapsed time: ${SECONDS} seconds"

# install vlfeat
echo ">> (4/5) Install vlfeat library (expected duration: ~20s)"
SECONDS=0
# https://github.com/vlfeat/vlfeat/issues/214
cd /opt && git clone https://github.com/vlfeat/vlfeat.git 1>/dev/null 2>&1
cd /opt/vlfeat && \
    sed -i 's/default(none)//g' vl/kmeans.c \
    && make 1>/dev/null 2>&1 \
    && cp bin/glnxa64/libvl.so /usr/lib \
    && mkdir -p /usr/local/include/vl \
    && cp -r vl/*.h /usr/local/include/vl && \
    cd /opt && rm -rf vlfeat 
echo "Elapsed time: ${SECONDS} seconds"

# copy and install cars
echo ">> (5/5) Install CARS with python dependencies (expected duration: ~6min30)"
SECONDS=0
# set variables for cars installation
export OTB_APPLICATION_PATH="/usr/lib/otb/applications"
export VLFEAT_INCLUDE_DIR="/usr/local/include"
cd /opt && git clone https://github.com/cnes/cars.git 1>/dev/null 2>&1

# cars installation
pip install libsgm==0.4.0 1>/dev/null 2>&1
cd /opt/cars && export CARS_VENV=/usr/local && make install 1>/dev/null 2>&1

# copy some files to avoid changing environment variables
cp /usr/lib/otb/python/otbApplication.py /usr/local/lib/python3.7/dist-packages/.
cp /usr/lib/otb/python/_otbApplication.so /usr/local/lib/python3.7/dist-packages/.
cp /usr/lib/otbapp_* /usr/lib/otb/applications/.
echo "Elapsed time: ${SECONDS} seconds"

echo ">> CARS is installed"
