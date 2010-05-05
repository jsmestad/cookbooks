maintainer "Absolute Performance, Inc"
license "Apache 2.0"

supports "ubuntu"

depends "aws"
depends "xfs"

attribute "data_dir",
  :display_name => "Data directory",
  :default => "/data/mongodb"
