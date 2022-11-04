## This module is to create IAM user for GUI Access
resource "aws_iam_user" "profbob" {
  name          = "profbob"
  path          = "/"
  force_destroy = true
}


resource "aws_iam_user_login_profile" "profbob_profile" {
  user    = aws_iam_user.profbob.name
  # If the user has username in keybase we can use that to generate password
  pgp_key = "VmVyeUNvb2xBV1MyMiMj"

}
