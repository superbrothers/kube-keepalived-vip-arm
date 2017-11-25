# Copyright 2017 Kazuki Suda.
# For the full copyright and license information, please view the LICENSE.txt
# file that was distributed with this source code.

# Copyright 2015 The Kubernetes Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

FROM gcr.io/google_containers/ubuntu-slim-arm:0.14

ARG GIT_COMMIT=75102e05058dc902c4b0510fbe3b6d8a54464349
ARG VERSION=1.2.24
ARG SHA256=b508d4591c1c0173f1bf1274d69eed139fa875ff51f5429f4f714e5c72cf06b4

RUN set -x && \
 apt-get update && \
 apt-get install -y --no-install-recommends bash git && \
 git clone git://github.com/kubernetes/contrib.git && \
 cd contrib && \
 git checkout $GIT_COMMIT && \
 bash -x keepalived-vip/build/build.sh

FROM golang:1.9

COPY --from=0 /contrib/keepalived-vip /go/src/keepalived-vip
RUN set -x && \
 cd /go/src/keepalived-vip && \
 CGO_ENABLED=0 GOOS=linux GOARCH=arm GOARM=7 go build -a -ldflags '-w' -o /kube-keepalived-vip

FROM gcr.io/google_containers/ubuntu-slim-arm:0.14

RUN set -x && \
  apt-get update && apt-get install -y --no-install-recommends \
    libssl1.0.0 \
    libnl-3-200 \
    libnl-route-3-200 \
    libnl-genl-3-200 \
    iptables \
    libnfnetlink0 \
    libiptcdata0 \
    libipset3 \
    libipset-dev \
    libsnmp30 \
    kmod \
    ca-certificates \
    iproute2 \
    ipvsadm \
    bash && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/*

COPY --from=0 /keepalived /

RUN set -x && \
  mkdir -p /etc/keepalived && \
  ln -s /keepalived/sbin/keepalived /usr/sbin && \
  ln -s /keepalived/bin/genhash /usr/sbin

COPY --from=1 /kube-keepalived-vip /
COPY --from=0 /contrib/keepalived-vip/keepalived.tmpl /
COPY --from=0 /contrib/keepalived-vip/keepalived.conf /etc/keepalived

ENTRYPOINT ["/kube-keepalived-vip"]
