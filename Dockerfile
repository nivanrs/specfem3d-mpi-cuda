FROM ubuntu:18.04
# In case the main package repositories are down, use the alternative base image:
# FROM gliderlabs/alpine:3.4

MAINTAINER nivanrs

ARG REQUIRE="sudo build-essential gfortran git byacc zlib1g-dev wget apt-utils openssh-server iproute2 net-tools"
RUN apt update && apt upgrade -y
RUN apt install ${REQUIRE} -y


#### INSTALL MPICH ####
# Source is available at http://www.mpich.org/static/downloads/

# Build Options:
# See installation guide of target MPICH version
# Ex: http://www.mpich.org/static/downloads/3.2/mpich-3.2-installguide.pdf
# These options are passed to the steps below
ARG MPICH_VERSION="3.3.2"
ARG MPICH_MAKE_OPTIONS

# Download, build, and install MPICH
RUN mkdir /tmp/mpich-src
WORKDIR /tmp/mpich-src
RUN wget http://www.mpich.org/static/downloads/${MPICH_VERSION}/mpich-${MPICH_VERSION}.tar.gz \
      && tar xfz mpich-${MPICH_VERSION}.tar.gz  \
      && cd mpich-${MPICH_VERSION}  \
      && ./configure  \
      && make ${MPICH_MAKE_OPTIONS} && make install \
      && rm -rf /tmp/mpich-src
#### CLEAN UP ####
WORKDIR /
RUN rm -rf /tmp/*

#### ADD DEFAULT USER ####
ARG USER=mpi
ENV USER ${USER}
RUN sudo adduser ${USER} 
RUN echo "${USER} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

ENV USER_HOME /home/${USER}
RUN chown -R ${USER}:${USER} ${USER_HOME}

#### CREATE WORKING DIRECTORY FOR USER ####
ARG WORKDIR=/project
ENV WORKDIR ${WORKDIR}
RUN mkdir ${WORKDIR}
RUN chown -R ${USER}:${USER} ${WORKDIR}

WORKDIR ${WORKDIR}
USER ${USER}

#### INSTALL SPECFEM ####
RUN git clone --recursive --branch devel https://github.com/geodynamics/specfem3d.git
WORKDIR ${WORKDIR}/specfem3d/
ENV MPI_INC=/usr/local/include:$MPI_INC=/usr/local/include
ENV LD_LIBRARY_PATH=/usr/local/lib/:$LD_LIBRARY_PATH
RUN ./configure FC=gfortran CC=gcc MPIFC=mpif90 --with-mpi MPI_INC=/usr/local/include USE_BUNDLED_SCOTCH=1 LD_LIBRARY_PATH=/usr/local/lib/
RUN sed -i 's/*compute_20*//g' Makefile
RUN make all

## Install open ssh
User root
WORKDIR /
RUN mkdir /var/run/sshd
RUN sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# SSH login fix. Otherwise user is kicked off after login
RUN sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd

ENV NOTVISIBLE "in users profile"
RUN echo "export VISIBLE=now" >> /etc/profile

EXPOSE 22
CMD ["/bin/bash"]
USER ${USER}

CMD ["/usr/sbin/sshd", "-D"]
CMD ["/bin/bash"]


