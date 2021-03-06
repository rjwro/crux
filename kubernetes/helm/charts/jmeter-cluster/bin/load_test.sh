#!/bin/bash
#Script created to invoke jmeter test script with the slave POD IP addresses
#Script should be run like: ./load_test "path to the test script in jmx format"
#/jmeter/apache-jmeter-*/bin/jmeter -n -t $1 -DjmeterPlugin.sts.loadAndRunOnStartup=true -DjmeterPlugin.sts.port=9191 -DjmeterPlugin.sts.datasetDirectory=/test -q /test/user.properties -Dserver.rmi.ssl.disable=true -R `getent ahostsv4 jmeter-slaves-svc | cut -d' ' -f1 | sort -u | awk -v ORS=, '{print $1}' | sed 's/,$//'`
#!/bin/bash

_wait_for_sts() {
  local _sleep_sec=$1
  local _ip=$2
  local _http_code=""
  until [ "$_http_code" == "200" ]; do
    printf "\n\t Waiting for STS ... %s s (code: %s)" "$_sleep_sec" "$_http_code"
    echo ""
    sleep "$_sleep_sec"
    _http_code=$(curl -s -o /dev/null -w "%{http_code}" http://$_ip:9191/sts/INITFILE?FILENAME=google.csv)
  done
}
_kill_script(){
  local _script=$1
  kill -9 $(pidof -x "$_script") > /dev/null 2>&1
}
_start_sts(){
  #for some reason nohup is no go perhaps SIGHUP is overwritten
  local _sts_name=$1
  local _shared_dir=$2
  screen -A -m -d -S sts /jmeter/apache-jmeter-*/bin/$_sts_name -DjmeterPlugin.sts.addTimestamp=true -DjmeterPlugin.sts.datasetDirectory=/$_shared_dir &
}
_jmeter(){
  local _test_dir=$1
  local _shared_dir=$2
  local _ip=$3
  shift 3
  local _jmx=$1
  shift 1
  local _fixed_args="-Gsts=$_ip -Gchromedriver=/usr/bin/chromedriver -q /$_test_dir/user.properties -Dserver.rmi.ssl.disable=true"
  echo "##[command] sh /jmeter/apache-jmeter-*/bin/jmeter.sh -n -t /$_test_dir/$_jmx $@ $_fixed_args -R $(getent ahostsv4 jmeter-slaves-svc | cut -d' ' -f1 | sort -u | awk -v ORS=, '{print $1}' | sed 's/,$//')"
  sh /jmeter/apache-jmeter-*/bin/jmeter.sh -n -t "/$_test_dir/$_jmx" $@ $_fixed_args -R $(getent ahostsv4 jmeter-slaves-svc | cut -d' ' -f1 | sort -u | awk -v ORS=, '{print $1}' | sed 's/,$//')

}
load_test(){
  local _ip="$(hostname -i)"
  local _sts_name=simple-table-server.sh
  local _test_dir=/test
  local _shared_dir=/shared
  local _sleep_sec=1

  _kill_script "$_sts_name"
  _start_sts "$_sts_name" "$_shared_dir"
  _wait_for_sts "$_sleep_sec" "$_ip"
  _jmeter "$_test_dir" "$_shared_dir" "$_ip" "$@"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  load_test "$@"
fi