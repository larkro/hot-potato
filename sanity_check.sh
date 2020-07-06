#!/usr/bin/env bash

# gem install standardrb erb_lint

standardrb app.rb
erblint views/*
