param(
  $RootPath="$PSScriptRoot",
  $Image="gabrielstar/crux-master:0.0.1",
  $ContainerName="crux"
)
function Stop-JMeterContainer($ContainerName){
  Write-Host "Checking if container $ContainerName if running ..."
  $out = docker ps -a --no-trunc --filter name=^/${ContainerName}$ | Out-String
  if( $out -like "*${ContainerName}*" )
  {
    Write-Host "Container $ContainerName running. Attempting to stop it ..."
    docker stop $ContainerName
    docker rm $ContainerName
  }else{
    Write-Host "Container $ContainerName not running ..."
  }
}

function Start-JMeterContainer($Image, $ContainerName, $TestDataDir, $ContainerTestDataDir, $JVM_ARGS)
{
  Write-Host "Starting container ${ContainerName} from ${Image} ..."
  docker run -d `
          --name ${ContainerName} `
          --entrypoint tail `
          -e JVM_ARGS="$JVM_ARGS" `
          --volume ${TestDataDir}:${ContainerTestDataDir} ${Image} `
          -f /dev/null
  Write-Host "Started container ${ContainerName} "
  docker ps -a --no-trunc --filter name=^/${ContainerName}$
  Start-CommandInsideDocker $ContainerName "touch /test/errors.xml" #file should be there even if no errors
}
function Start-CommandInsideDocker($ContainerName, $Command){
  docker exec $ContainerName sh -c "${Command}"
}
function Show-TestDirectory($ContainerName,$Directory){
  Write-Host "Directory ${Directory}:"
  Start-CommandInsideDocker $ContainerName "ls $Directory"
}
function Start-SimpleTableServer($ContainerName, $DataSetDirectory, $SleepSeconds){
  $stsCommand="screen -A -m -d -S sts /jmeter/apache-jmeter-*/bin/simple-table-server.sh -DjmeterPlugin.sts.addTimestamp=true -DjmeterPlugin.sts.datasetDirectory=${DataSetDirectory}"
  Start-Sleep -Seconds $SleepSeconds
  Start-CommandInsideDocker $ContainerName "${stsCommand}"
}
function Start-JmeterTest($ContainerName, $JMXPath,$UserArgs,$FixedArgs){
  Write-Host "##[command] sh /jmeter/apache-jmeter-*/bin/jmeter.sh -n -t ${JMXPath} ${UserArgs} ${FixedArgs}"
  Start-CommandInsideDocker $ContainerName "sh /jmeter/apache-jmeter-*/bin/jmeter.sh -n -t ${JMXPath} ${UserArgs} ${FixedArgs}"
}
function Copy-Artifacts($ArtifactsDirectory, $TestDataDirOnAgent)
{
  Copy-Item $TestDataDirOnAgent/report $ArtifactsDirectory/report -Recurse -force
  Copy-Item $TestDataDirOnAgent/jmeter.log $ArtifactsDirectory -force
  Copy-Item $TestDataDirOnAgent/results.csv $ArtifactsDirectory -force
  Copy-Item $TestDataDirOnAgent/errors.xml $ArtifactsDirectory -force
}
Export-ModuleMember -function *