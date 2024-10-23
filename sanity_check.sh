#!/usr/bin/env bash

# gem install standardrb erb_lint

standardrb app.rb
erb_lint views/*
