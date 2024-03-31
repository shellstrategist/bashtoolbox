#!/bin/bash


query_file() {

    touch $file
    chown -R root:bind $directory
    chmod -R 775 $directory
}

stop_named() {
    systemctl stop named
}


clean_file() {
    > $file
}


if [ $# -ne 1 ]
then
    echo "Usage: $0 <key>"
    exit 1
fi


trap 'stop_named; clean_file; exit 1' INT
directory="/var/log/named"
file="${directory}/query.log"
key="$1"

if [[ $EUID -ne 0 ]]
then
   echo "[!] This script must be executed with administrator privilege"
   exit 1
fi


if [ ! -d $directory ]
then
    mkdir -p $directory
fi


if ! pgrep named >/dev/null
then
    systemctl start named
fi

counter=1
while true
do
    query_file
    echo "[*] Waiting for file..."
    while ! grep -q "==END==" "$file"
    do
        sleep 1
    done
    ip=$(grep "==START==" $file | grep -oE "(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)" | sort -u)
    domain=$(sed -n 's/.*==START==\.\(.*\)\():\).*/\1/p' $file | sort -u)
    encrypted_file=$(awk '/==START==/,/==END==/' $file | grep -E "${ip}.+${domain}" | grep -vE "==START==|==END==" | cut -d "(" -f 2 | cut -d "." -f 1 | sed 's/^.\{1\}//')
    plaintext_file=$(echo "$encrypted_file" | openssl enc -d -aes-256-cbc -salt -pbkdf2 -pass "pass:$key" -a)
    echo "$plaintext_file" > rx_${counter} && echo "[+] file rx_${counter} transfered"
    ((counter++))
    clean_file
done
