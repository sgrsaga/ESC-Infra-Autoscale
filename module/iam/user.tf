## full read only access
/*
resource "aws_iam_role" "ReadOnlyFull" {
  name = "ReadOnlyFull"

  assume_role_policy = <<EOF
{
    "Version": "2008-10-17",
    "Statement": [
        {
            "Sid": "",
            "Effect": "Allow",
            "Principal": {
                "Service": "ecs-tasks.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ReadOnlyFullAttach" {
  role       = aws_iam_role.ReadOnlyFull.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}
*/

## This module is to create IAM user for GUI Access
resource "aws_iam_user" "profbob" {
  name          = var.username
  path          = "/"
  force_destroy = true
}

## Create random value for profile
resource "random_string" "sm_postfix_prof"{
  length           = 8
  special          = false
  override_special = "-"
}

# Create Instance Profile for Proffesor
resource "aws_iam_instance_profile" "profbob" {
  name = "profbob-${random_string.sm_postfix_prof.result}"
  role = aws_iam_role.profbob.name
}


resource "aws_iam_policy_attachment" "profbob-attach" {
  name       = "profbob-attach"
  users      = [aws_iam_user.profbob.name]
  policy_arn =  "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

/*
resource "aws_iam_user_login_profile" "profbob_profile" {
  user    = aws_iam_user.profbob.name
  # If the user has username in keybase we can use that to generate password
  pgp_key = "VmVyeUNvb2xBV1MyMiMj"

}
*/