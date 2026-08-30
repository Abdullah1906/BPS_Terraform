AWS-এ GitHub Actions-এর জন্য OIDC (OpenID Connect) মূলত ২টি ধাপে তৈরি ও কনফিগার হয়:

AWS Identity Provider (IdP) সেটআপ: AWS-কে জানানো যে GitHub Actions একটি বিশ্বস্ত Identity Provider।

IAM Role তৈরি: একটি Role বানিয়ে তার Trust Policy-তে বলে দেওয়া যে নির্দিষ্ট GitHub Repository ছাড়া কেউ এটি ব্যবহার করতে পারবে না।

১. Terraform দিয়ে OIDC তৈরি (সবচেয়ে সহজ ও সেরা উপায়)
আপনার পূর্বের Terraform কোডটিতে ইতিমধ্যেই OIDC সম্পূর্ণ কনফিগার করা আছে। Terraform এটি এভাবে তৈরি করে:

ধাপ ১: OIDC Provider তৈরি

Terraform
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1", "1c58a2a8925dc04fe001309f405ee41d69d53280"]
}
ধাপ ২: IAM Role ও Trust Policy (যা GitHub-কে অনুমতি দেয়)

Terraform
resource "aws_iam_role" "github_actions" {
  name = "bps-dev-github-actions"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          # শুধুমাত্র আপনার GitHub Org/User, Repo এবং Branch-কে অ্যাক্সেস দেবে
          "token.actions.githubusercontent.com:sub" = "repo:YOUR_GITHUB_USER/YOUR_REPO:ref:refs/heads/main"
        }
      }
    }]
  })
}
২. AWS Console (GUI) দিয়ে ম্যানুয়ালি তৈরি করা
যদি Terraform না দিয়ে ম্যানুয়ালি AWS Console থেকে বানাতে চান:

ধাপ ১: Identity Provider যোগ করা

AWS Management Console-এ IAM সার্ভিস-এ যান।

বাম পাশের মেনু থেকে Identity providers-এ ক্লিক করে Add provider চাপুন।

Provider type: নির্বাচন করুন OpenID Connect।

Provider URL: দিন [https://token.actions.githubusercontent.com](https://token.actions.githubusercontent.com) এবং Get thumbprint-এ ক্লিক করুন।

Audience: দিন sts.amazonaws.com

Add provider বাটনে ক্লিক করুন।

ধাপ ২: IAM Role তৈরি ও Trust Policy সেটআপ

IAM > Roles-এ গিয়ে Create role-এ ক্লিক করুন।

Trusted entity type: নির্বাচন করুন Web identity।

Identity provider: ড্রপডাউন থেকে token.actions.githubusercontent.com সিলেক্ট করুন।

Audience: sts.amazonaws.com সিলেক্ট করুন।

GitHub organization: আপনার GitHub Username বা Organization Name দিন।

GitHub repository: আপনার Repository Name দিন (ঐচ্ছিক)।

Next দিয়ে প্রয়োজনীয় Permissions Policy (যেমন: S3, SSM access) যুক্ত করুন এবং Role-টি Save করুন।

৩. GitHub Actions-এ ব্যবহার করার নিয়ম
OIDC কাজ করার জন্য আপনার GitHub Workflow (.yml) ফাইলের একদম ওপরে id-token: write পারমিশনটি অবশ্যই থাকতে হবে:

YAML
name: Deploy to AWS

on:
  push:
    branches: [ "main" ]

permissions:
  id-token: write   # OIDC টোকেন জেনারেট করার জন্য এটি বাধ্যতামূলক
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Configure AWS credentials with GitHub OIDC
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::448513989308:role/bps-dev-github-actions
          aws-region: us-east-1