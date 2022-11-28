resource "aws_cloudwatch_metric_alarm" "high_bandwidth" {
  alarm_name          = "smart-bw-out-high-${module.this.id}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "NetworkOut"
  namespace           = "AWS/EC2"
  period              = "3600"
  statistic           = "Sum"
  threshold           = var.max_transfer_per_hour
  alarm_description   = "Alerts when bandwidth out exceeds specified threshold in an hour"
  actions_enabled     = "true"
  dimensions = {
    InstanceId = module.instance.id
  }

  tags = module.this.tags
}

resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "smart-cpu-high-${module.this.id}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "3600"
  statistic           = "Average"
  threshold           = 50
  alarm_description   = "Alerts when bandwidth out exceeds specified threshold in an hour"
  actions_enabled     = "true"
  dimensions = {
    InstanceId = module.instance.id
  }

  tags = module.this.tags
}
