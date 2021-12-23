ARG RUBY_VERSION=2.5

FROM ruby:${RUBY_VERSION}-alpine

RUN mkdir -p /usr/local/etc \
  && { \
    echo 'install: --no-document'; \
    echo 'update: --no-document'; \
  } >> /usr/local/etc/gemrc \
  && echo 'gem: --no-document' > ~/.gemrc

RUN set -ex \
  && apk add --no-cache build-base git curl

WORKDIR /home/app

ADD Gemfile Gemfile.lock *.gemspec /home/app/
ADD lib/bbk/utils/version.rb /home/app/lib/bbk/utils/

RUN set -ex \
  && gem install bundler && gem update bundler \
  && if [ "${RUBY_VERSION}" \> '3' ]; then gem install 'activesupport:~>6.0' steep; fi \
  && bundle install --jobs=3 --full-index \
  && rm -rf /tmp/* /var/tmp/* /usr/src/ruby /root/.gem /usr/local/bundle/cache

ADD . /home/app/

RUN set -ex \
  && bundle install --jobs=3 --full-index \
  && rm -rf /tmp/* /var/tmp/* /usr/src/ruby /root/.gem /usr/local/bundle/cache

CMD ["tail", "-f", "/dev/null"]


