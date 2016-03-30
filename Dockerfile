FROM centos:7

RUN yum -y update
RUN rpm -iUvh http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-5.noarch.rpm
RUN yum -y update


# Install dependencies required to build Barbican
RUN yum install -y \
    python-pip \
    python-devel \
    libffi-devel \
    openssl-devel \
    sqlite-devel \
    openldap-devel

# Install dependencies required for PyEnv
RUN yum install -y \
    git \
    curl \
    make \
    gcc \
    gcc-c++ \
    make \
    openssl-devel \
    libxml2 \
    libxml2-devel \
    libxslt \
    libxslt-devel \
    zlib-devel \
    bzip2-devel \
    readline-devel \
    patch \
    openssl

# Install dependency for the PyEnv - virtualenvwrapper plugin
RUN pip install virtualenvwrapper

RUN yum install -y \
    python-setuptools \
    python-lxml \
    python-greenlet-devel \
    python-ldap \
    vim \
    jq

WORKDIR /root

RUN git clone https://github.com/openstack/barbican.git

WORKDIR /root/barbican
RUN pip install -r /root/barbican/requirements.txt
RUN python setup.py install
RUN pip install uwsgi
RUN mkdir -p /etc/barbican
RUN mkdir -p /var/lib/barbican
RUN mkdir -p /etc/barbican/vassals
RUN cp etc/barbican/barbican-api-paste.ini /etc/barbican/barbican-api-paste.ini
RUN cp etc/barbican/barbican.conf /etc/barbican/barbican.conf
RUN cp etc/barbican/policy.json /etc/barbican/policy.json
RUN cp etc/barbican/vassals/barbican-api.ini /etc/barbican/vassals/barbican-api.ini

WORKDIR /

RUN easy_install supervisor
RUN /usr/bin/echo_supervisord_conf > /etc/supervisord.conf

RUN mkdir -p /var/log/supervisor

# make supervisor run in foreground
RUN sed -i -e "s/^nodaemon=false/nodaemon=true/" /etc/supervisord.conf

# tell supervisor to include relative .ini files
RUN mkdir /etc/supervisord.d
RUN echo [include] >> /etc/supervisord.conf
RUN echo 'files = /etc/supervisord.d/*.ini' >> /etc/supervisord.conf

# add barbican-svc program to supervisord config
RUN echo [program:barbican-svc] >> /etc/supervisord.d/barbican-svc.ini
RUN echo 'command=uwsgi --master --emperor /etc/barbican/vassals' >> /etc/supervisord.d/barbican-svc.ini
RUN echo  >> /etc/supervisord.d/barbican-svc.ini

# add barbican-retry program to supervisord config
RUN echo [program:barbican-retry] >> /etc/supervisord.d/barbican-retry.ini
RUN echo 'command=/usr/bin/barbican-retry --config-file=/etc/barbican/barbican-api.conf' >> /etc/supervisord.d/barbican-retry.ini
RUN echo  >> /etc/supervisord.d/barbican-retry.ini

EXPOSE 9311

# default command
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]

