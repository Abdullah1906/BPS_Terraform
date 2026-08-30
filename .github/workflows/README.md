সবচেয়ে আগে পুরো flow-টা বুঝো:

Developer
   │
   │ git push main
   ▼
GitHub
   │
   ▼
GitHub Actions
   │
   ├── 1. Code checkout
   ├── 2. .NET 8 setup
   ├── 3. Restore
   ├── 4. Build
   ├── 5. Publish
   ├── 6. ZIP
   │
   ▼
AWS OIDC
   │
   ▼
S3 Artifact Bucket
   │
   ▼
AWS SSM
   │
   ├───────────────┐
   ▼               ▼
EC2 #1           EC2 #2
.NET 8           .NET 8
   │               │
   └───────┬───────┘
           ▼
       Internal ALB
           ▼
      API Gateway
           ▼
        Angular

এখন line-by-line দেখি।

1. Workflow-এর নাম
name: BPS .NET 8 Deploy

এটা শুধু GitHub Actions workflow-এর নাম।

GitHub-এর:

Repository
   → Actions

এ গেলে এই নামে workflow দেখতে পাবে।

2. কখন workflow চলবে?
on:
  push:
    branches:
      - main
  workflow_dispatch:

এখানে দুইটা trigger আছে।

push
push:
  branches:
    - main

মানে তুমি যদি:

git add .
git commit -m "update trip api"
git push origin main

করো, তাহলে automatically deployment শুরু হবে।

workflow_dispatch
workflow_dispatch:

এটার কারণে GitHub UI থেকে manually workflow চালাতে পারবে।

GitHub
 → Actions
 → BPS .NET 8 Deploy
 → Run workflow

এটা debugging/re-deployment-এর জন্য খুব useful।

3. permissions কেন?
permissions:
  id-token: write
  contents: read

এটা খুব important।

আমরা GitHub Actions থেকে AWS access করতে চাই।

পুরনো পদ্ধতিতে GitHub Secrets-এ রাখতে হতো:

AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY

কিন্তু এখানে আমরা GitHub OIDC ব্যবহার করছি।

তাই:

id-token: write

GitHub-কে AWS-এর জন্য temporary OIDC token তৈরি করতে দেয়।

আর:

contents: read

repository-এর source code read করতে দেয়।

4. Environment variables
env:
  DOTNET_VERSION: "8.0.x"
  AWS_REGION: ap-south-1
  ARTIFACT_BUCKET: REPLACE_WITH_TERRAFORM_OUTPUT_ARTIFACT_BUCKET
  ASG_NAME: REPLACE_WITH_TERRAFORM_OUTPUT_ASG_NAME

এগুলো common variable।

DOTNET
DOTNET_VERSION: "8.0.x"

মানে GitHub runner-এ .NET 8 install হবে।

AWS Region
AWS_REGION: ap-south-1

মানে Mumbai region।

S3 bucket
ARTIFACT_BUCKET: ...

এখানে Terraform যে S3 bucket বানিয়েছে তার নাম দিতে হবে।

যেমন:

bps-dev-artifacts-123456789012
ASG_NAME
ASG_NAME: ...

এটা এই workflow-তে বর্তমানে সরাসরি ব্যবহার হচ্ছে না।

SSM deployment-এ আমরা ASG name-এর পরিবর্তে instance tags ব্যবহার করছি।

তাই technically এই variable remove করলেও deployment কাজ করবে।

5. Job
jobs:
  build-and-deploy:
    runs-on: ubuntu-latest

মানে GitHub একটি temporary Ubuntu machine তৈরি করবে।

GitHub
   ↓
Temporary Ubuntu Runner

এই machine-এ build হবে।

Build শেষ হলে runner destroy হয়ে যায়।

তোমার AWS EC2-তে build করার প্রয়োজন নেই।

6. Code checkout
- name: Checkout
  uses: actions/checkout@v4

GitHub repository-এর code runner-এর মধ্যে নিয়ে আসে।

ধরো তোমার repository:

BPS/
├── src/
│   ├── BPS.Api/
│   ├── BPS.Application/
│   ├── BPS.Domain/
│   └── BPS.Infrastructure/
└── ...

তাহলে এগুলো runner-এ চলে আসবে।

7. .NET 8 install
- name: Setup .NET 8
  uses: actions/setup-dotnet@v4
  with:
    dotnet-version: ${{ env.DOTNET_VERSION }}

GitHub runner-এ .NET 8 SDK install করবে।

