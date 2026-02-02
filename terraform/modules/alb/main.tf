# ALB Module
# @author Shanaka Jayasundera - shanakaj@gmail.com
# AWS Application Load Balancer - equivalent to Azure Application Gateway

# Security Group for ALB
resource "aws_security_group" "alb" {
  name        = "alb-${var.name_prefix}-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = var.vpc_id

  # HTTP ingress
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP from internet"
  }

  # HTTPS ingress
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS from internet"
  }

  # Egress to VPC (for backend communication)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
    description = "All traffic to VPC"
  }

  tags = merge(var.tags, {
    Name = "sg-alb-${var.name_prefix}"
  })
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "alb-${var.name_prefix}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = var.enable_deletion_protection

  tags = merge(var.tags, {
    Name = "alb-${var.name_prefix}"
  })
}

# Target Group for Istio Gateway (HTTP)
resource "aws_lb_target_group" "istio_http" {
  name        = "tg-istio-http-${var.name_prefix}"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 10
    path                = var.health_check_path
    protocol            = "HTTP"
    matcher             = "200"
  }

  tags = merge(var.tags, {
    Name = "tg-istio-http-${var.name_prefix}"
  })
}

# Target Group for Istio Gateway (HTTPS backend)
resource "aws_lb_target_group" "istio_https" {
  count       = var.backend_https_enabled ? 1 : 0
  name        = "tg-istio-https-${var.name_prefix}"
  port        = 443
  protocol    = "HTTPS"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 10
    path                = var.health_check_path
    protocol            = "HTTPS"
    matcher             = "200"
  }

  tags = merge(var.tags, {
    Name = "tg-istio-https-${var.name_prefix}"
  })
}

# HTTP Listener - redirect to HTTPS
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = var.enable_https ? "redirect" : "forward"

    dynamic "redirect" {
      for_each = var.enable_https ? [1] : []
      content {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }

    dynamic "forward" {
      for_each = var.enable_https ? [] : [1]
      content {
        target_group {
          arn = aws_lb_target_group.istio_http.arn
        }
      }
    }
  }

  tags = var.tags
}

# HTTPS Listener
resource "aws_lb_listener" "https" {
  count             = var.enable_https ? 1 : 0
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = var.ssl_policy
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = var.backend_https_enabled ? aws_lb_target_group.istio_https[0].arn : aws_lb_target_group.istio_http.arn
  }

  tags = var.tags
}

# Listener Rules for path-based routing (optional)
resource "aws_lb_listener_rule" "health" {
  count        = var.enable_https ? 1 : 0
  listener_arn = aws_lb_listener.https[0].arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = var.backend_https_enabled ? aws_lb_target_group.istio_https[0].arn : aws_lb_target_group.istio_http.arn
  }

  condition {
    path_pattern {
      values = ["/healthz", "/healthz/*"]
    }
  }

  tags = var.tags
}

resource "aws_lb_listener_rule" "app1" {
  count        = var.enable_https ? 1 : 0
  listener_arn = aws_lb_listener.https[0].arn
  priority     = 200

  action {
    type             = "forward"
    target_group_arn = var.backend_https_enabled ? aws_lb_target_group.istio_https[0].arn : aws_lb_target_group.istio_http.arn
  }

  condition {
    path_pattern {
      values = ["/app1", "/app1/*"]
    }
  }

  tags = var.tags
}

resource "aws_lb_listener_rule" "app2" {
  count        = var.enable_https ? 1 : 0
  listener_arn = aws_lb_listener.https[0].arn
  priority     = 300

  action {
    type             = "forward"
    target_group_arn = var.backend_https_enabled ? aws_lb_target_group.istio_https[0].arn : aws_lb_target_group.istio_http.arn
  }

  condition {
    path_pattern {
      values = ["/app2", "/app2/*"]
    }
  }

  tags = var.tags
}
