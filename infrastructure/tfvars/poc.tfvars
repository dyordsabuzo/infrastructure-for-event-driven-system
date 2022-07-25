region                   = "ap-southeast-2"
hosted_zone_name         = "pablosspot.ml"
endpoint_name            = "app"
vpc_id                   = "vpc-392e765d"
private_subnets          = ["subnet-ba2f3dcc", "subnet-4de6a814"]
public_subnets           = ["subnet-588b663f", "subnet-4de6a814"]
instance_security_groups = ["sg-06be7460"]
lb_security_groups       = ["sg-728b390b"]
