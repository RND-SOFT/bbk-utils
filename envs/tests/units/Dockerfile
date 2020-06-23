ARG BASE_IMAGE=ruby:2.5-alpine
ARG BUILD_TAG=2.5

FROM ${BASE_IMAGE} as buildbase

WORKDIR /home/app

RUN set -ex \
  && apk add --no-cache build-base git curl postgresql-dev postgresql-client libstdc++ libxml2

  
FROM buildbase:${BUILD_TAG} as image

RUN mkdir -p /usr/local/etc \
  && { \
    echo 'install: --no-document'; \
    echo 'update: --no-document'; \
  } >> /usr/local/etc/gemrc \
  && echo 'gem: --no-document' > ~/.gemrc

WORKDIR /home/app

ARG GEM_STORAGE_AUTH

ENV BUNDLE_NEXUS__RNDS__LOCAL ${GEM_STORAGE_AUTH}

ADD Gemfile Gemfile.lock *.gemspec /home/app/
ADD lib/aggredator/utils/version.rb /home/app/lib/aggredator/utils/

RUN set -ex \
  && gem source --add http://${GEM_STORAGE_CREDS}@nexus.rnds.local/repository/internal/ \
  && gem install bundler && gem update bundler \
  && ping -c 1 nexus.rnds.local \
  && bundle install --jobs=3 --full-index \
  && rm -rf /tmp/* /var/tmp/* /usr/src/ruby /root/.gem /usr/local/bundle/cache

ADD . /home/app/

RUN set -ex \
  && bundle install --jobs=3 --full-index \
  && rm -rf /tmp/* /var/tmp/* /usr/src/ruby /root/.gem /usr/local/bundle/cache

CMD ["tail", "-f", "/dev/null"]


