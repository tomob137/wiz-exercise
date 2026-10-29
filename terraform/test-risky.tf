# Deliberately risky change to show the pipeline scan catching it. Never merged.
resource "aws_security_group" "test_rdp_open" {
  name   = "wiz-test-rdp-open"
  vpc_id = module.vpc.vpc_id
  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}