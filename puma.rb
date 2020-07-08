workers Integer(0)
threads Integer(ENV["MIN_THREADS"] || 1), Integer(ENV["MAX_THREADS"] || 16)

preload_app!

rackup DefaultRackup
port ENV["PORT"] || 4567
environment ENV["RACK_ENV"] || "development"
