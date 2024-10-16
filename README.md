# README

## How to Run On Windows Mcahine
- Make sure gemfile contains the following lines:
    - gem 'psych', '4.0.0' 
        - we need to look it to 4.0.0 otherwise installation will fail
            - conjecture - when trying to install latest version, it runs some C++ code to try to install a library. Since C++ doesn't have the cisco certificate (just like ruby used to not have it) it fails to install the library, causing the overall installation to fail.
    - gem 'tzinfo-data'

This README would normally document whatever steps are necessary to get the
application up and running.

Things you may want to cover:

* Ruby version

* System dependencies

* Configuration

* Database creation

* Database initialization

* How to run the test suite

* Services (job queues, cache servers, search engines, etc.)

* Deployment instructions

* ...
