#To Create Autoscaling Launch Template 
resource "aws_launch_template" "webserver" {
  name_prefix   = var.namespace
  image_id      = "ami-098f16afa9edf40be"
  instance_type = "t2.micro"
  user_data     = "${base64encode(file("install.sh"))}"
  key_name      = var.ssh_keypair
  lifecycle {
    create_before_destroy = true
  }
  vpc_security_group_ids = [var.sg.websvr]
}

#To Create Autoscaling Group
resource "aws_autoscaling_group" "webserver" {
  name                = "${var.namespace}-asg"
  min_size            = 2
  max_size            = 5
  vpc_zone_identifier = var.subnet_private
  launch_template {
    id      = aws_launch_template.webserver.id
    version = aws_launch_template.webserver.latest_version
  }
  health_check_type = "ELB"
}

# AutoScaling Policy

# scale up alarm
resource "aws_autoscaling_policy" "web-cpu-policy" {
  name                   = "web-cpu-policy"
  autoscaling_group_name = "${aws_autoscaling_group.webserver.name}"
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = "1"
  cooldown               = "300"
  policy_type            = "SimpleScaling"
}

resource "aws_cloudwatch_metric_alarm" "web-cpu-alarm" {
  alarm_name          = "web-cpu-alarm"
  alarm_description   = "web-cpu-alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "60"
  dimensions = {
    "AutoScalingGroupName" = "${aws_autoscaling_group.webserver.name}"
  }
  actions_enabled = true
  alarm_actions   = ["${aws_autoscaling_policy.web-cpu-policy.arn}"]
}


# scale down alarm
resource "aws_autoscaling_policy" "web-cpu-policy-scaledown" {
  name                   = "web-cpu-policy-scaledown"
  autoscaling_group_name = "${aws_autoscaling_group.webserver.name}"
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = "-1"
  cooldown               = "300"
  policy_type            = "SimpleScaling"
}

resource "aws_cloudwatch_metric_alarm" "web-cpu-alarm-scaledown" {
  alarm_name          = "web-cpu-alarm-scaledown"
  alarm_description   = "web-cpu-alarm-scaledown"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120"
  statistic           = "Average"
  threshold           = "50"
  dimensions = {
    "AutoScalingGroupName" = "${aws_autoscaling_group.webserver.name}"
  }
  actions_enabled = true
  alarm_actions   = ["${aws_autoscaling_policy.web-cpu-policy-scaledown.arn}"]
}

#To Create Application Load-Balancer 
resource "aws_lb" "sush-alb" {
  name            = "sush-alb"
  subnets         = var.subnet_public
  security_groups = [var.sg.lb]
  internal        = false
  idle_timeout    = 60
  tags = {
    Name = "sush-alb"
  }
}

#To Create Application Load-Balancer Target Group
resource "aws_lb_target_group" "alb_target_group" {
  name     = "alb-target-group"
  port     = "80"
  protocol = "HTTP"
  vpc_id   = var.vpc.id
  tags = {
    name = "alb_target_group"
  }
  stickiness {
    type            = "lb_cookie"
    cookie_duration = 1800
    enabled         = true
  }
  health_check {
    healthy_threshold   = 3
    unhealthy_threshold = 10
    timeout             = 5
    interval            = 10
    path                = "/"
    port                = 80
  }
}

# To Create ALB Listener for Target Group 
resource "aws_lb_listener" "alb_listener_http" {
  load_balancer_arn = "${aws_lb.sush-alb.arn}"
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_lb_target_group.alb_target_group.arn}"
    type             = "forward"
  }
}

resource "aws_alb_listener" "alb_listener_https" {
  load_balancer_arn = "${aws_lb.sush-alb.arn}"
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = "${var.certificate_arn}"
  default_action {
    target_group_arn = "${aws_lb_target_group.alb_target_group.arn}"
    type             = "forward"
  }
}

#Attaching Autoscaling group with ALB Target group to serve tarffic.
resource "aws_autoscaling_attachment" "alb_autoscale" {
  alb_target_group_arn   = "${aws_lb_target_group.alb_target_group.arn}"
  autoscaling_group_name = "${aws_autoscaling_group.webserver.id}"
}

# Data Source of Hosted Zone to get Hosted Domain Name
data "aws_route53_zone" "hosted-zone" {
  name = "${var.route53_hosted_zone_name}"
}

#Creating A record which we will use to access website using HTTPS Protocol 
resource "aws_route53_record" "terraform" {
  zone_id = "${data.aws_route53_zone.hosted-zone.zone_id}"
  name    = "terraform.${var.route53_hosted_zone_name}"
  type    = "A"
  alias {
    name                   = "${aws_lb.sush-alb.dns_name}"
    zone_id                = "${aws_lb.sush-alb.zone_id}"
    evaluate_target_health = true
  }
}
