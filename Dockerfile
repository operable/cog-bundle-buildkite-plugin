FROM operable/cog:0.16.2

# The above gets us cogctl
# The below gets us testing stuff

USER root

ENV RUBY_VERSION 2.3.1-r0

RUN apk -U add \
    ruby=$RUBY_VERSION \
    ruby-dev=$RUBY_VERSION \
    ruby-json=$RUBY_VERSION \
    ruby-bundler=1.12.5-r0 \
    diffutils=3.3-r0

RUN gem install rspec --no-ri --no-rdoc

COPY hooks/common.sh /hooks/common.sh
COPY scripts/config_with_testing_image /usr/bin/config_with_testing_image
COPY scripts/wait-for-it-alpine.sh /usr/bin/wait-for-it.sh
COPY integration /integration
COPY scripts/run /usr/bin/run
