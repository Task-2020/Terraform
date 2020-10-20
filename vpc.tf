provider "aws" {
    region = "us-east-1"
}
module "vpc" {
    source = "terraform-aws-modules/vpc/aws"
    name = "my-vpc"
    cidr = "10.0.0.0/16"
    azs = ["us-east-1a","us-east-1b","us-east-1c"]
    public_subnets = ["10.0.101.0/24","10.0.102.0/24"]
    enable_nat_gateway = false
    enable_vpn_gateway = false
    tags = {
        terraform = "true"
        environment = "test"
    }   
}
module "security-group"  {
  source = "terraform-aws-modules/security-group/aws"
  version = "3.16.0"
  name        = "web-server"
  description = "Security group for web-server with HTTP ports open within VPC"
  vpc_id      = module.vpc.vpc_id
  ingress_cidr_blocks = ["10.10.0.0/16"]
  tags = {
      terraform = "true"
      environment = "test"
  }
}

module "ec2_instance" {
    source = "terraform-aws-modules/ec2-instance/aws"
    version = "~> 2.0"

    name = "my-instance"
    instance_count = 1
    ami = var.ami
    instance_type = "t2.micro"
    key_name = "awslearning"
    monitoring = "true"
    vpc_security_group_ids = [module.security-group.this_security_group_id]	
    subnet_ids = module.vpc.public_subnets
    user_data = <<-EOT
    #!/bin/bash

# Install script for Latest WordPress on local dev

# Setup

# Hardcoded variables that shouldn't change much

# Path to MySQL
MYSQL='/usr/bin/mysql'

# DB Variables
echo "MySQL Host:"
$mysqlhost = "myhost"
export $mysqlhost

echo "MySQL DB Name:"
$mysqldb = ""
export $mysqldb

echo "MySQL DB User:"
$mysqluser = ""
export $mysqluser

echo "MySQL User Password:"
$mysqlpass = ""
export $mysqlpass

# WP Variables
echo "Site Title:"
$wptitle = ""
export $wptitle

echo "Admin Username:"
$wpuser = ""
export $wpuser

echo "Admin Password:"
$wppass = ""
export $wppass

echo "Admin Email"
$wpemail = ""
export $wpemail

# Site Variables
echo "Site URL (ie, www.youraddress.com):"
$siteurl = ""
export $siteurl

echo "You will now be prompted for your MySQL password" 

# Setup DB & DB User
$MYSQL -uroot -p$mysqlrootpass -e "CREATE DATABASE IF NOT EXISTS $mysqldb; GRANT ALL ON $mysqldb.* TO '$mysqluser'@'$mysqlhost' IDENTIFIED BY '$mysqlpass'; FLUSH PRIVILEGES "

# Download latest WordPress and uncompress
wget http://wordpress.org/latest.tar.gz
tar zxf latest.tar.gz
mv wordpress/* ./


# Build our wp-config.php file
sed -e "s/localhost/"$mysqlhost"/" -e "s/database_name_here/"$mysqldb"/" -e "s/username_here/"$mysqluser"/" -e "s/password_here/"$mysqlpass"/" wp-config-sample.php > wp-config.php

# Grab our Salt Keys
SALT=$(curl -L https://api.wordpress.org/secret-key/1.1/salt/)
STRING='put your unique phrase here'
printf '%s\n' "g/$STRING/d" a "$SALT" . w | ed -s wp-config.php

# Run our install ...
curl -d "weblog_title=$wptitle&user_name=$wpuser&admin_password=$wppass&admin_password2=$wppass&admin_email=$wpemail" http://$siteurl/wp-admin/install.php?step=2

# Tidy up
rmdir wordpress
rm latest.tar.gz
rm wp-config-sample.php

# Download starkers
cd wp-content/themes/
wget https://github.com/viewportindustries/starkers/archive/master.zip
unzip master.zip
rm master.zip

    EOT
    tags = {
        terraform = "true"
        environment = "test"
    }
}

module "elb"  {
    source = "terraform-aws-modules/elb/aws"
    version = "2.4.0"
    name = "elb-testing"
    subnets = module.vpc.public_subnets
    security_groups = [module.security-group.this_security_group_id]
    internal = false
    listener = [
        {
            instance_port = "80"
            instance_protocol = "HTTP"
            lb_port = "80"
            lb_protocol = "HTTP"
        },
        {
            instance_port = "8080"
            instance_protocol = "http"
            lb_port = "8080"
            lb_protocol = "http"
        },
    ]    

    health_check = {
        target = "HTTP:80/"
        interval = 30
        healthy_threshold = 2
        unhealthy_threshold = 2
        timeout = 5
    }

    access_logs = {
        bucket = "my-access-logs"
    }

    number_of_instances = 1
    instances = module.ec2_instance.id

    tags = {
        environment = "test"

    }
}

resource "aws_launch_configuration" "web" {
  name_prefix = "web-"

  image_id = var.ami 
  instance_type = "t2.micro"
  key_name = "awslearning"

  security_groups = [module.security-group.this_security_group_id]
  associate_public_ip_address = true

  user_data = <<USER_DATA
#!/bin/bash
#!/bin/bash

# Install script for Latest WordPress on local dev

# Setup

# Hardcoded variables that shouldn't change much

# Path to MySQL
MYSQL='/usr/bin/mysql'

# DB Variables
echo "MySQL Host:"
$mysqlhost = "myhost"
export $mysqlhost

echo "MySQL DB Name:"
$mysqldb = ""
export $mysqldb

echo "MySQL DB User:"
$mysqluser = ""
export $mysqluser

echo "MySQL User Password:"
$mysqlpass = ""
export $mysqlpass

# WP Variables
echo "Site Title:"
$wptitle = ""
export $wptitle

echo "Admin Username:"
$wpuser = ""
export $wpuser

echo "Admin Password:"
$wppass = ""
export $wppass

echo "Admin Email"
$wpemail = ""
export $wpemail

# Site Variables
echo "Site URL (ie, www.youraddress.com):"
$siteurl = ""
export $siteurl

echo "You will now be prompted for your MySQL password" 

# Setup DB & DB User
$MYSQL -uroot -p$mysqlrootpass -e "CREATE DATABASE IF NOT EXISTS $mysqldb; GRANT ALL ON $mysqldb.* TO '$mysqluser'@'$mysqlhost' IDENTIFIED BY '$mysqlpass'; FLUSH PRIVILEGES "

# Download latest WordPress and uncompress
wget http://wordpress.org/latest.tar.gz
tar zxf latest.tar.gz
mv wordpress/* ./


# Build our wp-config.php file
sed -e "s/localhost/"$mysqlhost"/" -e "s/database_name_here/"$mysqldb"/" -e "s/username_here/"$mysqluser"/" -e "s/password_here/"$mysqlpass"/" wp-config-sample.php > wp-config.php

# Grab our Salt Keys
SALT=$(curl -L https://api.wordpress.org/secret-key/1.1/salt/)
STRING='put your unique phrase here'
printf '%s\n' "g/$STRING/d" a "$SALT" . w | ed -s wp-config.php

# Run our install ...
curl -d "weblog_title=$wptitle&user_name=$wpuser&admin_password=$wppass&admin_password2=$wppass&admin_email=$wpemail" http://$siteurl/wp-admin/install.php?step=2

# Tidy up
rmdir wordpress
rm latest.tar.gz
rm wp-config-sample.php

# Download starkers
cd wp-content/themes/
wget https://github.com/viewportindustries/starkers/archive/master.zip
unzip master.zip
rm master.zip
  USER_DATA

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "web" {
  name = "${aws_launch_configuration.web.name}-asg"

  min_size             = 1
  desired_capacity     = 2
  max_size             = 4
  
  health_check_type    = "ELB"
  load_balancers = [module.elb.this_elb_id]

  launch_configuration = aws_launch_configuration.web.name

  enabled_metrics = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupTotalInstances"
  ]

  metrics_granularity = "1Minute"

  vpc_zone_identifier  = ["module.vpc.public_subnets[0]","module.vpc.public_subnets[1]"]

  # Required to redeploy without an outage.
  lifecycle {
    create_before_destroy = true
  }

  tag {
    key                 = "Name"
    value               = "web"
    propagate_at_launch = true
  }

}


#module "autoscaling" {
#  source  = "terraform-aws-modules/autoscaling/aws"
#  version = "3.7.0"
#  
#  name = "service"
#
#  lc_name = "example-lc"
#
#  image_id = var.ami
#  instance_type = var.instance_type
#  security_groups = [module.security-group.this_security_group_id]
#
#  ebs_block_device = [
#      {
#          device_name = "/dev/xvdz"
#          volume_type = "gp2"
#          volume_size = "50"
#          delete_on_termination = true
#      },
#  ]
#  root_block_device = [
#      {
#          volume_size = "50"
#          volume_type = "gp2"
#      }
#  ]
#
#  asg_name = "example-asg"
#  vpc_zone_identifier = [module.vpc.vpc_id]
#  health_check_type = "EC2"
#  min_size = 0
#  max_size = 1
#  desired_capacity = 1
#  wait_for_capacity_timeout = 0
#
#  tags = [
#      {
#        environment = "test" 
#        propagate_at_launch = true         
#      },
#      {
#          key = "project"
#          value = "megasecret"
#          propagate_at_launch = true
#      },
#  ]
#
#  tags_as_map = {
#      extra_tag1 = "extra_value1"
#      extra_tag2 = "extra_value2"
#  }
#}        




