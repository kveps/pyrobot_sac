# set the base image
FROM ubuntu:16.04

# author
MAINTAINER Karthik Vijayakumar

# basic container setup
RUN apt-get update
RUN apt-get install sudo

# ros-kinetic-librealsense fails while installng ros-kinetic-desktop-full inside a container 
# more details at `https://github.com/IntelRealSense/librealsense/issues/4781` 
# workaround as suggested in the above link
RUN apt-get install -y lsb-release
RUN apt-key adv --keyserver 'hkp://keyserver.ubuntu.com:80' --recv-key C1CF6E31E6BADE8868B172B4F42ED6FBAB17C654
RUN echo "deb http://packages.ros.org/ros/ubuntu $(lsb_release -sc) main" > /etc/apt/sources.list.d/ros-latest.list 
RUN apt-get update

# dependencies needed by librealsense. `deb -i` will not resolve these
RUN apt-get install -y binutils cpp cpp-5 dkms fakeroot gcc gcc-5 kmod libasan2 libatomic1 libc-dev-bin libc6-dev libcc1-0 libcilkrts5 libfakeroot libgcc-5-dev libgmp10 libgomp1 libisl15 libitm1 liblsan0 libmpc3 libmpfr4 libmpx0 libquadmath0 libssl-dev libssl-doc libtsan0 libubsan0 libusb-1.0-0 libusb-1.0-0-dev libusb-1.0-doc linux-headers-4.4.0-159 linux-headers-4.4.0-159-generic linux-headers-generic linux-libc-dev make manpages manpages-dev menu patch zlib1g-dev
RUN apt-get install -y libssl-dev libssl-doc libusb-1.0-0 libusb-1.0-0-dev libusb-1.0-doc linux-headers-4.4.0-159 linux-headers-4.4.0-159-generic linux-headers-generic zlib1g-dev

# modify librealsense deb (unpack, replace script, repack)
RUN apt-get download ros-kinetic-librealsense
RUN dpkg-deb -R ros-kinetic-librealsense*.deb ros-rslib/
RUN wget https://gist.githubusercontent.com/dizz/404ef259a15e1410d692792da0c27a47/raw/3769e80a051b5f2ce2a08d4ee6f79c766724f495/postinst
RUN chmod +x postinst
RUN cp postinst ros-rslib/DEBIAN
RUN dpkg-deb -b ./ros-rslib/ ros-kinetic-librealsense_1.12.1-0xenial-20190830_icrlab_amd64.deb

# install container friendly libsense
RUN dpkg -i ros-kinetic-librealsense_1.12.1-0xenial-20190830_icrlab_amd64.deb

# lock from updates
RUN apt-mark hold ros-kinetic-librealsense

# install pyrobot
# `https://github.com/facebookresearch/pyrobot`
RUN sudo apt-get install curl
RUN /bin/bash -c "alias python='/usr/bin/python3.5'"
RUN /bin/bash -c ". /root/.bashrc"
RUN sudo apt install -y python3-pip
RUN pip3 install numpy --upgrade
RUN curl 'https://raw.githubusercontent.com/facebookresearch/pyrobot/master/robots/LoCoBot/install/locobot_install_all.sh' > /root/locobot_install_all.sh
RUN chmod +x /root/locobot_install_all.sh
RUN /bin/bash -c "cd /root/; ./locobot_install_all.sh -t sim_only -p 3"; exit 0

# compile tf2_ros for python3, else pyrobot import will fail
# more details at `https://answers.ros.org/question/326226/importerror-dynamic-module-does-not-define-module-export-function-pyinit__tf2/`
RUN sudo apt update
RUN sudo apt install python3-catkin-pkg-modules python3-rospkg-modules python3-empy
RUN /bin/bash -c ". /opt/ros/kinetic/setup.bash; cd /root/pyrobot_catkin_ws; catkin_make"
RUN /bin/bash -c ". /root/pyrobot_catkin_ws/devel/setup.bash"
RUN /bin/bash -c "cd /root/pyrobot_catkin_ws; wstool init"
RUN /bin/bash -c "cd /root/pyrobot_catkin_ws; wstool set -y src/geometry2 --git https://github.com/ros/geometry2 -v 0.6.5"
RUN /bin/bash -c "cd /root/pyrobot_catkin_ws; wstool up"
RUN /bin/bash -c "cd /root/pyrobot_catkin_ws; rosdep install --from-paths src --ignore-src -y -r"
RUN /bin/bash -c ". /opt/ros/kinetic/setup.bash; cd /root/pyrobot_catkin_ws; catkin_make --cmake-args \
            -DCMAKE_BUILD_TYPE=Release \
            -DPYTHON_EXECUTABLE=/usr/bin/python3 \
            -DPYTHON_INCLUDE_DIR=/usr/include/python3.6m \
            -DPYTHON_LIBRARY=/usr/lib/x86_64-linux-gnu/libpython3.6m.so"

# install gym and pybullet
RUN pip3 install gym
RUN pip3 install pybullet

# clone the softlearning repository and install
# `https://github.com/rail-berkeley/softlearning`
RUN git clone https://github.com/rail-berkeley/softlearning.git /root/softlearning
RUN /bin/bash -c "cd /root/softlearning; python setup.py build"
RUN /bin/bash -c "cd /root/softlearning; python setup.py install"

# activate the pyrobot environment
RUN /bin/bash -c ". /root/pyenv_pyrobot_python3/bin/activate"