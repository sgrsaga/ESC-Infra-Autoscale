## This module is to create IAM user for GUI Access
resource "aws_iam_user" "profbob" {
  name          = "profbob"
  path          = "/"
  force_destroy = true
}

resource "aws_iam_user_login_profile" "profbob_profile" {
  user    = aws_iam_user.example.name
  pgp_key = "keybase:some_person_that_exists"
}

output "password" {
  value = aws_iam_user_login_profile.profbob_profile.encrypted_password
}