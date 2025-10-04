FROM ubuntu:24.04
RUN apt-get update
RUN apt-get install -y vim tmux curl ruby ruby-dev git build-essential
RUN gem install bundler

RUN mkdir /opt/sgm
WORKDIR /opt/sgm
COPY opt/sgm/Gemfile /opt/sgm/Gemfile
RUN bundle

COPY .vimrc /root/.vimrc
ENTRYPOINT sleep infinity
