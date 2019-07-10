ARG BUILD_IMAGE=centos:7
ARG BASE=centos
# Install golang since the package managed one probably is too old and ppa's don't cover all distros
ARG GOLANG_IMAGE
FROM ${GOLANG_IMAGE} as golang

FROM alpine:3.8 as containerd
RUN apk -u --no-cache add git
ARG REF=master
RUN git clone https://github.com/containerd/containerd.git /containerd
RUN git -C /containerd checkout ${REF}

FROM alpine:3.8 as runc
RUN apk -u --no-cache add git
ARG RUNC_REF=master
RUN git clone https://github.com/opencontainers/runc.git /runc
RUN git -C /runc checkout ${RUNC_REF}

FROM ${BUILD_IMAGE} as centos-base
RUN yum install -y rpm-build git
# Overwrite repo that was failing on aarch64
RUN sed -i 's/altarch/centos/g' /etc/yum.repos.d/CentOS-Sources.repo

FROM ${BUILD_IMAGE} as fedora-base
RUN dnf install -y rpm-build git dnf-plugins-core

FROM ${BUILD_IMAGE} as suse-base
# On older versions of Docker the path may not be explicitly set
# opensuse also does not set a default path in their docker images
ENV PATH /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH
RUN zypper install -y git rpm rpm-build libbtrfs-devel libseccomp-devel
RUN echo "%_topdir    /root/rpmbuild" > /root/.rpmmacros

FROM ${BUILD_IMAGE} as amzn-base
RUN yum install -y yum-utils rpm-build git

FROM ${BASE}-base
COPY --from=golang /usr/local/go /usr/local/go/
ENV GOPATH /go
ENV PATH "$PATH:/usr/local/go/bin:$GOPATH/bin"
RUN go get github.com/cpuguy83/go-md2man

COPY common/ /root/rpmbuild/SOURCES/
COPY rpm/containerd.spec /root/rpmbuild/SPECS/containerd.spec
COPY scripts/build-rpm /build-rpm
COPY scripts/.rpm-helpers /.rpm-helpers

RUN mkdir -p /go
ARG REF
ENV GO_SRC_PATH /go/src/github.com/containerd/containerd
COPY --from=containerd /containerd /go/src/github.com/containerd/containerd
COPY --from=runc /runc /go/src/github.com/opencontainers/runc

WORKDIR /root/rpmbuild
ENTRYPOINT ["/build-rpm"]
