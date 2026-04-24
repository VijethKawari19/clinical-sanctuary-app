param(
  [Parameter(Mandatory=$true)][string]$SmtpUsername,
  [Parameter(Mandatory=$true)][string]$SmtpPassword
)

$ErrorActionPreference = "Stop"

# Gmail SMTP defaults for this project.
$SMTP_HOST = "smtp.gmail.com"
$SMTP_PORT = "587"
$SMTP_FROM = $SmtpUsername.Trim()
$SMTP_FROM_NAME = "Clinical Curator"
$SMTP_SSL = "false" # STARTTLS on 587

flutter run -d windows `
  --dart-define=SMTP_HOST=$SMTP_HOST `
  --dart-define=SMTP_PORT=$SMTP_PORT `
  --dart-define=SMTP_USERNAME=$SmtpUsername `
  --dart-define=SMTP_PASSWORD=$SmtpPassword `
  --dart-define=SMTP_FROM=$SMTP_FROM `
  --dart-define=SMTP_FROM_NAME=$SMTP_FROM_NAME `
  --dart-define=SMTP_SSL=$SMTP_SSL