এখানে একটা important distinction:

SDK

Build করার জন্য দরকার:

.NET SDK 8
Runtime

AWS EC2-তে application চালানোর জন্য দরকার:

ASP.NET Core Runtime 8

তাই:

GitHub Runner
   ↓
.NET 8 SDK
   ↓
Build/Publish

আর:

AWS EC2
   ↓
ASP.NET Core Runtime 8
   ↓
BPS.Api.dll চালাবে
8. Restore
- name: Restore
  run: dotnet restore src/BPS.Api/BPS.Api.csproj

তোমার .NET project-এর NuGet packages download করবে।

যেমন:

Dapper
Microsoft.AspNetCore.Authentication.JwtBearer
Microsoft.Data.SqlClient
...

এসব dependency restore হবে।

9. Build
- name: Build
  run: dotnet build src/BPS.Api/BPS.Api.csproj --configuration Release --no-restore

এখানে application compile হচ্ছে।

C#
 ↓
Compiler
 ↓
BPS.Api.dll

Release production build-এর জন্য।

আর:

--no-restore

কারণ আগের step-এই restore হয়ে গেছে।

তাই আবার restore করার দরকার নেই।

10. Publish
- name: Publish
  run: |
    rm -rf ./publish
    dotnet publish src/BPS.Api/BPS.Api.csproj \
      --configuration Release \
      --output ./publish \
      --no-restore

এটা সবচেয়ে important step।

build শুধু compile করে।

publish deployment-এর জন্য complete files তৈরি করে।

ধরো:

publish/
├── BPS.Api.dll
├── BPS.Api.deps.json
├── BPS.Api.runtimeconfig.json
├── appsettings.json
├── ...
└── required libraries

এটাই AWS server-এ যাবে।

11. ZIP তৈরি
- name: Package
  run: |
    cd publish
    zip -r ../bps-api-${GITHUB_SHA}.zip .

Publish folder-কে ZIP করছে।

ধরো commit ID:

abc123456789

তাহলে:

bps-api-abc123456789.zip

হবে।

GITHUB_SHA কেন?

প্রতিটি Git commit-এর unique ID থাকে।

তাই:

commit A → bps-api-111aaa.zip
commit B → bps-api-222bbb.zip
commit C → bps-api-333ccc.zip

এতে কোন version deploy হয়েছে সেটা সহজে track করা যায়।

12. AWS authentication
- name: Configure AWS credentials with GitHub OIDC
  uses: aws-actions/configure-aws-credentials@v4

এরপর:

with:
  role-to-assume: REPLACE_WITH_TERRAFORM_OUTPUT_GITHUB_ACTIONS_ROLE_ARN
  aws-region: ${{ env.AWS_REGION }}

এখানে GitHub AWS-এর IAM Role assume করবে।

Flow:

GitHub Actions
      │
      │ OIDC Token
      ▼
AWS IAM
      │
      │ Verify:
      │ GitHub repo?
      │ branch main?
      ▼
GitHub Actions IAM Role

এখানে AWS access key GitHub-এ রাখতে হচ্ছে না।

এটাই OIDC-এর বড় সুবিধা।

13. S3-তে artifact upload
- name: Upload artifact
  run: |
    aws s3 cp \
      "bps-api-${GITHUB_SHA}.zip" \
      "s3://${ARTIFACT_BUCKET}/releases/bps-api-${GITHUB_SHA}.zip"

এখন ZIP AWS S3-তে চলে যাবে।

GitHub
   │
   │ BPS API ZIP
   ▼
S3
└── releases/
    ├── bps-api-111aaa.zip
    ├── bps-api-222bbb.zip
    └── bps-api-333ccc.zip
S3 এখানে কেন?

কারণ তোমার EC2 private subnet-এ।

GitHub সরাসরি:

GitHub → EC2 private IP

করতে পারবে না।

তাই একটা artifact store দরকার।

S3 সেই মাঝখানের জায়গা।

14. এবার আসল deployment
- name: Deploy to ASG instances through SSM

এখানে AWS Systems Manager ব্যবহার করছি।

কারণ EC2 private:

Internet
   X
   │
Private EC2

GitHub সরাসরি SSH করতে পারবে না।

SSM দিয়ে:

GitHub
  ↓
AWS SSM
  ↓
Private EC2

কমান্ড পাঠানো যায়।

