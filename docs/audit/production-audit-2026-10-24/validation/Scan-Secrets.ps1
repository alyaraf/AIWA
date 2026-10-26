$ErrorActionPreference='Stop'
$projectRoot='D:\AIWA PROJECT\AIWA'
$taskRoot=$PSScriptRoot
$patterns=[ordered]@{
  private_key='-----BEGIN (?:RSA |EC |DSA |OPENSSH |ENCRYPTED )?PRIVATE KEY-----'
  aws_access_id='\b(?:AKIA|ASIA)[A-Z0-9]{16}\b'
  github_token='\b(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{40,})\b'
  slack_token='\bxox[baprs]-[A-Za-z0-9-]{20,}\b'
  google_api_key='\bAIza[A-Za-z0-9_-]{35}\b'
}
$tracked=@(& git -c safe.directory='D:/AIWA PROJECT/AIWA' -C $projectRoot ls-files)
$lines=[Collections.Generic.List[string]]::new()
$lines.Add('Tracked-file pattern scan; values are intentionally never printed. Not an entropy or full-history credential certification.')
$count=0
foreach($relative in $tracked){
  if($relative -match '\.(png|jpg|jpeg|webp|gif|ico|ttf|woff2?|zip|jar|pdf|mp4|xlsx|docx|p12|jks|keystore)$'){continue}
  $path=Join-Path $projectRoot $relative
  if(-not(Test-Path -LiteralPath $path -PathType Leaf)){continue}
  $content=[IO.File]::ReadAllLines($path)
  $count++
  for($i=0;$i -lt $content.Length;$i++){
    foreach($pattern in $patterns.GetEnumerator()){
      if($content[$i] -match $pattern.Value){$lines.Add($pattern.Key+': '+$relative+':'+($i+1)+' [value redacted]')}
    }
  }
}
$sensitive=@($tracked | Where-Object {$_ -match '(^|/)(\.env|firebase-service-account\.json|key\.properties)$|\.(jks|keystore|p12|pem|key)$'})
$lines.Add('Text files checked: '+$count)
$lines.Add('Sensitive tracked filenames: '+$sensitive.Count)
foreach($path in $sensitive){$lines.Add('Sensitive filename: '+$path)}
$lines.Add('Ignore-rule verification:')
$ignored=& git -c safe.directory='D:/AIWA PROJECT/AIWA' -C $projectRoot check-ignore deploy/.env deploy/secrets/firebase-service-account.json Android/aiwa_app/android/key.properties aiwa-backend/.env
foreach($path in $ignored){$lines.Add('ignored: '+$path)}
[IO.File]::WriteAllLines((Join-Path $taskRoot 'secret-scan.txt'),$lines,[Text.UTF8Encoding]::new($false))
$lines
