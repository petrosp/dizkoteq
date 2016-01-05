# FROM petrosp/rails-nginx:v0.0.1

# RUN mkdir -p /app
# WORKDIR /app
# COPY Gemfile Gemfile.lock ./
# RUN bundle install --jobs 20 --retry 5
# EXPOSE 3000
# ENTRYPOINT ["bundle", "exec"]
# CMD ["bundle", "exec","rails", "s", "-b", "0.0.0.0", "-p", "3000"]

# The FROM instruction sets the Base Image for subsequent instructions. As such,
# a valid Dockerfile must have FROM as its first instruction. We use
# phusion/baseimage as a base image. To make our builds reproducible, we make
# sure we lock down to a specific version, not to `latest`!
FROM phusion/passenger-ruby22:0.9.16

# The MAINTAINER instruction allows you to set the Author field of the generated
# images.
MAINTAINER "Job King'ori Maina" <yo@kingori.co> (@itsmrwave)

# The RUN instructions will execute any commands in a new layer on top of the
# current image and commit the results. The resulting committed image will be
# used for the next step in the Dockerfile.

# === 1 ===

# Prepare for packages
RUN apt-get update --assume-yes && apt-get install --assume-yes build-essential

# For a JS runtime
# http://nodejs.org/
RUN apt-get install --assume-yes nodejs

# For Nokogiri gem
# http://www.nokogiri.org/tutorials/installing_nokogiri.html#ubuntu___debian
RUN apt-get install --assume-yes libxml2-dev libxslt1-dev

# For RMagick gem
# https://help.ubuntu.com/community/ImageMagick
RUN apt-get install --assume-yes libmagickwand-dev

# Clean up APT when done.
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# === 2 ===

# Set correct environment variables.
ENV HOME /root

# Use baseimage-docker's init process.
CMD ["/sbin/my_init"]

# === 3 ====

# By default Nginx clears all environment variables (except TZ). Tell Nginx to
# preserve these variables. See nginx-env.conf.
COPY nginx-env.conf /etc/nginx/main.d/rails-env.conf

# Nginx and Passenger are disabled by default. Enable them (start Nginx/Passenger).
RUN rm -f /etc/service/nginx/down

# Expose Nginx HTTP service
EXPOSE 80

# === 4 ===

# Our application should be placed inside /home/app. The image has an app user
# with UID 9999 and home directory /home/app. Our application is supposed to run
# as this user. Even though Docker itself provides some isolation from the host
# OS, running applications without root privileges is good security practice.
RUN mkdir -p /home/app/myapp
WORKDIR /home/app/myapp

# Run Bundle in a cache efficient way. Before copying the whole app, copy just
# the Gemfile and Gemfile.lock into the tmp directory and ran bundle install
# from there. If neither file changed, both instructions are cached. Because
# they are cached, subsequent commands—like the bundle install one—remain
# eligible for using the cache. Why? How? See ...
# http://ilikestuffblog.com/2014/01/06/how-to-skip-bundle-install-when-deploying-a-rails-app-to-docker/
COPY Gemfile /home/app/myapp/
COPY Gemfile.lock /home/app/myapp/
RUN chown -R app:app /home/app/myapp
RUN sudo -u app bundle install --deployment --without test development doc

# === 5 ===

# Adding our web app to the image ... only after bundling do we copy the rest of
# the app into the image.
COPY . /home/app/myapp
RUN chown -R app:app /home/app/myapp

# === 6 ===

# Remove the default site. Add a virtual host entry to Nginx which describes
# where our app is, and Passenger will take care of the rest. See nginx.conf.
RUN rm /etc/nginx/sites-enabled/default
COPY nginx.conf /etc/nginx/sites-enabled/myapp.conf