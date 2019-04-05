FROM caldweba/opengl-docker

# avoid questions from debconf
ENV DEBIAN_FRONTEND noninteractive

# packages neded for NEURON and graphics
# - Includes fixes the issue where importing OpenGL in python throws an error
#    (I assume that this works by installing the OpenGL for qt4 and then updating? it's not clear...)
#    I think that this is an error in the repos, not our fault.
# - These packages are needed for X display libxaw7 libxmu6 libxpm4
RUN apt-get update && \
    apt-get install -y  --no-install-recommends \
            build-essential bison flex automake libtool \
            git vim iputils-ping net-tools \
            iproute2 nano sudo telnet ca-certificates \
            python3-pip libx11-6 libxext6 openmpi-bin && \
    pip3 install matplotlib && \
    rm -rf /root/.cache && \
    apt-get autoremove -y --purge

# create the group hnn_group and user hnn_user
# add hnn_user to the sudo group
RUN groupadd hnn_group && \
    useradd -m -b /home/ -g hnn_group hnn_user && \
    adduser hnn_user sudo && \
    echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers


# copy the start script into the container
COPY start_hnn.sh /home/hnn_user/

RUN chown hnn_user:hnn_group /home/hnn_user/start_hnn.sh && \
    chmod +x /home/hnn_user/start_hnn.sh


RUN cd /tmp && \
    git clone https://github.com/neuronsimulator/iv && \
    cd iv && \
    apt-get install -y  --no-install-recommends \
            libx11-dev libxext-dev && \
    git checkout d4bb059 -b stable && \
    ./build.sh && \
    ./configure && \
    make -j4 && \
    make install && \
    sudo apt-get remove -y --purge \
            libxext-dev && \
    apt-get autoremove -y --purge && \
    cd .. && \
    rm -rf /tmp/iv

RUN cd /tmp && \
    git clone https://github.com/neuronsimulator/nrn && \
    cd nrn && \
    apt-get install -y --no-install-recommends \
            zlib1g-dev libopenmpi-dev libpython3-dev libncurses5-dev  libreadline-gplv2-dev \
            openssh-client && \
    ./build.sh && \
    ./configure --with-nrnpython=python3 --with-paranrn --disable-rx3d \
            --with-iv=/usr/local/iv && \
    make -j4 && \
    make install && \
    cd src/nrnpython && \
    python3 setup.py install && \
    sudo apt-get remove -y --purge \
            zlib1g-dev libopenmpi-dev libpython3-dev && \
    apt-get autoremove -y --purge && \
    cd .. && \
    rm -rf /tmp/nrn

USER hnn_user

# create the global session variables
RUN echo '# these lines define global session variables for HNN' >> ~/.bashrc && \
    echo 'export CPU=$(uname -m)' >> ~/.bashrc && \
    echo 'export PATH=$PATH:/usr/local/nrn/$CPU/bin' >> ~/.bashrc

# allow user to specify architecture if different than x86_64
ARG CPU=x86_64
# supply the path NEURON binaries for building hnn
ENV PATH=${PATH}:/usr/local/nrn/$CPU/bin

RUN sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
                 python3-pyqt5 python3-pyqtgraph python3-pyqt4.qtopengl libllvm5.0 python3-tk \
                 python3-opengl qt5dxcb-plugin python3-scipy libopenmpi-dev && \
    cd $HOME && \
    git clone https://github.com/jonescompneurolab/hnn.git hnn_repo && \
    cd hnn_repo && \
    make && \
    sudo apt-get remove -y --purge \
                 python3-dev libopenmpi-dev \
                 build-essential libxext-dev bison flex automake libtool && \
    sudo apt-get autoremove -y --purge

# run sudo to get rid of message on first login about using sudo
# create the hnn shared folder (don't rely on docker daemon
# to create it)
RUN sudo -l && \
    mkdir /home/hnn_user/hnn

# if users open up a shell, they should go to the hnn repo checkout
WORKDIR /home/hnn_user/hnn_repo

CMD /home/hnn_user/start_hnn.sh