15. SSM Command পাঠানো
COMMAND_ID=$(aws ssm send-command \

AWS-কে বলছে:

এই command-গুলো আমার target EC2 instances-এ চালাও।

16. কোন EC2-তে command যাবে?
--targets "Key=tag:Project,Values=bps" "Key=tag:Role,Values=api"

এটা খুব সুন্দর একটা approach।

Terraform-এ API EC2 instances-এর tag আছে:

Project = bps
Role    = api

তাই SSM বলছে:

Project=bps
AND
Role=api

যে instances আছে, সবগুলোর ওপর command চালাও।

তাই:

ASG
├── EC2 #1 → Project=bps, Role=api
└── EC2 #2 → Project=bps, Role=api

দুটোতেই deployment হবে।

ASG পরে নতুন instance তৈরি করলেও যদি একই tags থাকে, সেটাও target হবে।

17. AWS RunShellScript
--document-name "AWS-RunShellScript"

মানে target Ubuntu EC2-তে shell command চালাবে।

যেমন:

mkdir
aws s3 cp
unzip
systemctl restart
18. Release folder তৈরি
mkdir -p /opt/bps/releases/${GITHUB_SHA}

Server-এ:

/opt/bps/
├── current/
└── releases/
    └── abc123/

তৈরি হবে।

19. S3 থেকে ZIP download
aws s3 cp \
s3://${ARTIFACT_BUCKET}/releases/bps-api-${GITHUB_SHA}.zip \
/opt/bps/releases/bps-api-${GITHUB_SHA}.zip

EC2 নিজে S3 থেকে artifact download করছে।

Flow:

S3
 │
 │ BPS ZIP
 ▼
EC2

এখানে EC2-এর IAM Role-এর S3 read permission দরকার।

20. ZIP extract
unzip -oq \
/opt/bps/releases/bps-api-${GITHUB_SHA}.zip \
-d /opt/bps/releases/${GITHUB_SHA}

যেমন:

/opt/bps/releases/abc123/
├── BPS.Api.dll
├── BPS.Api.deps.json
├── appsettings.json
└── ...
21. current.new
rm -rf /opt/bps/current.new

cp -a \
/opt/bps/releases/${GITHUB_SHA} \
/opt/bps/current.new

এটা deployment-এর একটা staging approach।

মানে আগে নতুন version:

current.new

এ তৈরি হচ্ছে।

তারপর:

rm -rf /opt/bps/current
mv /opt/bps/current.new /opt/bps/current

শেষে:

/opt/bps/current

নতুন version point করবে।

22. systemd restart
systemctl daemon-reload
systemctl restart bps-api

তোমার EC2-তে আমরা service বানিয়েছিলাম:

/etc/systemd/system/bps-api.service

যার মধ্যে:

ExecStart=/usr/bin/dotnet /opt/bps/current/BPS.Api.dll

তাই:

systemctl restart bps-api

করলে নতুন DLL চালু হবে।

Flow:

Old BPS.Api.dll
       ↓
stop
       ↓
New BPS.Api.dll
       ↓
start
23. Application actually running কিনা check
systemctl is-active --quiet bps-api

যদি service running হয়:

exit code = 0

তাহলে deployment successful।

যদি application crash করে:

exit code != 0

তাহলে GitHub Actions fail করবে।

24. Command ID
COMMAND_ID=$(aws ssm send-command ...)

SSM যখন command নেয়, একটা ID দেয়।

যেমন:

COMMAND_ID =
12345678-abcd-....

এটা পরে command-এর status দেখার জন্য ব্যবহার হচ্ছে।

25. 10 seconds অপেক্ষা
sleep 10

SSM command execute হওয়ার জন্য একটু সময় দিচ্ছে।

26. Deployment status
aws ssm list-command-invocations \
  --command-id "${COMMAND_ID}" \
  --details

এতে দেখবে:

EC2 #1 → Success
EC2 #2 → Success

অথবা:

EC2 #1 → Success
EC2 #2 → Failed
সবচেয়ে গুরুত্বপূর্ণ বিষয়: ASG এখানে কী করছে?

ধরো তোমার:

min     = 2
desired = 2
max     = 4

তাহলে:

             ASG
              │
       ┌──────┴──────┐
       ▼             ▼
    EC2 #1         EC2 #2
    .NET 8         .NET 8

GitHub Actions deployment হলে:

GitHub
   ↓
S3
   ↓
SSM
   ├──→ EC2 #1
   └──→ EC2 #2

দুটো server-এই একই version deploy হয়।